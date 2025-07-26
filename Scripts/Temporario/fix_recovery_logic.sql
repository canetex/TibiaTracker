-- Script para corrigir a lógica de determinação do recovery_active
-- =================================================================

-- 1. CORRIGIR LÓGICA DE DETERMINAÇÃO DO RECOVERY_ACTIVE
-- Problema: A lógica atual só considera personagens com experience > 0
-- Solução: Considerar qualquer snapshot nos últimos 10 dias (mesmo com 0 exp)

UPDATE characters 
SET recovery_active = FALSE 
WHERE id IN (
    SELECT DISTINCT c.id 
    FROM characters c
    LEFT JOIN character_snapshots cs ON c.id = cs.character_id 
        AND cs.exp_date >= CURRENT_DATE - INTERVAL '10 days'
    WHERE cs.id IS NULL
);

-- 2. ATIVAR RECOVERY PARA PERSONAGENS COM SNAPSHOTS RECENTES
UPDATE characters 
SET recovery_active = TRUE 
WHERE id IN (
    SELECT DISTINCT c.id 
    FROM characters c
    INNER JOIN character_snapshots cs ON c.id = cs.character_id 
        AND cs.exp_date >= CURRENT_DATE - INTERVAL '10 days'
    WHERE c.recovery_active = FALSE
);

-- 3. MANTER DESATIVADO APENAS PERSONAGENS COM 3+ ERROS CONSECUTIVOS
UPDATE characters 
SET recovery_active = FALSE 
WHERE scrape_error_count >= 3;

-- 4. VERIFICAR RESULTADO
SELECT 
    COUNT(*) as total_characters,
    COUNT(CASE WHEN recovery_active = TRUE THEN 1 END) as recovery_active,
    COUNT(CASE WHEN recovery_active = FALSE THEN 1 END) as recovery_inactive,
    COUNT(CASE WHEN scrape_error_count >= 3 THEN 1 END) as with_errors
FROM characters; 