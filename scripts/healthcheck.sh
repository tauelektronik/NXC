#!/bin/bash
echo "============================================================"
echo "  XC_VM HEALTH CHECK - $(date)"
echo "============================================================"

echo ""
echo "=== [1] SISTEMA ==="
echo "Uptime / Load:"
uptime
echo ""
echo "Memoria RAM:"
free -h | grep -E "Mem|Swap"
echo ""
echo "Disco:"
df -h / /home 2>/dev/null | grep -v "^Filesystem"

echo ""
echo "=== [2] SERVICOS ==="
for svc in xc_vm mariadb; do
    status=$(systemctl is-active $svc 2>/dev/null)
    echo "  $svc: $status"
done
echo "  Nginx: $(pgrep -c nginx 2>/dev/null || echo 0) processos"

echo ""
echo "=== [3] PHP-FPM ==="
total=$(ps aux | grep php-fpm | grep -v grep | wc -l)
stuck=$(ps aux | grep php-fpm | grep -v grep | grep " R " | wc -l)
echo "  Total processos: $total"
echo "  Processos R (stuck): $stuck"
if [ "$stuck" -gt "0" ]; then
    echo "  ALERTA: processos travados!"
    ps aux | grep php-fpm | grep " R " | grep -v grep | awk '{print "    PID:"$2, "CPU:"$3"%", "Tempo:"$10}'
fi

echo ""
echo "=== [4] FIXES VERIFICADOS ==="
# live.php fix
if grep -q "BUGFIX" /home/xc_vm/www/stream/live.php 2>/dev/null; then
    echo "  live.php fix (loop infinito): OK"
else
    echo "  live.php fix: AUSENTE - reaplicar!"
fi

# CoreUtilities.php fix #80
if grep -q "FIX #80" /home/xc_vm/includes/CoreUtilities.php 2>/dev/null; then
    echo "  CoreUtilities fix #80 (LLOD lento): OK"
else
    echo "  CoreUtilities fix #80: AUSENTE - reaplicar!"
fi

# Redis fix: server-threads 1 (nao deve ter server-threads 4)
redis_val=$(grep "^server-threads" /home/xc_vm/bin/redis/redis.conf 2>/dev/null | awk '{print $2}')
redis_pid=$(pgrep redis-server 2>/dev/null | head -1)
if [ "$redis_val" = "1" ] && [ -n "$redis_pid" ]; then
    echo "  Redis fix (server-threads 1): OK - rodando PID=$redis_pid"
elif [ "$redis_val" = "4" ]; then
    echo "  Redis fix: ALERTA - server-threads ainda em 4! Reaplicar fix_redis_conf.py"
elif [ -z "$redis_pid" ]; then
    echo "  Redis: PARADO (redis_handler desabilitado - pode ser normal)"
else
    echo "  Redis: server-threads=$redis_val, PID=$redis_pid"
fi

# PHP-FPM terminate timeout
pool_ok=$(grep -l "request_terminate_timeout" /home/xc_vm/bin/php/etc/*.conf 2>/dev/null | wc -l)
echo "  PHP-FPM request_terminate_timeout: $pool_ok/4 pools"

echo ""
echo "=== [5] BANCO DE DADOS ==="
echo "  Conexoes abertas (lines_live):"
mariadb xc_vm -e "SELECT COUNT(*) as abertas FROM lines_live WHERE hls_end=0;" 2>/dev/null | tail -1
echo "  Conexoes orphans (sem hls_last_read):"
mariadb xc_vm -e "SELECT COUNT(*) as orphans FROM lines_live WHERE hls_end=0 AND (hls_last_read IS NULL OR hls_last_read < UNIX_TIMESTAMP()-300);" 2>/dev/null | tail -1
echo "  Streams ativos no banco:"
mariadb xc_vm -e "SELECT COUNT(*) as streams_ativos FROM streams_servers WHERE stream_status=1;" 2>/dev/null | tail -1
echo "  Usuarios ativos:"
mariadb xc_vm -e "SELECT COUNT(*) as usuarios FROM users WHERE enabled=1;" 2>/dev/null | tail -1

echo ""
echo "=== [6] LOGS DE ERRO (ultimas 10 linhas) ==="
for logfile in /home/xc_vm/logs/error.log /home/xc_vm/logs/php_error.log; do
    if [ -f "$logfile" ] && [ -s "$logfile" ]; then
        echo "  --- $logfile ---"
        tail -5 "$logfile"
    fi
done
echo "  Erros no nginx (ultimas 5):"
tail -5 /home/xc_vm/bin/nginx/logs/error.log 2>/dev/null || echo "  sem log nginx"

echo ""
echo "=== [7] PORTS E REDE ==="
ss -tlnp | grep -E ":80 |:443 |:3306 |:6379 " | awk '{print "  ",$1,$4,$7}' | head -10

echo ""
echo "=== [8] VERSAO ==="
ver=$(mariadb xc_vm -e "SELECT xc_vm_version FROM servers LIMIT 1;" 2>/dev/null | tail -1)
echo "  XC_VM: $ver"
echo "  PHP: $(/home/xc_vm/bin/php/bin/php -v 2>/dev/null | head -1)"
echo "  MariaDB: $(mariadb --version 2>/dev/null | head -1)"

echo ""
echo "=== [9] ESPACO EM STREAMS ==="
streams_count=$(ls /home/xc_vm/content/streams/*.ts 2>/dev/null | wc -l)
streams_size=$(du -sh /home/xc_vm/content/streams/ 2>/dev/null | cut -f1)
echo "  Arquivos .ts ativos: $streams_count"
echo "  Tamanho pasta streams: $streams_size"

echo ""
echo "============================================================"
echo "  HEALTH CHECK CONCLUIDO"
echo "============================================================"
