-- NXC - Setup Profissional de Pacotes
-- Executar APOS setup_bouquets.sql

DELETE FROM users_packages;
INSERT INTO users_packages (id, package_name, is_trial, is_official, bouquets, trial_credits, official_credits, trial_duration, trial_duration_in, official_duration, official_duration_in, max_connections, output_formats, is_line, is_mag, is_e2, is_restreamer) VALUES
(1, 'BASICO',      0, 1, '[1]',           0, 0, 0, 'months', 1, 'months', 1, '["ts"]',          1, 1, 1, 0),
(2, 'FAMILIA',     0, 1, '[2,4]',         0, 0, 0, 'months', 1, 'months', 2, '["ts","m3u8"]',   1, 1, 1, 0),
(3, 'COMPLETO',    0, 1, '[3,4,5]',       0, 0, 0, 'months', 1, 'months', 2, '["ts","m3u8"]',   1, 1, 1, 0),
(4, 'FULL',        0, 1, '[1,2,3,4,5]',   0, 0, 0, 'months', 1, 'months', 3, '["ts","m3u8"]',   1, 1, 1, 1),
(5, 'FULL ADULTO', 0, 1, '[1,2,3,4,5,6]', 0, 0, 0, 'months', 1, 'months', 3, '["ts","m3u8"]',   1, 1, 1, 1);
