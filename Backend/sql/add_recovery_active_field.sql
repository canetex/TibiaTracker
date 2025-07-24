-- =============================================================================
-- MIGRAÇÃO: Adicionar campo recovery_active na tabela characters
-- =============================================================================
-- Data: 2025-07-24
-- Descrição: Adiciona campo para controlar se personagem deve receber scraping automático

-- Adicionar coluna recovery_active
ALTER TABLE characters 
ADD COLUMN recovery_active BOOLEAN DEFAULT TRUE;

-- Criar índice para performance
CREATE INDEX idx_characters_recovery_active ON characters(recovery_active);

-- Atualizar personagens que não tiveram experiência nos últimos 10 dias
UPDATE characters 
SET recovery_active = FALSE 
WHERE id IN (
    SELECT DISTINCT c.id 
    FROM characters c
    LEFT JOIN character_snapshots cs ON c.id = cs.character_id 
        AND cs.exp_date >= CURRENT_DATE - INTERVAL '10 days'
        AND cs.experience > 0
    WHERE cs.id IS NULL
);

-- Atualizar personagens com erro por 3 dias consecutivos
UPDATE characters 
SET recovery_active = FALSE 
WHERE scrape_error_count >= 3;

-- Verificar resultado
SELECT 
    COUNT(*) as total_characters,
    COUNT(CASE WHEN recovery_active = TRUE THEN 1 END) as recovery_active,
    COUNT(CASE WHEN recovery_active = FALSE THEN 1 END) as recovery_inactive
FROM characters; 