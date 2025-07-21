-- Script para adicionar campos outfit_image_path nas tabelas
-- Execute este script no banco PostgreSQL

-- Adicionar campo na tabela characters
ALTER TABLE characters ADD COLUMN IF NOT EXISTS outfit_image_path VARCHAR(500);

-- Adicionar campo na tabela character_snapshots
ALTER TABLE character_snapshots ADD COLUMN IF NOT EXISTS outfit_image_path VARCHAR(500);

-- Verificar se os campos foram adicionados
SELECT 
    'characters' as table_name,
    column_name,
    data_type
FROM information_schema.columns 
WHERE table_name = 'characters' AND column_name = 'outfit_image_path'

UNION ALL

SELECT 
    'character_snapshots' as table_name,
    column_name,
    data_type
FROM information_schema.columns 
WHERE table_name = 'character_snapshots' AND column_name = 'outfit_image_path'; 