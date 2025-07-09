-- =====================================================
-- ETAPA 1: ADICIONAR CAMPO EXP_DATE
-- Script seguro para adicionar campo exp_date
-- =====================================================

-- ⚠️ IMPORTANTE: Execute este script em ambiente de teste primeiro!
-- ⚠️ IMPORTANTE: Faça backup antes de executar!

BEGIN;

-- =====================================================
-- 1. VERIFICAR SE O CAMPO JÁ EXISTE
-- =====================================================

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'character_snapshots' AND column_name = 'exp_date'
    ) THEN
        RAISE NOTICE 'Campo exp_date já existe na tabela character_snapshots';
        RAISE EXCEPTION 'Campo já existe. Execute apenas uma vez.';
    END IF;
END $$;

-- =====================================================
-- 2. BACKUP DA TABELA ANTES DA MUDANÇA
-- =====================================================

-- Criar backup da tabela character_snapshots
CREATE TABLE character_snapshots_backup_step1 AS 
SELECT * FROM character_snapshots;

RAISE NOTICE 'Backup criado: character_snapshots_backup_step1';

-- =====================================================
-- 3. ADICIONAR CAMPO EXP_DATE
-- =====================================================

-- Adicionar campo exp_date como nullable inicialmente
ALTER TABLE character_snapshots ADD COLUMN exp_date DATE;

RAISE NOTICE 'Campo exp_date adicionado (nullable)';

-- =====================================================
-- 4. MIGRAR DADOS EXISTENTES
-- =====================================================

-- Migrar dados existentes: usar scraped_at como exp_date inicial
UPDATE character_snapshots 
SET exp_date = DATE(scraped_at) 
WHERE exp_date IS NULL;

-- Verificar quantos registros foram migrados
DO $$
DECLARE
    migrated_count INTEGER;
    total_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO migrated_count FROM character_snapshots WHERE exp_date IS NOT NULL;
    SELECT COUNT(*) INTO total_count FROM character_snapshots;
    
    RAISE NOTICE 'Registros migrados: % de %', migrated_count, total_count;
    
    IF migrated_count != total_count THEN
        RAISE EXCEPTION 'Erro na migração: % registros não foram migrados', total_count - migrated_count;
    END IF;
END $$;

RAISE NOTICE 'Dados migrados com sucesso';

-- =====================================================
-- 5. TORNAR CAMPO NOT NULL
-- =====================================================

-- Tornar exp_date NOT NULL após migração
ALTER TABLE character_snapshots ALTER COLUMN exp_date SET NOT NULL;

RAISE NOTICE 'Campo exp_date definido como NOT NULL';

-- =====================================================
-- 6. VERIFICAÇÕES DE INTEGRIDADE
-- =====================================================

-- Verificar se todos os registros têm exp_date
DO $$
DECLARE
    null_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO null_count
    FROM character_snapshots
    WHERE exp_date IS NULL;
    
    IF null_count > 0 THEN
        RAISE EXCEPTION 'Erro: % registros ainda têm exp_date NULL', null_count;
    ELSE
        RAISE NOTICE 'Verificação OK: todos os registros têm exp_date';
    END IF;
END $$;

-- Verificar se as datas fazem sentido
DO $$
DECLARE
    future_count INTEGER;
    old_count INTEGER;
BEGIN
    -- Verificar se há datas futuras (erro)
    SELECT COUNT(*) INTO future_count
    FROM character_snapshots
    WHERE exp_date > CURRENT_DATE;
    
    IF future_count > 0 THEN
        RAISE WARNING 'Encontradas % datas futuras em exp_date', future_count;
    END IF;
    
    -- Verificar datas muito antigas (pode ser normal)
    SELECT COUNT(*) INTO old_count
    FROM character_snapshots
    WHERE exp_date < '2020-01-01';
    
    IF old_count > 0 THEN
        RAISE NOTICE 'Encontradas % datas anteriores a 2020 (pode ser normal)', old_count;
    END IF;
END $$;

-- =====================================================
-- 7. ESTATÍSTICAS FINAIS
-- =====================================================

DO $$
DECLARE
    total_snapshots INTEGER;
    date_range_min DATE;
    date_range_max DATE;
BEGIN
    SELECT COUNT(*) INTO total_snapshots FROM character_snapshots;
    SELECT MIN(exp_date), MAX(exp_date) INTO date_range_min, date_range_max FROM character_snapshots;
    
    RAISE NOTICE '=== ESTATÍSTICAS DA ETAPA 1 ===';
    RAISE NOTICE 'Total de snapshots: %', total_snapshots;
    RAISE NOTICE 'Range de datas: % a %', date_range_min, date_range_max;
    RAISE NOTICE '================================';
END $$;

COMMIT;

RAISE NOTICE 'ETAPA 1 CONCLUÍDA COM SUCESSO!';
RAISE NOTICE 'Campo exp_date adicionado e dados migrados.';
RAISE NOTICE 'Backup disponível em: character_snapshots_backup_step1'; 