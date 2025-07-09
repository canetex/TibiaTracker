-- =====================================================
-- ETAPA 1: ADICIONAR CAMPO EXP_DATE (VERSÃO SIMPLIFICADA)
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
        RAISE EXCEPTION 'Campo exp_date já existe na tabela character_snapshots';
    END IF;
END $$;

-- =====================================================
-- 2. BACKUP DA TABELA ANTES DA MUDANÇA
-- =====================================================

-- Criar backup da tabela character_snapshots
CREATE TABLE character_snapshots_backup_step1 AS 
SELECT * FROM character_snapshots;

-- =====================================================
-- 3. ADICIONAR CAMPO EXP_DATE
-- =====================================================

-- Adicionar campo exp_date como nullable inicialmente
ALTER TABLE character_snapshots ADD COLUMN exp_date DATE;

-- =====================================================
-- 4. MIGRAR DADOS EXISTENTES
-- =====================================================

-- Migrar dados existentes: usar scraped_at como exp_date inicial
UPDATE character_snapshots 
SET exp_date = DATE(scraped_at) 
WHERE exp_date IS NULL;

-- =====================================================
-- 5. TORNAR CAMPO NOT NULL
-- =====================================================

-- Tornar exp_date NOT NULL após migração
ALTER TABLE character_snapshots ALTER COLUMN exp_date SET NOT NULL;

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
    END IF;
END $$;

COMMIT; 