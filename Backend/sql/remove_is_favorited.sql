-- Etapa 2: Remover campo is_favorited da tabela characters
ALTER TABLE characters DROP COLUMN IF EXISTS is_favorited;
COMMIT;
