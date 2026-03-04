# NXC — Painel IPTV

**NXC** é uma distribuição pré-configurada e corrigida do [XC_VM](https://github.com/Vateron-Media/XC_VM) v1.2.16, com todos os fixes de produção já aplicados e instalador automatizado em português.

> Licença: [AGPL v3.0](https://www.gnu.org/licenses/agpl-3.0.html) — Uso responsável do operador.

---

## O que está incluído

| Item | Descrição |
|------|-----------|
| `XC_VM.zip` | XC_VM v1.2.16 (instalação completa) |
| `loadbalancer.tar.gz` | Load Balancer separado |
| `instalar.sh` | Instalador automatizado (1 comando) |
| `instalar_lb.sh` | Instalador do Load Balancer |
| `patches/` | Fixes de produção já aplicados |
| `configs/` | Configurações otimizadas |
| `scripts/` | Utilitários (diagnóstico, fix emergencial) |

### Fixes incluídos

| Fix | Issue | Descrição |
|-----|-------|-----------|
| **#1** | — | `live.php`: loop infinito → CPU 100% quando stream cai |
| **#2** | #80 | `CoreUtilities.php`: startup lento de 20-30s em M3U8 on-demand |
| **#3** | #91 | Conexões fantasma no dashboard |
| **#4** | #88 | Redis/KeyDB: HTTP 500 por `server-threads` inválido |

---

## Requisitos do Servidor

### Mínimo (até ~500 usuários)
- Ubuntu **22.04 LTS** (obrigatório)
- 6 CPUs / 16 GB RAM / 100 GB SSD
- 1 Gbps de rede dedicada

### Recomendado (até ~5.000 usuários)
- Ubuntu **22.04 LTS**
- 16+ CPUs / 64+ GB RAM / 480+ GB SSD NVMe
- 1 Gbps dedicado

### Alta escala (10.000+ usuários)
- Ubuntu **22.04 LTS**
- 32+ CPUs / 128+ GB RAM / 1+ TB NVMe
- 10 Gbps de rede

> **Atenção:** Ubuntu 18.04 não é suportado (EOL). Ubuntu 24.04 não testado.

### Pré-requisitos
- Acesso `root` ao servidor
- Ubuntu 22.04 LTS limpo (fresh install recomendado)
- Conexão de internet no servidor (para `apt update`)
- Portas liberadas no provedor: **22**, **80**, **443**, **25461**, **25462**

---

## Instalação

### Passo 1 — Clonar o repositório no servidor

```bash
# Instale git-lfs primeiro (necessário para os binários)
apt-get install -y git git-lfs

# Clonar o repositório
git clone https://github.com/SEU_USUARIO/NXC.git
cd NXC
git lfs pull
```

### Passo 2 — Executar o instalador

```bash
sudo bash instalar.sh
```

O instalador irá:
1. Verificar o sistema (Ubuntu 22.04 + root)
2. Atualizar pacotes do sistema
3. Instalar o XC_VM v1.2.16
4. Aplicar todos os 4 fixes de produção automaticamente
5. Otimizar MariaDB, Nginx, PHP-FPM e parâmetros de kernel
6. Configurar o firewall (UFW)
7. Exibir a URL de acesso ao painel

**Tempo estimado:** 10–20 minutos (depende da velocidade do servidor)

### Passo 3 — Criar conta administrador

Após a instalação, execute:

```bash
/home/xc_vm/tools user
```

---

## Primeiro Acesso

1. Acesse a URL exibida ao final da instalação
2. Faça login com a conta criada em `/home/xc_vm/tools user`
3. Configure:
   - **Settings → Main Settings**: URL/domínio do painel
   - **Settings → Streaming**: portas e protocolos
   - **Servers**: adicione o IP do servidor (e Load Balancer se houver)
   - **TMDb API Key** (opcional — para metadados de filmes/séries)

---

## Instalar Load Balancer (servidor secundário)

O Load Balancer distribui o tráfego de streaming para um segundo servidor, liberando o principal para gerenciamento.

### No servidor LB (Ubuntu 22.04):

```bash
git clone https://github.com/SEU_USUARIO/NXC.git
cd NXC
git lfs pull
sudo bash instalar_lb.sh
```

### No painel NXC:
- **Servers → Add Server**
- IP do LB, porta HTTP: `8080`, porta RTMP: `25462`

---

## Manutenção

### Diagnóstico completo

```bash
bash /caminho/NXC/scripts/healthcheck.sh
```

Verifica: serviços, PHP-FPM, fixes aplicados, banco de dados, portas de rede.

### Fix emergencial (CPU 100%)

Se o servidor travar com CPU em 100% por PHP-FPM travado:

```bash
bash /caminho/NXC/scripts/fix_now.sh
```

### Reaplicar fixes após atualização

Se atualizar o XC_VM pelo painel e os fixes forem sobrescritos:

```bash
bash /caminho/NXC/scripts/fix_permanent.sh
```

### Comandos úteis do XC_VM

```bash
# Status dos serviços
systemctl status xc_vm mariadb

# URL de acesso ao painel
/home/xc_vm/tools access

# Criar/resetar conta admin
/home/xc_vm/tools user

# Diagnóstico de stream específico
sudo -u xc_vm /home/xc_vm/bin/php/bin/php /home/xc_vm/includes/cli/monitor.php <STREAM_ID>

# Reiniciar tudo
systemctl restart mariadb xc_vm
/home/xc_vm/bin/nginx/sbin/nginx -s reload
```

---

## Acesso Remoto ao MariaDB

Para acessar o banco de dados do seu PC (ex: DBeaver, HeidiSQL):

```sql
-- Execute no servidor como root:
GRANT ALL PRIVILEGES ON xc_vm.* TO 'nxc_admin'@'SEU_IP' IDENTIFIED BY 'SENHA_FORTE';
FLUSH PRIVILEGES;
```

```bash
# Liberar porta no UFW:
ufw allow from SEU_IP to any port 3306 proto tcp
```

---

## Migração do XtreamUI

Para migrar dados de um painel XtreamUI existente:

```bash
# 1. No servidor XtreamUI antigo — gerar backup:
mysqldump --defaults-file=/etc/mysql/debian.cnf xtream_iptvpro \
  --no-tablespaces --single-transaction > /tmp/backup_xtreamui.sql

# 2. Copiar para o servidor NXC:
scp /tmp/backup_xtreamui.sql root@IP_NXC:/tmp/

# 3. No servidor NXC — executar migração:
/home/xc_vm/tools migration "/tmp/backup_xtreamui.sql"
/home/xc_vm/bin/php/bin/php /home/xc_vm/includes/cli/migrate.php

# 4. Corrigir IP do servidor no banco:
mariadb xc_vm -e "UPDATE servers SET server_ip='IP_NXC' WHERE server_ip='IP_ANTIGO';"

# 5. Recuperar acesso:
/home/xc_vm/tools access
/home/xc_vm/tools user
```

> O que migra automaticamente: streams, usuários, revendedores, categorias, bouquets, pacotes, EPG.
> O que requer reconfiguração manual: settings do painel, SSL, Load Balancers, API keys.

---

## Portas Utilizadas

| Porta | Protocolo | Função |
|-------|-----------|--------|
| 22 | TCP | SSH |
| 80 | TCP | HTTP (painel + streaming) |
| 443 | TCP | HTTPS |
| 25461 | TCP | NXC API interna |
| 25462 | TCP | RTMP streaming |
| 8080 | TCP | Load Balancer HTTP |
| 3306 | TCP | MariaDB (fechar para internet) |

---

## Changelog de Fixes

### v1.2.16-nxc1 (2026-03-04)
- **Fix #4**: Redis/KeyDB `server-threads 1` — elimina HTTP 500 no v1.2.16
- **Fix #1**: `live.php` — adiciona `else { break; }` no loop de streaming (elimina CPU 100%)
- **Fix #2**: `CoreUtilities.php` — usa `stream_max_analyze` dinâmico (elimina startup 20-30s em M3U8)
- **Fix #3**: SQL para limpar conexões fantasma em `lines_live`
- Otimizações de MariaDB, Nginx, PHP-FPM, sysctl e limits para alta escala

---

## Estrutura do Repositório

```
NXC/
├── instalar.sh              # Instalador principal (execute este)
├── instalar_lb.sh           # Instalador do Load Balancer
├── XC_VM.zip                # XC_VM v1.2.16 completo
├── loadbalancer.tar.gz      # Load Balancer
├── hashes.md5               # Verificação de integridade
├── patches/
│   ├── live.php             # Fix #1: loop infinito
│   ├── CoreUtilities.php    # Fix #2: startup lento
│   ├── fix_redis.py         # Fix #4: Redis server-threads
│   └── fix_orphans.sql      # Fix #3: conexões fantasma
├── configs/
│   ├── mariadb.cnf.template # MariaDB otimizado
│   ├── nginx.conf.template  # Nginx otimizado
│   ├── sysctl.conf          # Kernel: rede e I/O
│   └── limits.conf          # File descriptors 1M
└── scripts/
    ├── healthcheck.sh       # Diagnóstico completo
    ├── fix_now.sh           # Fix emergencial CPU
    └── fix_permanent.sh     # Reaplicar fixes
```

---

## Licença

Este projeto é distribuído sob a licença **AGPL v3.0**, seguindo a licença do projeto original [XC_VM](https://github.com/Vateron-Media/XC_VM).

O uso de painéis IPTV para distribuição de conteúdo protegido por direitos autorais sem autorização é ilegal. O operador é inteiramente responsável pelo uso desta ferramenta.

---

## Créditos

- **XC_VM original**: [Vateron-Media/XC_VM](https://github.com/Vateron-Media/XC_VM) — AGPL v3.0
- **NXC**: Distribuição com fixes e instalador automatizado
