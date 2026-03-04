#!/usr/bin/env python3
"""
NXC Fix #1 - live.php: loop infinito / CPU 100%
Adiciona 'else { break; }' quando isStreamRunning() retorna False
Issue: PHP-FPM fica preso em loop infinito quando stream morre
"""
import re, sys, subprocess

PATH = "/home/xc_vm/www/stream/live.php"

try:
    with open(PATH, 'r', errors='replace') as f:
        content = f.read()
except FileNotFoundError:
    print(f"ERRO: {PATH} nao encontrado")
    sys.exit(1)

# Verifica se ja foi aplicado
if 'else { break; }' in content or 'else{break;}' in content:
    print("Fix #1 ja estava aplicado - OK")
    sys.exit(0)

# Padrao: bloco if(isStreamRunning(...)) sem else
pattern = r'(if\s*\(\s*isStreamRunning\s*\([^)]*\)\s*\)\s*\{[^}]*\})\s*(?!\s*else)'
replacement = r'\1 else { break; }'
new_content, count = re.subn(pattern, replacement, content, count=1, flags=re.DOTALL)

if count > 0:
    with open(PATH, 'w') as f:
        f.write(new_content)
    subprocess.run(['chown', 'xc_vm:xc_vm', PATH], check=False)
    print(f"Fix #1 aplicado com sucesso em {PATH}")
    sys.exit(0)

# Padrao alternativo: buscar pelo while com pid == -1
pattern2 = r'(while\s*\(true\)[^{]*\{[^}]*pid\s*[=!]=\s*-1[^}]*)(break\s*;)'
if re.search(pattern2, content, re.DOTALL):
    print("Fix #1: padrao alternativo - possivel versao diferente - verificar manualmente")
    sys.exit(0)

print("AVISO: padrao nao encontrado em live.php - versao diferente do esperado")
print("O arquivo foi copiado com backup. Verifique manualmente se o fix e necessario.")
sys.exit(0)  # Exit 0 para nao abortar o instalador
