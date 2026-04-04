-- NXC - Setup Profissional de Categorias
-- Executar apos instalacao: mariadb -u root xc_vm < setup_categorias.sql
-- Adaptar IDs dos streams conforme seu painel

DELETE FROM streams_categories;
INSERT INTO streams_categories (id,category_name,category_type,parent_id,cat_order,is_adult) VALUES
(1,'ABERTOS','live',0,1,0),
(2,'ESPORTES','live',0,2,0),
(3,'FILMES E SERIES','live',0,3,0),
(4,'NOTICIAS','live',0,4,0),
(5,'INFANTIL','live',0,5,0),
(6,'DOCUMENTARIOS','live',0,6,0),
(7,'VARIEDADES','live',0,7,0),
(8,'RELIGIOSOS','live',0,8,0),
(9,'NBA','live',0,9,0),
(10,'BAND TV','live',0,10,0),
(11,'GLOBOPLAY','live',0,11,0),
(12,'PLAYPLUS','live',0,12,0),
(13,'DISNEY PLUS','live',0,13,0),
(14,'HBO MAX','live',0,14,0),
(15,'REALITY SHOW','live',0,15,0),
(16,'REDE TV','live',0,16,0),
(17,'ADULTO','live',0,17,1),
(18,'OUTROS','live',0,18,0);
