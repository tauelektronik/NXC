#!/bin/bash
# ============================================================
#  NXC — Instalador Completo v1.2.16 (com todos os fixes)
#  Baseado no XC_VM de Vateron-Media (AGPL v3.0)
#  https://github.com/Vateron-Media/XC_VM
# ============================================================

set -e

# ── Cores ──
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

ok()   { echo -e "${GREEN}[✓]${NC} $1"; }
info() { echo -e "${CYAN}[i]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }
step() { echo -e "\n${BOLD}${CYAN}══ $1 ══${NC}"; }

# ── Banner ──
clear
echo -e "${CYAN}"
cat << 'EOF'
  _   _  __  __  ____
 | \ | ||  \/  |/ ___|
 |  \| || |\/| | |
 | |\  || |  | | |___
 |_| \_||_|  |_|\____|

  NXC — Painel IPTV (XC_VM v1.2.16 + Fixes)
  Licença: AGPL v3.0
EOF
echo -e "${NC}"

# ── Verificações iniciais ──
step "Verificando pré-requisitos"

[[ $EUID -ne 0 ]] && err "Execute como root: sudo bash instalar.sh"

OS_ID=$(lsb_release -si 2>/dev/null || echo "")
OS_VER=$(lsb_release -sr 2>/dev/null || echo "")
if [[ "$OS_ID" != "Ubuntu" ]]; then
    warn "Sistema detectado: $OS_ID $OS_VER"
    warn "NXC foi testado em Ubuntu 22.04 LTS. Outros sistemas podem ter problemas."
    read -rp "Continuar mesmo assim? (s/N): " resp
    [[ "$resp" != "s" && "$resp" != "S" ]] && exit 0
else
    ok "Ubuntu $OS_VER detectado"
fi

# Detectar hardware
TOTAL_RAM_MB=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
TOTAL_RAM_GB=$((TOTAL_RAM_MB / 1024))
CPU_COUNT=$(nproc)
ok "CPU: ${CPU_COUNT} threads | RAM: ${TOTAL_RAM_GB} GB"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
info "Diretório do instalador: $SCRIPT_DIR"

echo ""
echo -e "${BOLD}Este instalador irá:${NC}"
echo "  • Instalar o NXC (XC_VM v1.2.16) em /home/xc_vm/"
echo "  • Aplicar todos os fixes de produção (Redis, live.php, CoreUtilities, conexões)"
echo "  • Otimizar MariaDB, Nginx, PHP-FPM e parâmetros do kernel"
echo "  • Configurar UFW (firewall)"
echo ""
read -rp "$(echo -e "${YELLOW}Confirmar instalação? (s/N):${NC} ")" confirm
[[ "$confirm" != "s" && "$confirm" != "S" ]] && { info "Instalação cancelada."; exit 0; }

# ── Fix GRUB (evita travar o apt) ──
step "Corrigindo pacotes GRUB (se necessário)"
apt-mark hold grub-efi-amd64 grub-efi-amd64-bin grub-efi-amd64-signed grub-common grub2-common shim-signed 2>/dev/null || true
rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/cache/apt/archives/lock 2>/dev/null || true
dpkg --configure -a --force-confdef --force-confold 2>/dev/null || true
ok "GRUB verificado"

# ── Atualizar sistema ──
step "Atualizando sistema"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get full-upgrade -y -qq
apt-get install -y -qq python3-pip unzip curl wget ufw
ok "Sistema atualizado"

# ── Instalar XC_VM ──
step "Instalando XC_VM v1.2.16"

if [[ ! -f "$SCRIPT_DIR/XC_VM.zip" ]]; then
    err "Arquivo XC_VM.zip não encontrado em $SCRIPT_DIR"
fi

INSTALL_TMP=$(mktemp -d)
info "Extraindo XC_VM.zip..."
unzip -q "$SCRIPT_DIR/XC_VM.zip" -d "$INSTALL_TMP"

# Encontrar o diretório de instalação
XC_INSTALL_DIR=$(find "$INSTALL_TMP" -name "install" -maxdepth 3 | head -1 | xargs dirname)
if [[ -z "$XC_INSTALL_DIR" ]]; then
    err "Arquivo 'install' não encontrado dentro do XC_VM.zip"
fi

info "Executando instalador oficial XC_VM..."
cd "$XC_INSTALL_DIR"
echo -e "\n\n\nY" | python3 install
cd "$SCRIPT_DIR"
ok "XC_VM instalado em /home/xc_vm/"

# Aguardar serviço iniciar
info "Aguardando serviços iniciarem..."
sleep 10

# ── Fix #4: Redis / KeyDB ──
step "Fix #4 — Redis server-threads (evita HTTP 500)"
python3 "$SCRIPT_DIR/patches/fix_redis.py"
ok "Redis corrigido (server-threads 1)"

# ── Fix #1 e #2: live.php + CoreUtilities.php ──
step "Fix #1 — live.php (loop infinito / CPU 100%)"
LIVE_PHP_PATH="/home/xc_vm/www/stream/live.php"
if [[ -f "$LIVE_PHP_PATH" ]]; then
    cp "$LIVE_PHP_PATH" "${LIVE_PHP_PATH}.bak.$(date +%Y%m%d_%H%M%S)"
    cp "$SCRIPT_DIR/patches/live.php" "$LIVE_PHP_PATH"
    chown xc_vm:xc_vm "$LIVE_PHP_PATH"
    ok "live.php atualizado com fix do loop infinito"
else
    warn "live.php não encontrado em $LIVE_PHP_PATH — pulando fix #1"
fi

step "Fix #2 — CoreUtilities.php (startup lento M3U8)"
CORE_PHP_PATH="/home/xc_vm/streaming/CoreUtilities.php"
if [[ -f "$CORE_PHP_PATH" ]]; then
    cp "$CORE_PHP_PATH" "${CORE_PHP_PATH}.bak.$(date +%Y%m%d_%H%M%S)"
    cp "$SCRIPT_DIR/patches/CoreUtilities.php" "$CORE_PHP_PATH"
    chown xc_vm:xc_vm "$CORE_PHP_PATH"
    ok "CoreUtilities.php atualizado (stream_max_analyze dinâmico)"
else
    warn "CoreUtilities.php não encontrado em $CORE_PHP_PATH — pulando fix #2"
fi

# ── Fix #3: Conexões fantasma ──
step "Fix #3 — Limpar conexões fantasma no banco"
DB_CMD="mariadb --defaults-file=/etc/mysql/debian.cnf xc_vm"
$DB_CMD -e "UPDATE lines_live SET hls_end=1 WHERE hls_end=0 AND (hls_last_read IS NULL OR hls_last_read < UNIX_TIMESTAMP()-300);" 2>/dev/null && \
    ok "Conexões fantasma limpas" || \
    warn "Não foi possível executar fix #3 (banco pode ainda não estar pronto)"

# ── Otimizar MariaDB ──
step "Otimizando MariaDB (RAM: ${TOTAL_RAM_GB}GB)"
BUFFER_POOL_GB=$(( TOTAL_RAM_GB * 55 / 100 ))
[[ $BUFFER_POOL_GB -lt 1 ]] && BUFFER_POOL_GB=1
BUFFER_INSTANCES=$(( CPU_COUNT > 64 ? 64 : CPU_COUNT ))
[[ $BUFFER_INSTANCES -lt 1 ]] && BUFFER_INSTANCES=1

sed \
    -e "s/{{BUFFER_POOL}}/${BUFFER_POOL_GB}G/g" \
    -e "s/{{BUFFER_INSTANCES}}/${BUFFER_INSTANCES}/g" \
    -e "s/{{THREAD_POOL}}/${CPU_COUNT}/g" \
    "$SCRIPT_DIR/configs/mariadb.cnf.template" > /etc/mysql/mariadb.conf.d/99-nxc.cnf

ok "MariaDB: buffer_pool=${BUFFER_POOL_GB}GB, threads=${CPU_COUNT}"

# ── Otimizar Nginx ──
step "Otimizando Nginx"
NGINX_CONF="/home/xc_vm/bin/nginx/conf/nginx.conf"
if [[ -f "$NGINX_CONF" ]]; then
    cp "$NGINX_CONF" "${NGINX_CONF}.bak.$(date +%Y%m%d_%H%M%S)"
    sed \
        -e "s/{{CPU_COUNT}}/${CPU_COUNT}/g" \
        "$SCRIPT_DIR/configs/nginx.conf.template" > "$NGINX_CONF"
    ok "Nginx: ${CPU_COUNT} workers"
else
    warn "nginx.conf não encontrado — usando configuração padrão"
fi

# ── Sysctl / Kernel ──
step "Aplicando parâmetros de kernel"
cp "$SCRIPT_DIR/configs/sysctl.conf" /etc/sysctl.d/99-nxc.conf
/sbin/sysctl -p /etc/sysctl.d/99-nxc.conf -q
ok "Parâmetros de rede aplicados"

# ── Limites do sistema ──
step "Configurando limites de file descriptors"
cp "$SCRIPT_DIR/configs/limits.conf" /etc/security/limits.d/99-nxc.conf
ok "Limites: 1M file descriptors para root e xc_vm"

# ── PHP-FPM: rlimit_files ──
step "Otimizando PHP-FPM"
for pool_conf in /home/xc_vm/bin/php/etc/{1,2,3,4}.conf; do
    if [[ -f "$pool_conf" ]]; then
        if grep -q "rlimit_files" "$pool_conf"; then
            sed -i "s/rlimit_files = [0-9]*/rlimit_files = 65535/" "$pool_conf"
        else
            echo "rlimit_files = 65535" >> "$pool_conf"
        fi
        if grep -q "request_terminate_timeout" "$pool_conf"; then
            sed -i "s/request_terminate_timeout = .*/request_terminate_timeout = 1800/" "$pool_conf"
        else
            echo "request_terminate_timeout = 1800" >> "$pool_conf"
        fi
    fi
done
ok "PHP-FPM: rlimit_files=65535, request_terminate_timeout=1800"

# ── KeyDB tcp-backlog ──
step "Otimizando KeyDB"
KEYDB_CONF="/home/xc_vm/bin/redis/redis.conf"
if [[ -f "$KEYDB_CONF" ]]; then
    sed -i "s/tcp-backlog [0-9]*/tcp-backlog 65535/" "$KEYDB_CONF"
    ok "KeyDB: tcp-backlog=65535"
fi

# ── Firewall UFW ──
step "Configurando UFW (firewall)"
ufw --force reset >/dev/null 2>&1
ufw default deny incoming >/dev/null 2>&1
ufw default allow outgoing >/dev/null 2>&1
ufw allow 22/tcp comment 'SSH' >/dev/null 2>&1
ufw allow 80/tcp comment 'HTTP' >/dev/null 2>&1
ufw allow 443/tcp comment 'HTTPS' >/dev/null 2>&1
ufw allow 25461/tcp comment 'NXC API' >/dev/null 2>&1
ufw allow 25462/tcp comment 'NXC RTMP' >/dev/null 2>&1
echo "y" | ufw enable >/dev/null 2>&1
ok "UFW ativo: portas 22, 80, 443, 25461, 25462 abertas"

# ── Reiniciar tudo ──
step "Reiniciando serviços"
systemctl daemon-reload
systemctl restart mariadb
sleep 3
systemctl restart xc_vm
sleep 5
/home/xc_vm/bin/nginx/sbin/nginx -s reload 2>/dev/null || true
ok "Serviços reiniciados"

# ── Limpeza ──
rm -rf "$INSTALL_TMP"

# ── Verificação final ──
step "Verificação final"
bash "$SCRIPT_DIR/scripts/healthcheck.sh" 2>/dev/null || true

# ── URL de acesso ──
echo ""
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════╗"
echo -e "║          NXC INSTALADO COM SUCESSO!              ║"
echo -e "╚══════════════════════════════════════════════════╝${NC}"
echo ""

SERVER_IP=$(hostname -I | awk '{print $1}')
ACCESS_URL=$(/home/xc_vm/tools access 2>/dev/null | grep -oP 'http[s]?://[^\s]+' | head -1 || echo "http://$SERVER_IP/")

echo -e "  ${BOLD}URL de acesso:${NC}   ${CYAN}$ACCESS_URL${NC}"
echo -e "  ${BOLD}Servidor IP:${NC}     ${CYAN}$SERVER_IP${NC}"
echo ""
echo -e "  ${YELLOW}Para criar conta admin:${NC}"
echo -e "  ${BOLD}/home/xc_vm/tools user${NC}"
echo ""
echo -e "  ${YELLOW}Para diagnóstico:${NC}"
echo -e "  ${BOLD}bash $SCRIPT_DIR/scripts/healthcheck.sh${NC}"
echo ""
echo -e "  ${YELLOW}Credenciais MariaDB:${NC}"
CREDS_FILE=$(find /root -name "credentials.txt" 2>/dev/null | head -1)
[[ -n "$CREDS_FILE" ]] && echo -e "  ${BOLD}cat $CREDS_FILE${NC}" || echo -e "  Arquivo de credenciais não encontrado."
echo ""
