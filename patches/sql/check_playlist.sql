SELECT 'SERVER_CONFIG' as info;
SELECT id, server_name, server_ip, http_broadcast_port, domain_name FROM servers;
SELECT 'SETTINGS' as info;
SELECT disable_playlist, disable_player_api, encrypt_playlist, use_mdomain_in_lists, live_streaming_pass FROM settings WHERE id=1;
SELECT 'LINE_PASS' as info;
SELECT id, username, password FROM `lines` LIMIT 3;
