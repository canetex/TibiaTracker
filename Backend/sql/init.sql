-- =============================================================================
-- TIBIA TRACKER - INICIALIZAÇÃO DO BANCO DE DADOS
-- =============================================================================
-- Script para criar as tabelas iniciais do banco PostgreSQL
-- Executado automaticamente durante o primeiro startup do container

-- Criar extensão UUID se não existir
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Configurar timezone padrão
SET timezone = 'America/Sao_Paulo';

-- Configurações de performance básicas
ALTER SYSTEM SET shared_preload_libraries = 'pg_stat_statements';
ALTER SYSTEM SET log_statement = 'all';
ALTER SYSTEM SET log_duration = on;
ALTER SYSTEM SET log_min_duration_statement = 1000;

-- Configurações de conexão
ALTER SYSTEM SET max_connections = 100;
ALTER SYSTEM SET shared_buffers = '128MB';
ALTER SYSTEM SET effective_cache_size = '512MB';
ALTER SYSTEM SET work_mem = '4MB';
ALTER SYSTEM SET maintenance_work_mem = '64MB';

-- Configurações de checkpoint
ALTER SYSTEM SET checkpoint_completion_target = 0.9;
ALTER SYSTEM SET wal_buffers = '16MB';
ALTER SYSTEM SET default_statistics_target = 100;

-- Recarregar configurações
SELECT pg_reload_conf();

-- Comentário informativo
-- As tabelas serão criadas automaticamente pelo Alembic/SQLAlchemy
-- através das migrations do backend FastAPI 

-- =============================================================================
-- TABELA PRINCIPAL DE PERSONAGENS
-- =============================================================================
-- Armazena informações básicas e estado atual do personagem
CREATE TABLE IF NOT EXISTS characters (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    server VARCHAR(50) NOT NULL,
    world VARCHAR(50) NOT NULL,  -- World atual do personagem
    
    -- Informações básicas (estado atual)
    level INTEGER DEFAULT 0,
    vocation VARCHAR(50) DEFAULT 'None',
    residence VARCHAR(255),
    
    -- Status e configurações
    is_active BOOLEAN DEFAULT TRUE,
    is_public BOOLEAN DEFAULT TRUE,
    is_favorited BOOLEAN DEFAULT FALSE,
    
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
CREATE TABLE IF NOT EXISTS character_snapshots (
    id SERIAL PRIMARY KEY,
    character_id INTEGER REFERENCES characters(id) ON DELETE CASCADE,
    
    -- ===== DADOS BÁSICOS DO PERSONAGEM =====
    level INTEGER NOT NULL DEFAULT 0,
    experience BIGINT NOT NULL DEFAULT 0,  -- BigInt para experiências altas
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
    
    -- ===== METADADOS DO SCRAPING =====
    scraped_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    scrape_source VARCHAR(100) DEFAULT 'manual',  -- manual, scheduled, retry
    scrape_duration INTEGER  -- duração em milissegundos
);

-- =============================================================================
-- ÍNDICES PARA PERFORMANCE
-- =============================================================================

-- Índices para a tabela characters
CREATE INDEX IF NOT EXISTS idx_character_name ON characters(name);
CREATE INDEX IF NOT EXISTS idx_character_server ON characters(server);
CREATE INDEX IF NOT EXISTS idx_character_world ON characters(world);
CREATE INDEX IF NOT EXISTS idx_character_active ON characters(is_active);
CREATE INDEX IF NOT EXISTS idx_character_favorited ON characters(is_favorited);

-- Índices compostos para characters
CREATE INDEX IF NOT EXISTS idx_character_server_world ON characters(server, world);
CREATE INDEX IF NOT EXISTS idx_character_name_server_world ON characters(name, server, world);
CREATE INDEX IF NOT EXISTS idx_character_active_favorited ON characters(is_active, is_favorited);
CREATE INDEX IF NOT EXISTS idx_character_next_scrape ON characters(next_scrape_at, is_active);

-- Índices para a tabela character_snapshots
CREATE INDEX IF NOT EXISTS idx_snapshot_character_id ON character_snapshots(character_id);
CREATE INDEX IF NOT EXISTS idx_snapshot_scraped_at ON character_snapshots(scraped_at);
CREATE INDEX IF NOT EXISTS idx_snapshot_world ON character_snapshots(world);

-- Índices compostos para character_snapshots (consultas históricas)
CREATE INDEX IF NOT EXISTS idx_snapshot_character_scraped ON character_snapshots(character_id, scraped_at);
CREATE INDEX IF NOT EXISTS idx_snapshot_character_world ON character_snapshots(character_id, world);
CREATE INDEX IF NOT EXISTS idx_snapshot_level_experience ON character_snapshots(level, experience);
CREATE INDEX IF NOT EXISTS idx_snapshot_points ON character_snapshots(charm_points, bosstiary_points, achievement_points);

-- Índice para consultas de evolução temporal
CREATE INDEX IF NOT EXISTS idx_snapshot_temporal ON character_snapshots(character_id, scraped_at DESC);

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

COMMENT ON COLUMN characters.world IS 'World atual do personagem (pode mudar ao longo do tempo)';
COMMENT ON COLUMN character_snapshots.world IS 'World do personagem no momento do snapshot (rastreia mudanças de world)';
COMMENT ON COLUMN character_snapshots.experience IS 'Experiência total do personagem (BigInt para suportar valores altos)';
COMMENT ON COLUMN character_snapshots.outfit_image_url IS 'URL da imagem do outfit do personagem';
COMMENT ON COLUMN character_snapshots.outfit_data IS 'Dados detalhados do outfit em formato JSON';

-- =============================================================================
-- STATUS
-- =============================================================================

-- Exibir informações sobre as tabelas criadas
DO $$ 
BEGIN
    RAISE NOTICE 'Tibia Tracker Database Initialized Successfully!';
    RAISE NOTICE 'Tables created: characters, character_snapshots';
    RAISE NOTICE 'Indexes created for optimal performance';
    RAISE NOTICE 'Ready for character tracking and daily snapshots';
END $$; 