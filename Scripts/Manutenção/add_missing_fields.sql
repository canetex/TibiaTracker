-- Script para adicionar campos faltantes nas tabelas
-- Execute este script no banco PostgreSQL

-- Adicionar campos na tabela characters
ALTER TABLE characters ADD COLUMN IF NOT EXISTS outfit_image_path VARCHAR(500);
ALTER TABLE characters ADD COLUMN IF NOT EXISTS profile_url VARCHAR(500);
ALTER TABLE characters ADD COLUMN IF NOT EXISTS character_url VARCHAR(500);

-- Adicionar campos na tabela character_snapshots
ALTER TABLE character_snapshots ADD COLUMN IF NOT EXISTS outfit_image_path VARCHAR(500);
ALTER TABLE character_snapshots ADD COLUMN IF NOT EXISTS profile_url VARCHAR(500);
ALTER TABLE character_snapshots ADD COLUMN IF NOT EXISTS outfit_data JSONB;
ALTER TABLE character_snapshots ADD COLUMN IF NOT EXISTS scrape_source VARCHAR(100);
ALTER TABLE character_snapshots ADD COLUMN IF NOT EXISTS scrape_duration INTEGER;

-- Verificar se os campos foram adicionados
SELECT 
    'characters' as table_name,
    column_name,
    data_type
FROM information_schema.columns 
WHERE table_name = 'characters' AND column_name IN ('outfit_image_path', 'profile_url', 'character_url')

UNION ALL

SELECT 
    'character_snapshots' as table_name,
    column_name,
    data_type
FROM information_schema.columns 
WHERE table_name = 'character_snapshots' AND column_name IN ('outfit_image_path', 'profile_url', 'outfit_data', 'scrape_source', 'scrape_duration')

ORDER BY table_name, column_name; 