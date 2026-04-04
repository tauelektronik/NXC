-- NXC - Setup Profissional de Bouquets
-- Executar APOS setup_categorias.sql e classificar streams
-- Os bouquets sao populados dinamicamente baseado nas categorias dos streams

DELETE FROM bouquets;

INSERT INTO bouquets (id, bouquet_name, bouquet_channels, bouquet_movies, bouquet_radios, bouquet_series, bouquet_order) VALUES
(1, 'BASICO',
  (SELECT CONCAT('[', GROUP_CONCAT(id ORDER BY id), ']') FROM streams WHERE category_id IN (1,4,8,16,18)),
  '[]', '[]', '[]', 1),
(2, 'STANDARD',
  (SELECT CONCAT('[', GROUP_CONCAT(id ORDER BY id), ']') FROM streams WHERE category_id IN (1,4,5,6,7,8,16,18)),
  '[]', '[]', '[]', 2),
(3, 'PREMIUM',
  (SELECT CONCAT('[', GROUP_CONCAT(id ORDER BY id), ']') FROM streams WHERE category_id IN (1,2,3,4,5,6,7,8,10,15,16,18)),
  '[]', '[]', '[]', 3),
(4, 'STREAMING',
  (SELECT CONCAT('[', GROUP_CONCAT(id ORDER BY id), ']') FROM streams WHERE category_id IN (11,12,13,14)),
  '[]', '[]', '[]', 4),
(5, 'ESPORTES PLUS',
  (SELECT CONCAT('[', GROUP_CONCAT(id ORDER BY id), ']') FROM streams WHERE category_id IN (2,9)),
  '[]', '[]', '[]', 5),
(6, 'ADULTO',
  (SELECT CONCAT('[', GROUP_CONCAT(id ORDER BY id), ']') FROM streams WHERE category_id IN (17)),
  '[]', '[]', '[]', 6);

-- IMPORTANTE: bouquet_radios DEVE ser '[]' e nao NULL, senao o painel da tela branca
-- (erro array_merge com NULL em CoreUtilities.php linha 254)
