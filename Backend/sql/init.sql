-- =============================================================================
-- SCRIPT DE INICIALIZAÇÃO DO BANCO DE DADOS - TIBIA TRACKER
-- Versão: 2.0 - Estrutura Reestruturada
-- =============================================================================

-- ⚠️ IMPORTANTE: Este script cria a estrutura completa do banco de dados
-- ⚠️ IMPORTANTE: Para migração de bancos existentes, use os scripts de migração

-- =============================================================================
-- EXTENSÕES NECESSÁRIAS
-- =============================================================================

-- UUID para identificadores únicos
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Estatísticas de queries (opcional)
-- ALTER SYSTEM SET shared_preload_libraries = 'pg_stat_statements';

-- =============================================================================
-- TABELA PRINCIPAL DE PERSONAGENS
-- =============================================================================
-- Armazena informações básicas e estado atual dos personagens
-- O histórico completo fica em character_snapshots
CREATE TABLE IF NOT EXISTS characters (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    server VARCHAR(50) NOT NULL,
    world VARCHAR(50) NOT NULL,  -- World atual do personagem
    
    -- Informações básicas (estado atual)
    level INTEGER DEFAULT 0,
    vocation VARCHAR(50) DEFAULT 'None',
    residence VARCHAR(255),
    guild VARCHAR(255),
    
    -- Status e configurações
    is_active BOOLEAN DEFAULT TRUE,
    is_public BOOLEAN DEFAULT TRUE,
    
    -- URLs e identificadores
    profile_url VARCHAR(500),
    character_url VARCHAR(500),
    outfit_image_url VARCHAR(500),  -- URL da imagem do outfit atual
    outfit_image_path VARCHAR(500),  -- Caminho local da imagem do outfit
    
    -- Metadados de scraping
    last_scraped_at TIMESTAMP WITH TIME ZONE,
    scrape_error_count INTEGER DEFAULT 0,
    last_scrape_error TEXT,
    next_scrape_at TIMESTAMP WITH TIME ZONE,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- TABELA DE SNAPSHOTS DIÁRIOS DOS PERSONAGENS
-- =============================================================================
-- Armazena histórico completo dia-a-dia de todos os dados dos personagens
-- IMPORTANTE: exp_date = data da experiência, scraped_at = data do scraping
CREATE TABLE IF NOT EXISTS character_snapshots (
    id SERIAL PRIMARY KEY,
    character_id INTEGER REFERENCES characters(id) ON DELETE CASCADE,
    
    -- ===== DADOS BÁSICOS DO PERSONAGEM =====
    level INTEGER NOT NULL DEFAULT 0,
    experience BIGINT NOT NULL DEFAULT 0,  -- Experiência ganha naquele dia específico
    deaths INTEGER NOT NULL DEFAULT 0,
    
    -- ===== PONTOS ESPECIAIS (podem ser null se não disponíveis) =====
    charm_points INTEGER,
    bosstiary_points INTEGER,
    achievement_points INTEGER,
    
    -- ===== INFORMAÇÕES ADICIONAIS =====
    vocation VARCHAR(50) NOT NULL,
    world VARCHAR(50) NOT NULL,  -- IMPORTANTE: rastreia mudanças de world
    residence VARCHAR(255),
    house VARCHAR(255),
    guild VARCHAR(255),
    guild_rank VARCHAR(100),
    
    -- ===== STATUS DO PERSONAGEM =====
    is_online BOOLEAN DEFAULT FALSE,
    last_login TIMESTAMP WITH TIME ZONE,
    
    -- ===== OUTFIT INFORMATION =====
    outfit_image_url VARCHAR(500),  -- URL da imagem do outfit
    outfit_image_path VARCHAR(500),  -- Caminho local da imagem do outfit
    outfit_data TEXT,  -- JSON string com dados detalhados do outfit
    profile_url VARCHAR(500),
    
    -- ===== DATAS IMPORTANTES =====
    exp_date DATE NOT NULL,                    -- Data da experiência (chave única)
    scraped_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,  -- Data do scraping
    
    -- ===== METADADOS DO SCRAPING =====
    scrape_source VARCHAR(100) DEFAULT 'manual',  -- manual, scheduled, retry
    scrape_duration INTEGER  -- duração em milissegundos
);

-- =============================================================================
-- TABELA DE FAVORITOS DOS USUÁRIOS
-- =============================================================================
-- Armazena relação entre usuários e personagens favoritos
-- Preparado para futura implementação de sistema de usuários
CREATE TABLE IF NOT EXISTS character_favorites (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL DEFAULT 1,  -- user_id = 1 para compatibilidade atual
    character_id INTEGER REFERENCES characters(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraint único para evitar duplicatas
    UNIQUE(user_id, character_id)
);

-- =============================================================================
-- ÍNDICES PARA PERFORMANCE
-- =============================================================================

-- Índices para a tabela characters
CREATE INDEX IF NOT EXISTS idx_character_name ON characters(name);
CREATE INDEX IF NOT EXISTS idx_character_server ON characters(server);
CREATE INDEX IF NOT EXISTS idx_character_world ON characters(world);
CREATE INDEX IF NOT EXISTS idx_character_active ON characters(is_active);

-- Índices compostos para characters
CREATE INDEX IF NOT EXISTS idx_character_server_world ON characters(server, world);
CREATE INDEX IF NOT EXISTS idx_character_name_server_world ON characters(name, server, world);
CREATE INDEX IF NOT EXISTS idx_character_next_scrape ON characters(next_scrape_at, is_active);

-- Índices para a tabela character_snapshots
CREATE INDEX IF NOT EXISTS idx_snapshot_character_id ON character_snapshots(character_id);
CREATE INDEX IF NOT EXISTS idx_snapshot_scraped_at ON character_snapshots(scraped_at);
CREATE INDEX IF NOT EXISTS idx_snapshot_world ON character_snapshots(world);

-- Índice único para evitar duplicatas de (character_id, exp_date)
CREATE UNIQUE INDEX IF NOT EXISTS idx_snapshot_character_exp_date 
ON character_snapshots(character_id, exp_date);

-- Índices compostos para character_snapshots (consultas históricas)
CREATE INDEX IF NOT EXISTS idx_snapshot_character_scraped ON character_snapshots(character_id, scraped_at);
CREATE INDEX IF NOT EXISTS idx_snapshot_character_world ON character_snapshots(character_id, world);
CREATE INDEX IF NOT EXISTS idx_snapshot_level_experience ON character_snapshots(level, experience);
CREATE INDEX IF NOT EXISTS idx_snapshot_points ON character_snapshots(charm_points, bosstiary_points, achievement_points);
CREATE INDEX IF NOT EXISTS idx_snapshot_exp_date ON character_snapshots(exp_date);

-- Índice para consultas de evolução temporal
CREATE INDEX IF NOT EXISTS idx_snapshot_temporal ON character_snapshots(character_id, exp_date DESC);

-- Índices para a tabela character_favorites
CREATE INDEX IF NOT EXISTS idx_favorites_user ON character_favorites(user_id);
CREATE INDEX IF NOT EXISTS idx_favorites_character ON character_favorites(character_id);

-- =============================================================================
-- FUNÇÃO PARA ATUALIZAR updated_at AUTOMATICAMENTE
-- =============================================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger para atualizar updated_at na tabela characters
DROP TRIGGER IF EXISTS update_characters_updated_at ON characters;
CREATE TRIGGER update_characters_updated_at 
    BEFORE UPDATE ON characters 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- DADOS INICIAIS (OPCIONAL)
-- =============================================================================

-- Inserir personagem de exemplo (para testes)
INSERT INTO characters (name, server, world, level, vocation, is_active) 
VALUES ('Test Character', 'taleon', 'san', 100, 'Master Sorcerer', TRUE)
ON CONFLICT DO NOTHING;

-- =============================================================================
-- GRANTS E PERMISSÕES
-- =============================================================================

-- Garantir que o usuário da aplicação tenha acesso às tabelas
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO tibia_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO tibia_user;

-- Configurar permissões padrão para futuras tabelas
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO tibia_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO tibia_user;

-- =============================================================================
-- COMENTÁRIOS PARA DOCUMENTAÇÃO
-- =============================================================================

COMMENT ON TABLE characters IS 'Tabela principal para armazenar informações básicas e estado atual dos personagens';
COMMENT ON TABLE character_snapshots IS 'Tabela para armazenar snapshots históricos diários dos personagens, permitindo rastrear evolução ao longo do tempo';
COMMENT ON TABLE character_favorites IS 'Tabela para armazenar relação entre usuários e personagens favoritos';

COMMENT ON COLUMN characters.world IS 'World atual do personagem (pode mudar ao longo do tempo)';
COMMENT ON COLUMN character_snapshots.world IS 'World do personagem no momento do snapshot (rastreia mudanças de world)';
COMMENT ON COLUMN character_snapshots.experience IS 'Experiência ganha naquele dia específico (não experiência total)';
COMMENT ON COLUMN character_snapshots.exp_date IS 'Data a qual se refere a experiência (chave única com character_id)';
COMMENT ON COLUMN character_snapshots.scraped_at IS 'Data/hora em que o scraping foi realizado';
COMMENT ON COLUMN character_snapshots.outfit_image_url IS 'URL da imagem do outfit do personagem';
COMMENT ON COLUMN character_snapshots.outfit_data IS 'Dados detalhados do outfit em formato JSON';

-- =============================================================================
-- VERIFICAÇÕES DE INTEGRIDADE
-- =============================================================================

-- Verificar se as tabelas foram criadas corretamente
DO $$ 
DECLARE
    char_count INTEGER;
    snapshot_count INTEGER;
    favorite_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO char_count FROM information_schema.tables WHERE table_name = 'characters';
    SELECT COUNT(*) INTO snapshot_count FROM information_schema.tables WHERE table_name = 'character_snapshots';
    SELECT COUNT(*) INTO favorite_count FROM information_schema.tables WHERE table_name = 'character_favorites';
    
    IF char_count = 0 OR snapshot_count = 0 OR favorite_count = 0 THEN
        RAISE EXCEPTION 'Erro: Nem todas as tabelas foram criadas corretamente';
    END IF;
    
    RAISE NOTICE 'Tibia Tracker Database Initialized Successfully!';
    RAISE NOTICE 'Tables created: characters, character_snapshots, character_favorites';
    RAISE NOTICE 'Indexes created for optimal performance';
    RAISE NOTICE 'Ready for character tracking and daily snapshots';
    RAISE NOTICE 'Structure version: 2.0 - Reestruturada';
END $$; 