#!/usr/bin/env python3
"""
NXC - Adiciona aba Fail2Ban no Settings do painel admin
Insere um link para fail2ban.php na barra de abas do settings.php
"""
import sys, subprocess

PATH = "/home/xc_vm/admin/settings.php"

try:
    with open(PATH, 'r', errors='replace') as f:
        content = f.read()
except FileNotFoundError:
    print(f"ERRO: {PATH} nao encontrado")
    sys.exit(1)

if 'fail2ban' in content.lower():
    print("Aba Fail2Ban ja existe no settings.php - OK")
    sys.exit(0)

# Encontrar a aba Info e adicionar Fail2Ban depois
TAB = '''									<li class="nav-item">
										<a href="fail2ban" class="nav-link rounded-0 pt-2 pb-2"> <i
												class="mdi mdi-shield-lock-outline mr-1"></i><span
												class="d-none d-sm-inline">Fail2Ban</span></a>
									</li>'''

# Inserir depois do fechamento da aba Info
marker = '<span\n\t\t\t\t\t\t\t\t\t\t\t\tclass="d-none d-sm-inline">Info</span></a>\n\t\t\t\t\t\t\t\t\t</li>'

if marker in content:
    content = content.replace(marker, marker + '\n' + TAB)
    with open(PATH, 'w') as f:
        f.write(content)
    subprocess.run(['chown', 'xc_vm:xc_vm', PATH], check=False)
    print("Aba Fail2Ban adicionada ao settings.php")
    sys.exit(0)

# Fallback: tentar com sed-style
import re
pattern = r'(class="d-none d-sm-inline">Info</span></a>\s*</li>)'
match = re.search(pattern, content)
if match:
    insert_pos = match.end()
    content = content[:insert_pos] + '\n' + TAB + '\n' + content[insert_pos:]
    with open(PATH, 'w') as f:
        f.write(content)
    subprocess.run(['chown', 'xc_vm:xc_vm', PATH], check=False)
    print("Aba Fail2Ban adicionada (fallback regex)")
    sys.exit(0)

print("AVISO: padrao Info tab nao encontrado - adicionar manualmente")
sys.exit(0)
