#!/bin/bash
# NXC - Instalador Completo v1.2.16
# Baseado no XC_VM de Vateron-Media (AGPL v3.0)

set -o pipefail
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
ok()   { echo -e "${GREEN}[OK]${NC}" $1; }
info() { echo -e "${CYAN}[i]${NC}" $1; }
warn() { echo -e "${YELLOW}[!]${NC}" $1; }
err()  { echo -e "${RED}[ERRO]${NC}" $1; exit 1; }
step() { echo -e "\n${BOLD}${CYAN}== $1 ==${NC}"; }

clear
echo '  _   _  __  __  ____'
echo ' | \ | ||  \/  |/ ___|'
echo ' |  \| || |\/| | |'
echo ' | |\  || |  | | |___'
echo ' |_| \_||_|  |_|\____|'
echo '  NXC - Painel IPTV (XC_VM v1.2.16 + Fixes) | Licenca: AGPL v3.0'
echo ''

step 'Verificando pre-requisitos'
[[ $EUID -ne 0 ]] && err 'Execute como root: sudo bash instalar.sh'

OS_ID=$(lsb_release -si 2>/dev/null || echo '')
OS_VER=$(lsb_release -sr 2>/dev/null || echo '')
[[ "$OS_ID" != 'Ubuntu' ]] && warn "Sistema: $OS_ID $OS_VER (testado em Ubuntu 22.04)"
ok "Ubuntu $OS_VER detectado"

TOTAL_RAM_MB=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
TOTAL_RAM_GB=$(($TOTAL_RAM_MB / 1024))
CPU_COUNT=$(nproc)
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ok "CPU: ${CPU_COUNT} threads | RAM: ${TOTAL_RAM_GB} GB | Dir: $SCRIPT_DIR"

echo ''
echo 'Este instalador ira:'
echo '  - Instalar o NXC (XC_VM v1.2.16) em /home/xc_vm/'
echo '  - Aplicar todos os fixes de producao (Redis, live.php, CoreUtilities, BD)'
echo '  - Otimizar MariaDB, Nginx, PHP-FPM e kernel | Configurar UFW'
echo ''
read -rp 'Confirmar instalacao? (s/N): ' confirm
[[ "$confirm" != 's' && "$confirm" != 'S' ]] && { info 'Cancelado.'; exit 0; }

step 'Corrigindo GRUB'
apt-mark hold grub-efi-amd64 grub-efi-amd64-bin grub-efi-amd64-signed grub-common grub2-common shim-signed 2>/dev/null || true
rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/cache/apt/archives/lock 2>/dev/null || true
dpkg --configure -a --force-confdef --force-confold 2>/dev/null || true
ok 'GRUB OK'

step 'Atualizando sistema'
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq && apt-get full-upgrade -y -qq
apt-get install -y -qq python3-pip unzip curl wget ufw
ok 'Sistema atualizado'

step 'Instalando XC_VM v1.2.16'
[[ ! -f "$SCRIPT_DIR/XC_VM.zip" ]] && err "XC_VM.zip nao encontrado em $SCRIPT_DIR"
INSTALL_TMP=$(mktemp -d)
info 'Extraindo XC_VM.zip...'
unzip -q "$SCRIPT_DIR/XC_VM.zip" -d "$INSTALL_TMP"
XC_INSTALL_DIR=$(find "$INSTALL_TMP" -name 'install' -maxdepth 3 | head -1 | xargs dirname)
[[ -z "$XC_INSTALL_DIR" ]] && err 'Arquivo install nao encontrado no zip'
info 'Executando instalador oficial XC_VM...'
cd "$XC_INSTALL_DIR" && printf "\n\n\nY\n" | python3 install && cd "$SCRIPT_DIR"
ok 'XC_VM instalado em /home/xc_vm/'
info 'Aguardando servicos (15s)...'; sleep 15

step 'Fix 4 - Redis server-threads (evita HTTP 500)'
python3 "$SCRIPT_DIR/patches/fix_redis.py" && ok 'Redis: server-threads=1' || warn 'fix_redis.py com aviso'

step 'Fix 1 - live.php (loop infinito / CPU 100%)'
LIVE_PHP='/home/xc_vm/www/stream/live.php'
if [[ -f "$LIVE_PHP" ]]; then
    cp "$LIVE_PHP" "${LIVE_PHP}.bak.$(date +%Y%m%d_%H%M%S)"
    python3 "$SCRIPT_DIR/patches/apply_fix1.py" && ok 'live.php: fix aplicado' || warn 'live.php: verificar manualmente'
else
    warn "live.php nao encontrado em $LIVE_PHP"
fi

step 'Fix 2 - CoreUtilities.php (startup lento M3U8)'
CORE_PHP='/home/xc_vm/streaming/CoreUtilities.php'
if [[ -f "$CORE_PHP" ]]; then
    cp "$CORE_PHP" "${CORE_PHP}.bak.$(date +%Y%m%d_%H%M%S)"
    python3 "$SCRIPT_DIR/patches/apply_fix2.py" && ok 'CoreUtilities.php: fix aplicado' || warn 'CoreUtilities: verificar manualmente'
else
    warn "CoreUtilities.php nao encontrado em $CORE_PHP"
fi

step 'Fix 3 - Conexoes fantasma no banco'
if mariadb --defaults-file=/etc/mysql/debian.cnf xc_vm -e 'SELECT 1;' >/dev/null 2>&1; then
    mariadb --defaults-file=/etc/mysql/debian.cnf xc_vm -e \
        'UPDATE lines_live SET hls_end=1 WHERE hls_end=0 AND (hls_last_read IS NULL OR hls_last_read < UNIX_TIMESTAMP()-300);' 2>/dev/null
    ok 'Conexoes fantasma limpas'
else
    warn 'Banco nao pronto - fix 3 aplicar depois'
fi

step "Otimizando MariaDB (RAM: ${TOTAL_RAM_GB}GB)"
BUFFER_GB=$(( TOTAL_RAM_GB * 55 / 100 )); [[ $BUFFER_GB -lt 1 ]] && BUFFER_GB=1
INSTANCES=$(( CPU_COUNT > 64 ? 64 : CPU_COUNT )); [[ $INSTANCES -lt 1 ]] && INSTANCES=1
sed -e "s/{{BUFFER_POOL}}/${BUFFER_GB}G/g" \
    -e "s/{{BUFFER_INSTANCES}}/${INSTANCES}/g" \
    -e "s/{{THREAD_POOL}}/${CPU_COUNT}/g" \
    "$SCRIPT_DIR/configs/mariadb.cnf.template" > /etc/mysql/mariadb.conf.d/99-nxc.cnf
ok "MariaDB: buffer=${BUFFER_GB}GB threads=${CPU_COUNT}"

step 'Otimizando Nginx (apenas parametros - NAO substitui nginx.conf)'
NGINX_CONF='/home/xc_vm/bin/nginx/conf/nginx.conf'
if [[ -f "$NGINX_CONF" ]]; then
    cp "$NGINX_CONF" "${NGINX_CONF}.bak.$(date +%Y%m%d_%H%M%S)"
    sed -i 's/^worker_processes[[:space:]]\+[^;]*;/worker_processes  auto;/' "$NGINX_CONF"
    if grep -q 'worker_rlimit_nofile' "$NGINX_CONF"; then
        sed -i 's/worker_rlimit_nofile[[:space:]]\+[0-9]*;/worker_rlimit_nofile 300000;/' "$NGINX_CONF"
    else
        sed -i '/^worker_processes/a worker_rlimit_nofile 300000;' "$NGINX_CONF"
    fi
    ok 'Nginx: worker_processes=auto rlimit=300000'
else
    warn 'nginx.conf nao encontrado'
fi

step 'Parametros de kernel'
cp "$SCRIPT_DIR/configs/sysctl.conf" /etc/sysctl.d/99-nxc.conf
/sbin/sysctl -p /etc/sysctl.d/99-nxc.conf -q 2>/dev/null || true
ok 'Sysctl aplicado'

step 'File descriptors (1M)'
cp "$SCRIPT_DIR/configs/limits.conf" /etc/security/limits.d/99-nxc.conf
ok 'Limites: 1M FDs'

step 'Otimizando PHP-FPM'
for p in /home/xc_vm/bin/php/etc/{1,2,3,4}.conf; do
    [[ ! -f "$p" ]] && continue
    # Remover entradas existentes para evitar duplicatas/corrupcao
    sed -i '/^rlimit_files/d' "$p"
    sed -i '/^request_terminate_timeout/d' "$p"
    # Adicionar com newline garantido no inicio (evita concatenar na ultima linha)
    printf '\nrlimit_files = 65535\nrequest_terminate_timeout = 1800\n' >> "$p"
done
ok 'PHP-FPM: rlimit=65535 timeout=1800'

step 'KeyDB tcp-backlog'
KC='/home/xc_vm/bin/redis/redis.conf'
[[ -f "$KC" ]] && sed -i 's/tcp-backlog [0-9]*/tcp-backlog 65535/' "$KC" && ok 'KeyDB: tcp-backlog=65535' || true

step 'UFW Firewall'
ufw --force reset >/dev/null 2>&1
ufw default deny incoming >/dev/null 2>&1; ufw default allow outgoing >/dev/null 2>&1
ufw allow 22/tcp comment 'SSH' >/dev/null 2>&1; ufw allow 80/tcp comment 'HTTP' >/dev/null 2>&1
ufw allow 443/tcp comment 'HTTPS' >/dev/null 2>&1; ufw allow 25461/tcp comment 'NXC API' >/dev/null 2>&1
ufw allow 25462/tcp comment 'NXC RTMP' >/dev/null 2>&1; echo 'y' | ufw enable >/dev/null 2>&1
ok 'UFW: 22 80 443 25461 25462'

step 'Reiniciando servicos'
systemctl daemon-reload
systemctl restart mariadb 2>/dev/null || true; sleep 5
systemctl restart xc_vm 2>/dev/null || true; sleep 8
ok 'Servicos reiniciados'

rm -rf "$INSTALL_TMP" 2>/dev/null || true

step 'Verificacao final'
systemctl is-active xc_vm >/dev/null && echo '  xc_vm:   ATIVO' || echo '  xc_vm:   INATIVO'
systemctl is-active mariadb >/dev/null && echo '  mariadb: ATIVO' || echo '  mariadb: INATIVO'
ss -tlnp | grep -E ':80|:443|:3306|:6379' 2>/dev/null || true
echo ''
echo '=============================================='
echo '     NXC INSTALADO COM SUCESSO!'
echo '=============================================='
SERVER_IP=$(hostname -I | awk '{print $1}')
ACCESS_URL=$(/home/xc_vm/tools access 2>/dev/null | grep -oP 'http[s]?://[^\s]+' | head -1 || echo "http://$SERVER_IP/")
echo "  URL de acesso:  $ACCESS_URL"
echo "  IP do servidor: $SERVER_IP"
echo '  Criar conta admin: /home/xc_vm/tools user'
CREDS=$(find /root -name 'credentials.txt' 2>/dev/null | head -1)
[[ -n "$CREDS" ]] && echo "  MariaDB credenciais: cat $CREDS" || true
echo ''