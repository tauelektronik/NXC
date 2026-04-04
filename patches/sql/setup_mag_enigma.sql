-- NXC - Habilitar MAG e Enigma2
-- Executar apos instalacao

UPDATE settings SET disable_enigma2 = 0 WHERE id = 1;
UPDATE settings SET disable_ministra = 0 WHERE id = 1;
UPDATE settings SET mag_container = 'ts' WHERE id = 1;
UPDATE settings SET mag_security = 1 WHERE id = 1;
UPDATE settings SET mag_keep_extension = 1 WHERE id = 1;
UPDATE settings SET disable_mag_token = 0 WHERE id = 1;
UPDATE settings SET allowed_stb_types = '["MAG250","MAG254","MAG256","MAG322","MAG324","MAG349","MAG351","MAG410","MAG420","MAG424","MAG425","MAG520","MAG522","MAG524","Aura","IP2400","IP6000","IF9100"]' WHERE id = 1;
UPDATE settings SET stalker_theme = 'starter' WHERE id = 1;
UPDATE settings SET show_all_category_mag = 1 WHERE id = 1;
UPDATE settings SET mag_load_all_channels = 1 WHERE id = 1;
UPDATE settings SET tv_channel_default_aspect = 'fit' WHERE id = 1;
UPDATE settings SET show_tv_channel_logo = 1 WHERE id = 1;
UPDATE settings SET show_channel_logo_in_preview = 1 WHERE id = 1;
UPDATE settings SET client_prebuffer = 30 WHERE id = 1;
UPDATE settings SET cloudflare = 1 WHERE id = 1;
