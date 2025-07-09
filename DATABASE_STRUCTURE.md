# Estrutura Completa do Banco de Dados - Tibia Tracker

## 📊 Diagrama da Estrutura Principal

```
┌─────────────────────────────────────────────────────────────────┐
│                        CHARACTERS                               │
├─────────────────────────────────────────────────────────────────┤
│ id (PK) | name | server | world | level | vocation | guild     │
│ is_active | is_favorited | last_scraped_at | created_at        │
│ outfit_image_url | profile_url | character_url                 │
│ outfit_image_path | scrape_error_count | next_scrape_at        │
└─────────────────────────────────────────────────────────────────┘
                                │
                                │ 1:N
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                   CHARACTER_SNAPSHOTS                           │
├─────────────────────────────────────────────────────────────────┤
│ id (PK) | character_id (FK) | level | experience | deaths      │
│ vocation | world | residence | guild | guild_rank              │
│ charm_points | bosstiary_points | achievement_points           │
│ is_online | last_login | outfit_image_url | scraped_at         │
│ scrape_source | scrape_duration | outfit_data (JSON)           │
│ outfit_image_path | profile_url                                │
└─────────────────────────────────────────────────────────────────┘
```

## 🗄️ Tabelas do Sistema PostgreSQL

### **Tabelas de Informação do Schema**
```
┌─────────────────────────────────────────────────────────────────┐
│                    INFORMATION_SCHEMA                           │
├─────────────────────────────────────────────────────────────────┤
│ TABLES | COLUMNS | INDEXES | CONSTRAINTS | TRIGGERS            │
│ VIEWS | ROUTINES | PARAMETERS | SEQUENCES                      │
│ USAGE_PRIVILEGES | TABLE_PRIVILEGES | COLUMN_PRIVILEGES        │
└─────────────────────────────────────────────────────────────────┘
```

### **Tabelas de Sistema PostgreSQL**
```
┌─────────────────────────────────────────────────────────────────┐
│                        PG_CATALOG                               │
├─────────────────────────────────────────────────────────────────┤
│ pg_class | pg_attribute | pg_index | pg_constraint             │
│ pg_trigger | pg_proc | pg_namespace | pg_type                  │
│ pg_user | pg_database | pg_tablespace | pg_statistic           │
│ pg_stat_all_tables | pg_stat_all_indexes | pg_locks            │
└─────────────────────────────────────────────────────────────────┘
```

### **Tabelas de Estatísticas**
```
┌─────────────────────────────────────────────────────────────────┐
│                        PG_STATISTICS                            │
├─────────────────────────────────────────────────────────────────┤
│ pg_stat_statements | pg_stat_database | pg_stat_user_tables    │
│ pg_stat_user_indexes | pg_stat_activity | pg_stat_bgwriter     │
│ pg_stat_wal | pg_stat_archiver | pg_stat_replication           │
└─────────────────────────────────────────────────────────────────┘
```

## 📋 Detalhamento das Tabelas Principais

### **1. CHARACTERS (Tabela Principal)**
```sql
CREATE TABLE characters (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    server VARCHAR(50) NOT NULL,
    world VARCHAR(50) NOT NULL,
    level INTEGER DEFAULT 0,
    vocation VARCHAR(50) DEFAULT 'None',
    residence VARCHAR(255),
    guild VARCHAR(255),
    is_active BOOLEAN DEFAULT TRUE,
    is_public BOOLEAN DEFAULT TRUE,
    is_favorited BOOLEAN DEFAULT FALSE,
    profile_url VARCHAR(500),
    character_url VARCHAR(500),
    outfit_image_url VARCHAR(500),
    outfit_image_path VARCHAR(500),
    last_scraped_at TIMESTAMP WITH TIME ZONE,
    scrape_error_count INTEGER DEFAULT 0,
    last_scrape_error TEXT,
    next_scrape_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
```

### **2. CHARACTER_SNAPSHOTS (Histórico Diário)**
```sql
CREATE TABLE character_snapshots (
    id SERIAL PRIMARY KEY,
    character_id INTEGER REFERENCES characters(id) ON DELETE CASCADE,
    level INTEGER NOT NULL DEFAULT 0,
    experience BIGINT NOT NULL DEFAULT 0,
    deaths INTEGER NOT NULL DEFAULT 0,
    charm_points INTEGER,
    bosstiary_points INTEGER,
    achievement_points INTEGER,
    vocation VARCHAR(50) NOT NULL,
    world VARCHAR(50) NOT NULL,
    residence VARCHAR(255),
    house VARCHAR(255),
    guild VARCHAR(255),
    guild_rank VARCHAR(100),
    is_online BOOLEAN DEFAULT FALSE,
    last_login TIMESTAMP WITH TIME ZONE,
    outfit_image_url VARCHAR(500),
    outfit_image_path VARCHAR(500),
    outfit_data TEXT,
    profile_url VARCHAR(500),
    scraped_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    scrape_source VARCHAR(100) DEFAULT 'manual',
    scrape_duration INTEGER
);
```

## 🔍 Índices Criados

### **Índices da Tabela CHARACTERS**
```sql
-- Índices simples
CREATE INDEX idx_character_name ON characters(name);
CREATE INDEX idx_character_server ON characters(server);
CREATE INDEX idx_character_world ON characters(world);
CREATE INDEX idx_character_active ON characters(is_active);
CREATE INDEX idx_character_favorited ON characters(is_favorited);

-- Índices compostos
CREATE INDEX idx_character_server_world ON characters(server, world);
CREATE INDEX idx_character_name_server_world ON characters(name, server, world);
CREATE INDEX idx_character_active_favorited ON characters(is_active, is_favorited);
CREATE INDEX idx_character_next_scrape ON characters(next_scrape_at, is_active);
```

### **Índices da Tabela CHARACTER_SNAPSHOTS**
```sql
-- Índices simples
CREATE INDEX idx_snapshot_character_id ON character_snapshots(character_id);
CREATE INDEX idx_snapshot_scraped_at ON character_snapshots(scraped_at);
CREATE INDEX idx_snapshot_world ON character_snapshots(world);

-- Índices compostos
CREATE INDEX idx_snapshot_character_scraped ON character_snapshots(character_id, scraped_at);
CREATE INDEX idx_snapshot_character_world ON character_snapshots(character_id, world);
CREATE INDEX idx_snapshot_level_experience ON character_snapshots(level, experience);
CREATE INDEX idx_snapshot_points ON character_snapshots(charm_points, bosstiary_points, achievement_points);
CREATE INDEX idx_snapshot_temporal ON character_snapshots(character_id, scraped_at DESC);
```

## 🔧 Funções e Triggers

### **Função de Atualização Automática**
```sql
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';
```

### **Trigger para CHARACTERS**
```sql
CREATE TRIGGER update_characters_updated_at 
    BEFORE UPDATE ON characters 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();
```

## 📊 Extensões PostgreSQL

### **Extensões Instaladas**
```sql
-- UUID para identificadores únicos
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Estatísticas de queries
ALTER SYSTEM SET shared_preload_libraries = 'pg_stat_statements';
```

## 🔍 Consultas Úteis para Debug

### **Verificar Todas as Tabelas**
```sql
SELECT table_name, table_type 
FROM information_schema.tables 
WHERE table_schema = 'public' 
ORDER BY table_name;
```

### **Verificar Estrutura das Tabelas**
```sql
SELECT 
    table_name,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name IN ('characters', 'character_snapshots')
ORDER BY table_name, ordinal_position;
```

### **Verificar Índices**
```sql
SELECT 
    tablename,
    indexname,
    indexdef
FROM pg_indexes 
WHERE schemaname = 'public'
ORDER BY tablename, indexname;
```

### **Verificar Tamanho das Tabelas**
```sql
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables 
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

## 📈 Estatísticas de Uso

### **Contagem de Registros**
```sql
-- Total de personagens
SELECT COUNT(*) as total_characters FROM characters;

-- Total de snapshots
SELECT COUNT(*) as total_snapshots FROM character_snapshots;

-- Snapshots por personagem
SELECT 
    c.name,
    COUNT(s.id) as snapshots_count
FROM characters c
LEFT JOIN character_snapshots s ON c.id = s.character_id
GROUP BY c.id, c.name
ORDER BY snapshots_count DESC;
```

## 🚀 Resumo da Estrutura

### **Tabelas de Aplicação (2)**
1. **`characters`** - Estado atual dos personagens
2. **`character_snapshots`** - Histórico diário completo

### **Tabelas de Sistema (Múltiplas)**
- **`information_schema.*`** - Metadados do banco
- **`pg_catalog.*`** - Catálogo do PostgreSQL
- **`pg_statistics.*`** - Estatísticas de performance

### **Índices (13)**
- **8 índices** na tabela `characters`
- **5 índices** na tabela `character_snapshots`

### **Funções e Triggers (1)**
- **1 função** para atualização automática de timestamps
- **1 trigger** na tabela `characters`

Esta estrutura garante:
- ✅ **Performance otimizada** para consultas temporais
- ✅ **Integridade referencial** com foreign keys
- ✅ **Atualização automática** de timestamps
- ✅ **Monitoramento** através de estatísticas
- ✅ **Escalabilidade** para grandes volumes de dados 