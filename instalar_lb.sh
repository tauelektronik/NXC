#!/bin/bash
# ============================================================
#  NXC — Instalador do Load Balancer
#  Instalar em servidor SEPARADO do painel principal
# ============================================================

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

ok()   { echo -e "${GREEN}[✓]${NC} $1"; }
info() { echo -e "${CYAN}[i]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }
step() { echo -e "\n${BOLD}${CYAN}══ $1 ══${NC}"; }

clear
echo -e "${CYAN}"
cat << 'EOF'
  _   _  __  __  ____  — Load Balancer
 | \ | ||  \/  |/ ___|
 |  \| || |\/| | |
 | |\  || |  | | |___
 |_| \_||_|  |_|\____|
EOF
echo -e "${NC}"

[[ $EUID -ne 0 ]] && err "Execute como root: sudo bash instalar_lb.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BOLD}Este script instala o Load Balancer NXC neste servidor.${NC}"
echo ""
echo -e "${YELLOW}IMPORTANTE:${NC} O Load Balancer deve ser instalado em um servidor"
echo "SEPARADO do painel principal. Após instalar, adicione este"
echo "servidor na seção 'Servers' do painel NXC."
echo ""
read -rp "$(echo -e "${YELLOW}IP do servidor principal NXC (para referência):${NC} ")" MAIN_IP
read -rp "$(echo -e "${YELLOW}Confirmar instalação do LB? (s/N):${NC} ")" confirm
[[ "$confirm" != "s" && "$confirm" != "S" ]] && exit 0

CPU_COUNT=$(nproc)
TOTAL_RAM_GB=$(awk '/MemTotal/ {print int($2/1024/1024)}' /proc/meminfo)

step "Preparando sistema"
export DEBIAN_FRONTEND=noninteractive
apt-mark hold grub-efi-amd64 grub-efi-amd64-bin grub-efi-amd64-signed grub-common grub2-common shim-signed 2>/dev/null || true
rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/cache/apt/archives/lock 2>/dev/null || true
dpkg --configure -a --force-confdef --force-confold 2>/dev/null || true
apt-get update -qq
apt-get full-upgrade -y -qq
apt-get install -y -qq python3-pip unzip ufw
ok "Sistema pronto"

step "Instalando Load Balancer"
if [[ ! -f "$SCRIPT_DIR/loadbalancer.tar.gz" ]]; then
    err "Arquivo loadbalancer.tar.gz não encontrado em $SCRIPT_DIR"
fi

LB_TMP=$(mktemp -d)
info "Extraindo loadbalancer.tar.gz..."
tar -xzf "$SCRIPT_DIR/loadbalancer.tar.gz" -C "$LB_TMP"

LB_INSTALL=$(find "$LB_TMP" -name "install" -maxdepth 3 | head -1 | xargs dirname 2>/dev/null || echo "$LB_TMP")
cd "$LB_INSTALL"
echo -e "\n\n\nY" | python3 install
cd "$SCRIPT_DIR"
ok "Load Balancer instalado"

step "Otimizando parâmetros do kernel"
cp "$SCRIPT_DIR/configs/sysctl.conf" /etc/sysctl.d/99-nxc-lb.conf
/sbin/sysctl -p /etc/sysctl.d/99-nxc-lb.conf -q
cp "$SCRIPT_DIR/configs/limits.conf" /etc/security/limits.d/99-nxc.conf
ok "Parâmetros de rede e limites aplicados"

step "Configurando UFW"
ufw --force reset >/dev/null 2>&1
ufw default deny incoming >/dev/null 2>&1
ufw default allow outgoing >/dev/null 2>&1
ufw allow 22/tcp >/dev/null 2>&1
ufw allow 80/tcp >/dev/null 2>&1
ufw allow 443/tcp >/dev/null 2>&1
ufw allow 8080/tcp >/dev/null 2>&1
ufw allow 25461/tcp >/dev/null 2>&1
ufw allow 25462/tcp >/dev/null 2>&1
# Permitir acesso do painel principal
[[ -n "$MAIN_IP" ]] && ufw allow from "$MAIN_IP" comment 'NXC Main Panel' >/dev/null 2>&1
echo "y" | ufw enable >/dev/null 2>&1
ok "UFW configurado"

rm -rf "$LB_TMP"
systemctl daemon-reload

LB_IP=$(hostname -I | awk '{print $1}')

echo ""
echo -e "${GREEN}${BOLD}╔═══════════════════════════════════════════════════════╗"
echo -e "║       LOAD BALANCER INSTALADO COM SUCESSO!            ║"
echo -e "╚═══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BOLD}IP deste LB:${NC}  ${CYAN}$LB_IP${NC}"
echo ""
echo -e "  ${YELLOW}Próximos passos:${NC}"
echo "  1. Acesse o painel NXC em http://$MAIN_IP/"
echo "  2. Vá em: Servers → Add Server"
echo "  3. Informe o IP: $LB_IP"
echo "  4. Porta HTTP: 8080  |  Porta RTMP: 25462"
echo ""
