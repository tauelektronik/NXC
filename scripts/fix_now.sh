#!/bin/bash
echo "=== STEP 1: Matando processos PHP-FPM travados (estado R) ==="
STUCK=$(ps aux | grep php-fpm | grep -v grep | grep " R " | awk '{print $2}')
COUNT=$(echo "$STUCK" | grep -c ".")
echo "Processos para matar: $COUNT"
echo "$STUCK" | xargs kill -9 2>/dev/null
echo "Done."

echo ""
echo "=== STEP 2: Reiniciando XC_VM ==="
systemctl restart xc_vm
sleep 5
systemctl is-active xc_vm

echo ""
echo "=== STEP 3: Verificando recuperacao ==="
echo "Load average:"
uptime

echo ""
echo "PHP-FPM processos restantes:"
ps aux | grep php-fpm | grep -v grep | wc -l

echo ""
echo "Processos em R (stuck) restantes:"
ps aux | grep php-fpm | grep -v grep | grep " R " | wc -l

echo ""
echo "=== FIM ==="
