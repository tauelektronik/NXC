#!/bin/bash
set -e

LIVE_PHP="/home/xc_vm/www/stream/live.php"
BACKUP="/home/xc_vm/www/stream/live.php.bak_$(date +%Y%m%d_%H%M%S)"

echo "=== BACKUP do live.php ==="
cp "$LIVE_PHP" "$BACKUP"
echo "Backup salvo em: $BACKUP"

echo ""
echo "=== APLICANDO CORRECAO NO live.php ==="

# The fix: add "else { break; }" so the loop exits when stream is dead
# instead of spinning at 100% CPU forever.
#
# BEFORE (buggy):
#   if (StreamingUtilities::isStreamRunning($rChannelInfo["pid"], $rStreamID)) {
#       sleep(1);
#       $rFails++;
#   }
#   // ^^^ When stream is NOT running: no sleep, no fail increment = infinite loop!
#
# AFTER (fixed):
#   if (StreamingUtilities::isStreamRunning($rChannelInfo["pid"], $rStreamID)) {
#       sleep(1);
#       $rFails++;
#   } else {
#       break; // stream is dead, exit inner loop to trigger recovery/exit
#   }

python3 - <<'PYEOF'
with open('/home/xc_vm/www/stream/live.php', 'r') as f:
    content = f.read()

# The exact buggy block to replace
old_block = '''                    if (StreamingUtilities::isStreamRunning($rChannelInfo["pid"], $rStreamID)) {
                        sleep(1); // <-- here is the biggest delay!
                        $rFails++;
                    }'''

new_block = '''                    if (StreamingUtilities::isStreamRunning($rChannelInfo["pid"], $rStreamID)) {
                        sleep(1); // <-- here is the biggest delay!
                        $rFails++;
                    } else {
                        // BUGFIX: stream is dead - break to prevent 100% CPU infinite loop
                        // The recovery code after this loop will handle restart or exit
                        break;
                    }'''

if old_block in content:
    content = content.replace(old_block, new_block)
    with open('/home/xc_vm/www/stream/live.php', 'w') as f:
        f.write(content)
    print("OK: Patch aplicado com sucesso!")
else:
    print("ERRO: Bloco nao encontrado - verificar manualmente")
    exit(1)
PYEOF

echo ""
echo "=== VERIFICANDO CORRECAO ==="
grep -n "BUGFIX\|break;\|isStreamRunning" "$LIVE_PHP" | head -20

echo ""
echo "=== APLICANDO SAFETY NET: request_terminate_timeout nos pools PHP-FPM ==="
# 1800 segundos (30 min) como segurança final.
# Conexões legítimas reconectam automaticamente via cliente HLS.
for conf in /home/xc_vm/bin/php/etc/{1,2,3,4}.conf; do
    if grep -q "request_terminate_timeout" "$conf"; then
        echo "Já existe em $conf, pulando."
    else
        # Add after pm.process_idle_timeout line
        sed -i '/pm\.process_idle_timeout/a request_terminate_timeout = 1800' "$conf"
        echo "Adicionado request_terminate_timeout = 1800 em $conf"
    fi
done

echo ""
echo "=== VERIFICANDO POOLS ==="
grep -E "request_terminate_timeout|pm\.process_idle_timeout" /home/xc_vm/bin/php/etc/*.conf

echo ""
echo "=== REINICIANDO PHP-FPM (reload gracioso) ==="
systemctl reload xc_vm 2>/dev/null || systemctl restart xc_vm
sleep 3
systemctl is-active xc_vm

echo ""
echo "=== VERIFICACAO FINAL - LOAD ==="
uptime

echo ""
echo "=== PROCESSOS TRAVADOS RESTANTES ==="
ps aux | grep php-fpm | grep " R " | grep -v grep | wc -l

echo ""
echo "CORRECAO CONCLUIDA!"
echo "- live.php: loop infinito corrigido (break quando stream morto)"
echo "- PHP-FPM: request_terminate_timeout=1800 adicionado como safety net"
