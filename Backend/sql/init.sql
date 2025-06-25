-- =============================================================================
-- TIBIA TRACKER - INICIALIZAÇÃO DO BANCO DE DADOS
-- =============================================================================
-- Este arquivo é executado automaticamente na primeira inicialização do PostgreSQL

-- Criar extensões necessárias
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Configurações de timezone
SET timezone = 'America/Sao_Paulo';

-- Comentário informativo
-- As tabelas serão criadas automaticamente pelo Alembic/SQLAlchemy
-- através das migrations do backend FastAPI 