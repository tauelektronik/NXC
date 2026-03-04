-- NXC Fix #3 — Limpar conexões fantasma (phantom connections)
-- Issue: Dashboard mostra conexões ativas que não existem
-- Causa: Registros órfãos em lines_live com hls_end=0 e hls_last_read=NULL
-- Executar: mariadb xc_vm < fix_orphans.sql

UPDATE lines_live
SET hls_end = 1
WHERE hls_end = 0
  AND (
    hls_last_read IS NULL
    OR hls_last_read < UNIX_TIMESTAMP() - 300
  );

-- Verificar resultado
SELECT
    COUNT(*) AS conexoes_ativas,
    SUM(CASE WHEN hls_end = 0 THEN 1 ELSE 0 END) AS ainda_abertas,
    SUM(CASE WHEN hls_end = 1 THEN 1 ELSE 0 END) AS fechadas
FROM lines_live;
