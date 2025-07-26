-- Relatório Sintético dos Últimos Scrapings
-- ===========================================
-- Este script gera um relatório completo dos últimos scrapings realizados

-- 1. RESUMO GERAL DOS ÚLTIMOS 7 DIAS
SELECT 
    'RESUMO GERAL (ÚLTIMOS 7 DIAS)' as titulo,
    '' as detalhe
UNION ALL
SELECT 
    'Total de Scrapings Realizados:',
    COUNT(*)::text
FROM character_snapshots 
WHERE scraped_at >= CURRENT_DATE - INTERVAL '7 days'
UNION ALL
SELECT 
    'Scrapings Manuais:',
    COUNT(*)::text
FROM character_snapshots 
WHERE scraped_at >= CURRENT_DATE - INTERVAL '7 days' 
    AND scrape_source = 'manual'
UNION ALL
SELECT 
    'Scrapings Automáticos:',
    COUNT(*)::text
FROM character_snapshots 
WHERE scraped_at >= CURRENT_DATE - INTERVAL '7 days' 
    AND scrape_source = 'scheduled'
UNION ALL
SELECT 
    'Scrapings Refresh:',
    COUNT(*)::text
FROM character_snapshots 
WHERE scraped_at >= CURRENT_DATE - INTERVAL '7 days' 
    AND scrape_source = 'refresh';

-- 2. STATUS ATUAL DOS PERSONAGENS
SELECT 
    'STATUS ATUAL DOS PERSONAGENS' as titulo,
    '' as detalhe
UNION ALL
SELECT 
    'Total de Personagens:',
    COUNT(*)::text
FROM characters
UNION ALL
SELECT 
    'Recovery Ativo:',
    COUNT(*)::text
FROM characters 
WHERE recovery_active = TRUE
UNION ALL
SELECT 
    'Recovery Inativo:',
    COUNT(*)::text
FROM characters 
WHERE recovery_active = FALSE
UNION ALL
SELECT 
    'Com Erros Consecutivos (3+):',
    COUNT(*)::text
FROM characters 
WHERE scrape_error_count >= 3;

-- 3. ÚLTIMOS SCRAPINGS POR FONTE (ÚLTIMAS 24H)
SELECT 
    'ÚLTIMOS SCRAPINGS POR FONTE (ÚLTIMAS 24H)' as titulo,
    '' as detalhe
UNION ALL
SELECT 
    'Manual:',
    COUNT(*)::text
FROM character_snapshots 
WHERE scraped_at >= CURRENT_TIMESTAMP - INTERVAL '24 hours' 
    AND scrape_source = 'manual'
UNION ALL
SELECT 
    'Scheduled:',
    COUNT(*)::text
FROM character_snapshots 
WHERE scraped_at >= CURRENT_TIMESTAMP - INTERVAL '24 hours' 
    AND scrape_source = 'scheduled'
UNION ALL
SELECT 
    'Refresh:',
    COUNT(*)::text
FROM character_snapshots 
WHERE scraped_at >= CURRENT_TIMESTAMP - INTERVAL '24 hours' 
    AND scrape_source = 'refresh';

-- 4. ÚLTIMOS 20 SCRAPINGS REALIZADOS
SELECT 
    'ÚLTIMOS 20 SCRAPINGS REALIZADOS' as titulo,
    '' as detalhe
UNION ALL
SELECT 
    'ID | Personagem | Fonte | Data/Hora | Duração(ms) | Exp Ganha',
    ''
UNION ALL
SELECT 
    cs.id::text || ' | ' || 
    c.name || ' | ' || 
    cs.scrape_source || ' | ' || 
    TO_CHAR(cs.scraped_at, 'DD/MM HH24:MI') || ' | ' || 
    COALESCE(cs.scrape_duration::text, 'N/A') || ' | ' || 
    cs.experience::text,
    ''
FROM character_snapshots cs
JOIN characters c ON cs.character_id = c.id
ORDER BY cs.scraped_at DESC
LIMIT 20;

-- 5. PERSONAGENS COM MAIS ERROS
SELECT 
    'PERSONAGENS COM MAIS ERROS CONSECUTIVOS' as titulo,
    '' as detalhe
UNION ALL
SELECT 
    'ID | Personagem | Erros | Último Erro | Recovery Status',
    ''
UNION ALL
SELECT 
    c.id::text || ' | ' || 
    c.name || ' | ' || 
    c.scrape_error_count::text || ' | ' || 
    COALESCE(TO_CHAR(c.last_scraped_at, 'DD/MM HH24:MI'), 'Nunca') || ' | ' || 
    CASE WHEN c.recovery_active THEN 'ATIVO' ELSE 'INATIVO' END,
    ''
FROM characters c
WHERE c.scrape_error_count > 0
ORDER BY c.scrape_error_count DESC, c.last_scraped_at DESC
LIMIT 10;

-- 6. PERSONAGENS MAIS RECENTEMENTE ATUALIZADOS
SELECT 
    'PERSONAGENS MAIS RECENTEMENTE ATUALIZADOS' as titulo,
    '' as detalhe
UNION ALL
SELECT 
    'ID | Personagem | Último Scraping | Recovery Status | Erros',
    ''
UNION ALL
SELECT 
    c.id::text || ' | ' || 
    c.name || ' | ' || 
    TO_CHAR(c.last_scraped_at, 'DD/MM HH24:MI') || ' | ' || 
    CASE WHEN c.recovery_active THEN 'ATIVO' ELSE 'INATIVO' END || ' | ' || 
    c.scrape_error_count::text,
    ''
FROM characters c
WHERE c.last_scraped_at IS NOT NULL
ORDER BY c.last_scraped_at DESC
LIMIT 10; 