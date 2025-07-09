-- =====================================================
-- SCRIPT DE MIGRAÇÃO DA ESTRUTURA DO BANCO DE DADOS
-- Tibia Tracker - Reestruturação Completa
-- =====================================================

-- ⚠️ IMPORTANTE: Execute este script em ambiente de teste primeiro!
-- ⚠️ IMPORTANTE: Faça backup completo antes de executar!

BEGIN;

-- =====================================================
-- 1. BACKUP DAS TABELAS ATUAIS
-- =====================================================

-- Backup da tabela characters
CREATE TABLE IF NOT EXISTS characters_backup AS 
SELECT * FROM characters;

-- Backup da tabela character_snapshots
CREATE TABLE IF NOT EXISTS character_snapshots_backup AS 
SELECT * FROM character_snapshots;

-- Backup dos favoritos (se existir is_favorited)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'characters' AND column_name = 'is_favorited'
    ) THEN
        CREATE TABLE IF NOT EXISTS favorites_backup AS 
        SELECT id, character_id, created_at 
        FROM characters 
        WHERE is_favorited = true;
    END IF;
END $$;

-- =====================================================
-- 2. ADICIONAR CAMPO EXP_DATE NA TABELA CHARACTER_SNAPSHOTS
-- =====================================================

-- Adicionar campo exp_date se não existir
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'character_snapshots' AND column_name = 'exp_date'
    ) THEN
        ALTER TABLE character_snapshots ADD COLUMN exp_date DATE;
        
        -- Migrar dados existentes: usar scraped_at como exp_date inicial
        UPDATE character_snapshots 
        SET exp_date = DATE(scraped_at) 
        WHERE exp_date IS NULL;
        
        -- Tornar exp_date NOT NULL
        ALTER TABLE character_snapshots ALTER COLUMN exp_date SET NOT NULL;
        
        RAISE NOTICE 'Campo exp_date adicionado e dados migrados';
    ELSE
        RAISE NOTICE 'Campo exp_date já existe';
    END IF;
END $$;

-- =====================================================
-- 3. CRIAR ÍNDICE ÚNICO PARA (CHARACTER_ID, EXP_DATE)
-- =====================================================

-- Remover índice antigo se existir (que pode causar conflito)
DROP INDEX IF EXISTS idx_snapshot_character_scraped;

-- Criar índice único para evitar duplicatas
CREATE UNIQUE INDEX IF NOT EXISTS idx_snapshot_character_exp_date 
ON character_snapshots(character_id, exp_date);

-- Criar índices adicionais para performance
CREATE INDEX IF NOT EXISTS idx_snapshot_character_scraped 
ON character_snapshots(character_id, scraped_at);

CREATE INDEX IF NOT EXISTS idx_snapshot_exp_date 
ON character_snapshots(exp_date);

CREATE INDEX IF NOT EXISTS idx_snapshot_character_world 
ON character_snapshots(character_id, world);

CREATE INDEX IF NOT EXISTS idx_snapshot_level_experience 
ON character_snapshots(level, experience);

-- =====================================================
-- 4. CRIAR TABELA CHARACTER_FAVORITES
-- =====================================================

CREATE TABLE IF NOT EXISTS character_favorites (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL DEFAULT 1,  -- user_id = 1 para compatibilidade
    character_id INTEGER REFERENCES characters(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(user_id, character_id)
);

-- Criar índices para a tabela de favoritos
CREATE INDEX IF NOT EXISTS idx_favorites_user 
ON character_favorites(user_id);

CREATE INDEX IF NOT EXISTS idx_favorites_character 
ON character_favorites(character_id);

-- =====================================================
-- 5. MIGRAR FAVORITOS EXISTENTES
-- =====================================================

-- Migrar favoritos existentes (se existir tabela de backup)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'favorites_backup') THEN
        INSERT INTO character_favorites (user_id, character_id, created_at)
        SELECT 1, character_id, created_at 
        FROM favorites_backup
        ON CONFLICT (user_id, character_id) DO NOTHING;
        
        RAISE NOTICE 'Favoritos migrados da tabela de backup';
    END IF;
END $$;

-- =====================================================
-- 6. REMOVER CAMPO IS_FAVORITED DA TABELA CHARACTERS
-- =====================================================

-- Remover campo is_favorited se existir
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'characters' AND column_name = 'is_favorited'
    ) THEN
        ALTER TABLE characters DROP COLUMN is_favorited;
        RAISE NOTICE 'Campo is_favorited removido da tabela characters';
    ELSE
        RAISE NOTICE 'Campo is_favorited não existe na tabela characters';
    END IF;
END $$;

-- =====================================================
-- 7. VERIFICAÇÕES DE INTEGRIDADE
-- =====================================================

-- Verificar se não há duplicatas de (character_id, exp_date)
DO $$
DECLARE
    duplicate_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO duplicate_count
    FROM (
        SELECT character_id, exp_date, COUNT(*)
        FROM character_snapshots
        GROUP BY character_id, exp_date
        HAVING COUNT(*) > 1
    ) AS duplicates;
    
    IF duplicate_count > 0 THEN
        RAISE EXCEPTION 'Encontradas % duplicatas de (character_id, exp_date). Corrija antes de continuar.', duplicate_count;
    ELSE
        RAISE NOTICE 'Nenhuma duplicata encontrada. Integridade OK.';
    END IF;
END $$;

-- Verificar se todos os snapshots têm exp_date
DO $$
DECLARE
    null_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO null_count
    FROM character_snapshots
    WHERE exp_date IS NULL;
    
    IF null_count > 0 THEN
        RAISE EXCEPTION 'Encontrados % snapshots sem exp_date. Corrija antes de continuar.', null_count;
    ELSE
        RAISE NOTICE 'Todos os snapshots têm exp_date. Integridade OK.';
    END IF;
END $$;

-- =====================================================
-- 8. ESTATÍSTICAS FINAIS
-- =====================================================

-- Mostrar estatísticas da migração
DO $$
DECLARE
    char_count INTEGER;
    snapshot_count INTEGER;
    favorite_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO char_count FROM characters;
    SELECT COUNT(*) INTO snapshot_count FROM character_snapshots;
    SELECT COUNT(*) INTO favorite_count FROM character_favorites;
    
    RAISE NOTICE '=== ESTATÍSTICAS DA MIGRAÇÃO ===';
    RAISE NOTICE 'Personagens: %', char_count;
    RAISE NOTICE 'Snapshots: %', snapshot_count;
    RAISE NOTICE 'Favoritos: %', favorite_count;
    RAISE NOTICE '================================';
END $$;

COMMIT;

-- =====================================================
-- 9. LIMPEZA (OPCIONAL - DESCOMENTE SE DESEJAR)
-- =====================================================

-- Descomente as linhas abaixo se quiser remover as tabelas de backup após confirmar que tudo está OK
-- DROP TABLE IF EXISTS characters_backup;
-- DROP TABLE IF EXISTS character_snapshots_backup;
-- DROP TABLE IF EXISTS favorites_backup;

RAISE NOTICE 'Migração concluída com sucesso!'; 