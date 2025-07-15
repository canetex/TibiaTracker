-- Script de Otimização para Rubinot
-- ===================================
-- Otimizações para suportar +10.000 personagens do Rubinot

-- 1. Índices específicos para consultas frequentes
-- ================================================

-- Índice composto para consultas por servidor/mundo
CREATE INDEX IF NOT EXISTS idx_characters_server_world_active 
ON characters(server, world, is_active) 
WHERE is_active = true;

-- Índice para consultas por nome (case insensitive)
CREATE INDEX IF NOT EXISTS idx_characters_name_gin 
ON characters USING gin(name gin_trgm_ops);

-- Índice para consultas por guild
CREATE INDEX IF NOT EXISTS idx_characters_guild 
ON characters(guild) 
WHERE guild IS NOT NULL;

-- Índice para consultas por level
CREATE INDEX IF NOT EXISTS idx_characters_level 
ON characters(level) 
WHERE level > 0;

-- Índice para snapshots por data de experiência
CREATE INDEX IF NOT EXISTS idx_snapshots_exp_date_desc 
ON character_snapshots(exp_date DESC);

-- Índice composto para snapshots por personagem e data
CREATE INDEX IF NOT EXISTS idx_snapshots_character_exp_date 
ON character_snapshots(character_id, exp_date DESC);

-- Índice para snapshots por mundo (útil para Rubinot)
CREATE INDEX IF NOT EXISTS idx_snapshots_world 
ON character_snapshots(world);

-- 2. Otimizações de tabelas
-- =========================

-- Atualizar estatísticas das tabelas
ANALYZE characters;
ANALYZE character_snapshots;
ANALYZE character_favorites;

-- 3. Configurações de performance
-- ===============================

-- Aumentar work_mem para operações de ordenação
-- (executar como superuser)
-- ALTER SYSTEM SET work_mem = '256MB';

-- Aumentar shared_buffers para cache
-- (executar como superuser)
-- ALTER SYSTEM SET shared_buffers = '1GB';

-- Aumentar effective_cache_size
-- (executar como superuser)
-- ALTER SYSTEM SET effective_cache_size = '3GB';

-- 4. Particionamento (opcional para volumes muito altos)
-- =====================================================

-- Criar tabela particionada por data (opcional)
-- CREATE TABLE character_snapshots_partitioned (
--     LIKE character_snapshots INCLUDING ALL
-- ) PARTITION BY RANGE (exp_date);

-- 5. Funções auxiliares para consultas otimizadas
-- ===============================================

-- Função para obter estatísticas por servidor/mundo
CREATE OR REPLACE FUNCTION get_server_world_stats(p_server text, p_world text)
RETURNS TABLE(
    total_characters bigint,
    active_characters bigint,
    total_snapshots bigint,
    avg_level numeric,
    max_level integer,
    min_level integer
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(DISTINCT c.id)::bigint as total_characters,
        COUNT(DISTINCT CASE WHEN c.is_active THEN c.id END)::bigint as active_characters,
        COUNT(s.id)::bigint as total_snapshots,
        AVG(c.level)::numeric as avg_level,
        MAX(c.level)::integer as max_level,
        MIN(c.level)::integer as min_level
    FROM characters c
    LEFT JOIN character_snapshots s ON c.id = s.character_id
    WHERE c.server = p_server AND c.world = p_world;
END;
$$ LANGUAGE plpgsql;

-- Função para obter top personagens por level
CREATE OR REPLACE FUNCTION get_top_characters_by_level(
    p_server text, 
    p_world text, 
    p_limit integer DEFAULT 10
)
RETURNS TABLE(
    character_id integer,
    name text,
    level integer,
    vocation text,
    guild text,
    last_experience bigint,
    last_experience_date date
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.id,
        c.name,
        c.level,
        c.vocation,
        c.guild,
        s.experience,
        s.exp_date
    FROM characters c
    LEFT JOIN LATERAL (
        SELECT experience, exp_date
        FROM character_snapshots cs
        WHERE cs.character_id = c.id
        ORDER BY cs.exp_date DESC
        LIMIT 1
    ) s ON true
    WHERE c.server = p_server 
      AND c.world = p_world 
      AND c.is_active = true
    ORDER BY c.level DESC, c.name
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- 6. Views materializadas para consultas frequentes
-- ================================================

-- View materializada para estatísticas diárias
CREATE MATERIALIZED VIEW IF NOT EXISTS daily_stats AS
SELECT 
    exp_date,
    world,
    COUNT(DISTINCT character_id) as characters_with_data,
    AVG(level) as avg_level,
    MAX(level) as max_level,
    SUM(experience) as total_experience_gained
FROM character_snapshots
WHERE exp_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY exp_date, world
ORDER BY exp_date DESC, world;

-- Índice na view materializada
CREATE INDEX IF NOT EXISTS idx_daily_stats_date_world 
ON daily_stats(exp_date DESC, world);

-- 7. Triggers para manutenção automática
-- ======================================

-- Trigger para atualizar last_scraped_at automaticamente
CREATE OR REPLACE FUNCTION update_last_scraped_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.last_scraped_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_last_scraped_at
    BEFORE UPDATE ON characters
    FOR EACH ROW
    EXECUTE FUNCTION update_last_scraped_at();

-- 8. Configurações específicas para Rubinot
-- =========================================

-- Comentários nas tabelas para documentação
COMMENT ON TABLE characters IS 'Tabela principal de personagens - Otimizada para Rubinot (+10k chars)';
COMMENT ON TABLE character_snapshots IS 'Snapshots diários - Otimizada para volume alto';
COMMENT ON INDEX idx_characters_server_world_active IS 'Índice otimizado para consultas por servidor/mundo';

-- 9. Limpeza e manutenção
-- ========================

-- Função para limpar snapshots antigos (opcional)
CREATE OR REPLACE FUNCTION cleanup_old_snapshots(p_days_to_keep integer DEFAULT 365)
RETURNS integer AS $$
DECLARE
    deleted_count integer;
BEGIN
    DELETE FROM character_snapshots 
    WHERE exp_date < CURRENT_DATE - (p_days_to_keep || ' days')::interval;
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- 10. Verificações de integridade
-- ===============================

-- Verificar se os índices foram criados corretamente
SELECT 
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes 
WHERE tablename IN ('characters', 'character_snapshots', 'character_favorites')
ORDER BY tablename, indexname;

-- Verificar estatísticas das tabelas
SELECT 
    schemaname,
    tablename,
    n_tup_ins as inserts,
    n_tup_upd as updates,
    n_tup_del as deletes,
    n_live_tup as live_rows,
    n_dead_tup as dead_rows
FROM pg_stat_user_tables 
WHERE tablename IN ('characters', 'character_snapshots', 'character_favorites')
ORDER BY tablename; 