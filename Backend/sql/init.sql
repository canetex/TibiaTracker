-- =============================================================================
-- TIBIA TRACKER - INICIALIZAÇÃO DO POSTGRESQL
-- =============================================================================
-- Script de inicialização executado quando o container PostgreSQL é criado
-- =============================================================================

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