# NXC — Painel IPTV

**NXC** e uma distribuicao pre-configurada e corrigida do [XC_VM](https://github.com/Vateron-Media/XC_VM) v1.2.16, com todos os fixes de producao, seguranca, painel Fail2Ban integrado e instalador automatizado.

> Licenca: [AGPL v3.0](https://www.gnu.org/licenses/agpl-3.0.html) — Uso responsavel do operador.

---

## O que esta incluido

| Item | Descricao |
|------|-----------|
| `XC_VM.zip` | XC_VM v1.2.16 (instalacao completa) |
| `loadbalancer.tar.gz` | Load Balancer separado |
| `instalar.sh` | Instalador automatizado (1 comando) |
| `instalar_lb.sh` | Instalador do Load Balancer |
| `admin/fail2ban.php` | Painel Fail2Ban integrado ao admin |
| `patches/` | Fixes de producao + patches admin |
| `patches/sql/` | Setup de categorias, bouquets e pacotes |
| `configs/` | Configuracoes otimizadas |
| `configs/security/` | Fail2Ban + sudoers |
| `scripts/` | Utilitarios (diagnostico, fix emergencial) |

### Fixes incluidos

| Fix | Issue | Descricao |
|-----|-------|-----------|
| **#1** | — | `live.php`: loop infinito → CPU 100% quando stream cai |
| **#2** | #80 | `CoreUtilities.php`: startup lento de 20-30s em M3U8 on-demand |
| **#3** | #91 | Conexoes fantasma no dashboard |
| **#4** | #88 | Redis/KeyDB: HTTP 500 por `server-threads` invalido |

### Seguranca incluida

| Item | Descricao |
|------|-----------|
| **Fail2Ban** | Instalado e configurado (ban 24h apos 3 tentativas SSH) |
| **SSH porta 2288** | Porta padrao alterada (elimina 99% dos bots) |
| **Painel Fail2Ban** | Pagina no admin para gerenciar bans, whitelist, config |
| **UFW** | Firewall com apenas portas necessarias |
| **Cloudflare** | Ativado no painel XC_VM |
| **Systemd limits** | LimitNOFILE/NPROC 1M |

### Dispositivos

| Item | Status |
|------|--------|
| **MAG** | Habilitado (portal /c/, todos STB types) |
| **Enigma2** | Habilitado |
| **Cloudflare** | Ativado |

---

## Requisitos do Servidor

### Minimo (ate ~500 usuarios)
- Ubuntu **22.04 LTS** (obrigatorio)
- 6 CPUs / 16 GB RAM / 100 GB SSD
- 1 Gbps de rede dedicada

### Recomendado (ate ~5.000 usuarios)
- Ubuntu **22.04 LTS**
- 16+ CPUs / 64+ GB RAM / 480+ GB SSD NVMe
- 1 Gbps dedicado

### Alta escala (10.000+ usuarios)
- Ubuntu **22.04 LTS**
- 32+ CPUs / 128+ GB RAM / 1+ TB NVMe
- 10 Gbps de rede

> **Atencao:** Ubuntu 18.04 nao e suportado (EOL). Ubuntu 24.04 nao testado.

---

## Instalacao

### 1 comando (copiar e colar no servidor como root)

```bash
apt install -y git git-lfs && git clone https://github.com/tauelektronik/NXC.git && cd NXC && git lfs pull && bash instalar.sh
```

O instalador ira:
1. Verificar o sistema (Ubuntu 22.04 + root)
2. Atualizar pacotes do sistema
3. Instalar o XC_VM v1.2.16
4. Aplicar todos os 4 fixes de producao
5. Otimizar MariaDB, Nginx, PHP-FPM e kernel (BBR)
6. Configurar timezone (America/Sao_Paulo)
7. Instalar e configurar Fail2Ban (ban 24h)
8. Mudar SSH para porta 2288
9. Instalar painel Fail2Ban no admin
10. Habilitar MAG + Enigma2 + Portal Ministra
11. Ativar Cloudflare no painel
12. Configurar UFW firewall
13. Configurar systemd limits (1M)
14. Exibir URL de acesso e credenciais

**Tempo estimado:** 10-20 minutos

### Criar conta administrador

```bash
/home/xc_vm/tools user
```

### IMPORTANTE: SSH na porta 2288

Apos instalar, o SSH muda para porta 2288:
```bash
ssh root@SEU_IP -p 2288
```

---

## Primeiro Acesso

1. Acesse a URL exibida ao final da instalacao
2. Faca login com a conta criada em `/home/xc_vm/tools user`
3. Configure:
   - **Settings > General**: URL/dominio do painel
   - **Settings > Streaming**: portas e protocolos
   - **Settings > MAG**: configuracoes MAG
   - **Settings > Fail2Ban**: gerenciar firewall
   - **Servers**: adicione o IP do servidor
   - **TMDb API Key** (opcional)

---

## Painel Fail2Ban

Acesse em **Settings > Fail2Ban** no painel admin. Funcionalidades:

- **Status**: ver se Fail2Ban esta ativo/parado
- **IPs Banidos**: lista com data/hora de cada ban
- **Liberar IP**: botao para desbanir individualmente
- **Banir IP**: campo para banir manualmente
- **Configuracao**: alterar tempo de ban, tentativas, whitelist
- **Top Atacantes**: ranking de IPs com mais tentativas
- **Log**: ultimas tentativas falhas em tempo real
- **Controles**: iniciar/parar/reiniciar Fail2Ban

---

## Setup de Categorias, Bouquets e Pacotes

Templates SQL em `patches/sql/` para organizar profissionalmente:

```bash
# 1. Criar categorias (18 categorias profissionais)
mariadb -u root xc_vm < patches/sql/setup_categorias.sql

# 2. Classificar seus streams nas categorias (adaptar IDs)

# 3. Criar bouquets (populados automaticamente pelas categorias)
mariadb -u root xc_vm < patches/sql/setup_bouquets.sql

# 4. Criar pacotes comerciais
mariadb -u root xc_vm < patches/sql/setup_pacotes.sql
```

### Estrutura de Pacotes

| Pacote | Bouquets | Conexoes |
|--------|----------|----------|
| BASICO | Basico | 1 |
| FAMILIA | Standard + Streaming | 2 |
| COMPLETO | Premium + Streaming + Esportes+ | 2 |
| FULL | Todos (sem Adulto) | 3 |
| FULL ADULTO | Todos | 3 |

---

## Portal MAG

O portal Ministra/Stalker e instalado automaticamente em `/c/`.

**No aparelho MAG:**
- Portal URL: `http://SEU_IP/c/` ou `https://SEU_DOMINIO/c/`

**No painel NXC:**
- MAG Devices > Add MAG Device
- Informar MAC address do aparelho

---

## Instalar Load Balancer (servidor secundario)

```bash
apt install -y git git-lfs && git clone https://github.com/tauelektronik/NXC.git && cd NXC && git lfs pull && bash instalar_lb.sh
```

No painel NXC: **Servers > Add Server** > IP do LB, porta HTTP: `8080`

---

## Manutencao

### Diagnostico completo
```bash
bash /caminho/NXC/scripts/healthcheck.sh
```

### Fix emergencial (CPU 100%)
```bash
bash /caminho/NXC/scripts/fix_now.sh
```

### Reaplicar fixes apos atualizacao
```bash
bash /caminho/NXC/scripts/fix_permanent.sh
```

### Fail2Ban - Comandos uteis
```bash
# Status
sudo fail2ban-client status sshd

# Desbanir IP
sudo fail2ban-client set sshd unbanip 1.2.3.4

# Banir IP
sudo fail2ban-client set sshd banip 1.2.3.4

# Ver log
tail -f /var/log/fail2ban.log
```

### Comandos XC_VM
```bash
# Status dos servicos
systemctl status xc_vm mariadb

# URL de acesso ao painel
/home/xc_vm/tools access

# Criar/resetar conta admin
/home/xc_vm/tools user

# Diagnostico de stream
sudo -u xc_vm /home/xc_vm/bin/php/bin/php /home/xc_vm/includes/cli/monitor.php <STREAM_ID>

# Reiniciar tudo
systemctl restart mariadb xc_vm
/home/xc_vm/bin/nginx/sbin/nginx -s reload
```

---

## Portas Utilizadas

| Porta | Protocolo | Funcao |
|-------|-----------|--------|
| 2288 | TCP | SSH (nao mais 22!) |
| 80 | TCP | HTTP (painel + streaming) |
| 443 | TCP | HTTPS |
| 25461 | TCP | NXC API interna |
| 25462 | TCP | RTMP streaming |
| 8080 | TCP | Load Balancer HTTP |
| 3306 | TCP | MariaDB (fechar para internet) |

---

## Estrutura do Repositorio

```
NXC/
├── instalar.sh                 # Instalador principal
├── instalar_lb.sh              # Instalador Load Balancer
├── XC_VM.zip                   # XC_VM v1.2.16 completo
├── loadbalancer.tar.gz         # Load Balancer
├── hashes.md5                  # Verificacao de integridade
├── admin/
│   └── fail2ban.php            # Painel Fail2Ban integrado
├── patches/
│   ├── live.php                # Fix #1: loop infinito
│   ├── CoreUtilities.php       # Fix #2: startup lento
│   ├── apply_fix1.py           # Aplica fix #1
│   ├── apply_fix2.py           # Aplica fix #2
│   ├── fix_redis.py            # Fix #4: Redis
│   ├── fix_orphans.sql         # Fix #3: conexoes fantasma
│   ├── admin/
│   │   └── add_fail2ban_tab.py # Adiciona aba Fail2Ban ao Settings
│   └── sql/
│       ├── setup_categorias.sql  # 18 categorias profissionais
│       ├── setup_bouquets.sql    # 6 bouquets comerciais
│       ├── setup_pacotes.sql     # 5 pacotes (Basico a Full)
│       └── setup_mag_enigma.sql  # Habilitar MAG + Enigma2
├── configs/
│   ├── mariadb.cnf.template    # MariaDB otimizado
│   ├── nginx.conf.template     # Nginx otimizado
│   ├── sysctl.conf             # Kernel: BBR + rede + I/O
│   ├── limits.conf             # File descriptors 1M
│   └── security/
│       ├── jail.local           # Fail2Ban config
│       └── xc_vm_fail2ban.sudoers  # Sudoers para painel
└── scripts/
    ├── healthcheck.sh           # Diagnostico completo
    ├── fix_now.sh               # Fix emergencial CPU
    └── fix_permanent.sh         # Reaplicar fixes
```

---

## Changelog

### v1.2.16-nxc2 (2026-04-04)
- **Fail2Ban** integrado com painel admin (gerenciar bans, config, whitelist)
- **SSH porta 2288** configurado automaticamente no instalador
- **Portal MAG** (/c/) criado automaticamente
- **MAG + Enigma2** habilitados com todos STB types
- **Cloudflare** ativado automaticamente
- **Timezone** America/Sao_Paulo
- **Systemd limits** LimitNOFILE/NPROC 1M
- **Templates SQL** para categorias, bouquets e pacotes profissionais
- Nginx thread_pool ajustado ao numero de CPUs
- KeyDB maxclients 655350
- Healthcheck expandido (rlimit, BBR, systemd)
- fix_permanent.sh agora corrige tudo (rlimit, redis, orphans)
- sysctl com tcp_keepalive para conexoes streaming

### v1.2.16-nxc1 (2026-03-04)
- Fix #4: Redis/KeyDB `server-threads 1`
- Fix #1: `live.php` loop infinito CPU 100%
- Fix #2: `CoreUtilities.php` M3U8 startup lento
- Fix #3: SQL conexoes fantasma
- Otimizacoes MariaDB, Nginx, PHP-FPM, sysctl, limits

---

## Licenca

Este projeto e distribuido sob a licenca **AGPL v3.0**, seguindo a licenca do projeto original [XC_VM](https://github.com/Vateron-Media/XC_VM).

O uso de paineis IPTV para distribuicao de conteudo protegido por direitos autorais sem autorizacao e ilegal. O operador e inteiramente responsavel pelo uso desta ferramenta.

---

## Creditos

- **XC_VM original**: [Vateron-Media/XC_VM](https://github.com/Vateron-Media/XC_VM) — AGPL v3.0
- **NXC**: Distribuicao com fixes, seguranca e instalador automatizado
