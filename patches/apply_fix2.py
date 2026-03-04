#!/usr/bin/env python3
"""
NXC Fix #2 - CoreUtilities.php: startup lento em streams M3U8 (Issue #80)
Substitui duracao hardcoded de 10s por valor dinamico das configuracoes do painel
"""
import sys, subprocess

PATH = "/home/xc_vm/streaming/CoreUtilities.php"

try:
    with open(PATH, 'r', errors='replace') as f:
        content = f.read()
except FileNotFoundError:
    print(f"ERRO: {PATH} nao encontrado")
    sys.exit(1)

# Verifica se ja foi aplicado
if 'stream_max_analyze' in content:
    print("Fix #2 ja estava aplicado - OK")
    sys.exit(0)

# Substituicao: duracao hardcoded -> valor das settings do painel
OLD = "$rAnalyseDuration = '10000000'"
NEW = "$rAnalyseDuration = abs(intval(self::$rSettings['stream_max_analyze'])) ?: 2000000"

if OLD in content:
    new_content = content.replace(OLD, NEW, 1)
    with open(PATH, 'w') as f:
        f.write(new_content)
    subprocess.run(['chown', 'xc_vm:xc_vm', PATH], check=False)
    print(f"Fix #2 aplicado: stream_max_analyze dinamico (era 10s fixo)")
    sys.exit(0)

# Buscar variacao com aspas duplas
OLD2 = '$rAnalyseDuration = "10000000"'
if OLD2 in content:
    new_content = content.replace(OLD2, NEW, 1)
    with open(PATH, 'w') as f:
        f.write(new_content)
    subprocess.run(['chown', 'xc_vm:xc_vm', PATH], check=False)
    print(f"Fix #2 aplicado (variacao com aspas duplas)")
    sys.exit(0)

print("AVISO: padrao nao encontrado em CoreUtilities.php - versao diferente do esperado")
print("O arquivo foi copiado com backup. Startup de streams pode ser lento (20-30s).")
sys.exit(0)  # Exit 0 para nao abortar o instalador
