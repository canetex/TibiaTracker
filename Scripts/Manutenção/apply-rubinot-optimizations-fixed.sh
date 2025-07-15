#!/bin/bash

# Script para Aplicar Otimizações do Rubinot (VERSÃO CORRIGIDA)
# =============================================================
# Aplica otimizações no banco de dados para suportar +10.000 personagens

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para log colorido
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Verificar se estamos no diretório correto
if [ ! -f "docker-compose.yml" ]; then
    error "Execute este script na raiz do projeto (onde está o docker-compose.yml)"
    exit 1
fi

# Verificar se o container do banco está rodando
if ! docker-compose ps | grep -q "postgres.*Up"; then
    error "Container do PostgreSQL não está rodando. Inicie com: docker-compose up -d postgres"
    exit 1
fi

log "🚀 Iniciando aplicação das otimizações do Rubinot..."

# 1. Backup do banco antes das alterações
log "📦 Criando backup do banco antes das alterações..."
BACKUP_FILE="backup_pre_rubinot_$(date +%Y%m%d_%H%M%S).sql"
docker exec tibia-tracker-postgres pg_dump -U postgres tibia_tracker_db > "$BACKUP_FILE"
log "✅ Backup criado: $BACKUP_FILE"

# 2. Aplicar script de otimização
log "🔧 Aplicando otimizações do banco de dados..."
docker exec -i tibia-tracker-postgres psql -U postgres -d tibia_tracker_db < Backend/sql/optimize_for_rubinot.sql

if [ $? -eq 0 ]; then
    log "✅ Otimizações aplicadas com sucesso!"
else
    error "❌ Erro ao aplicar otimizações"
    exit 1
fi

# 3. Verificar se os índices foram criados
log "🔍 Verificando índices criados..."
docker exec tibia-tracker-postgres psql -U postgres -d tibia_tracker_db -c "
SELECT 
    schemaname,
    tablename,
    indexname
FROM pg_indexes 
WHERE tablename IN ('characters', 'character_snapshots', 'character_favorites')
ORDER BY tablename, indexname;
"

# 4. Verificar estatísticas das tabelas
log "📊 Verificando estatísticas das tabelas..."
docker exec tibia-tracker-postgres psql -U postgres -d tibia_tracker_db -c "
SELECT 
    tablename,
    n_live_tup as live_rows,
    n_dead_tup as dead_rows,
    last_vacuum,
    last_autovacuum
FROM pg_stat_user_tables 
WHERE tablename IN ('characters', 'character_snapshots', 'character_favorites')
ORDER BY tablename;
"

# 5. Testar performance com consulta simples
log "⚡ Testando performance com consulta simples..."
docker exec tibia-tracker-postgres psql -U postgres -d tibia_tracker_db -c "
EXPLAIN (ANALYZE, BUFFERS) 
SELECT COUNT(*) FROM characters WHERE server = 'rubinot';
"

# 6. Verificar configurações do PostgreSQL
log "⚙️ Verificando configurações do PostgreSQL..."
docker exec tibia-tracker-postgres psql -U postgres -d tibia_tracker_db -c "
SHOW work_mem;
SHOW shared_buffers;
SHOW effective_cache_size;
SHOW max_connections;
"

# 7. Reiniciar containers para aplicar mudanças
log "🔄 Reiniciando containers para aplicar mudanças..."
docker-compose restart backend

# 8. Verificar se a API está funcionando
log "🔍 Verificando se a API está funcionando..."
sleep 10

if curl -f http://localhost:8000/health > /dev/null 2>&1; then
    log "✅ API está funcionando corretamente"
else
    warn "⚠️ API pode não estar respondendo ainda, aguarde alguns segundos"
fi

# 9. Testar endpoint de estatísticas do Rubinot
log "🧪 Testando endpoint de estatísticas do Rubinot..."
if curl -f "http://localhost:8000/api/v1/bulk/stats/rubinot/auroria" > /dev/null 2>&1; then
    log "✅ Endpoint de estatísticas do Rubinot funcionando"
else
    warn "⚠️ Endpoint de estatísticas pode não estar disponível ainda"
fi

# 10. Resumo final
log "🎉 Otimizações do Rubinot aplicadas com sucesso!"
echo ""
echo "📋 Resumo das alterações:"
echo "   ✅ Backup do banco criado: $BACKUP_FILE"
echo "   ✅ Índices otimizados criados"
echo "   ✅ Funções auxiliares criadas"
echo "   ✅ Views materializadas criadas"
echo "   ✅ Triggers de manutenção criados"
echo "   ✅ Containers reiniciados"
echo ""
echo "🚀 O sistema está pronto para processar +10.000 personagens do Rubinot!"
echo ""
echo "📊 Para monitorar o desempenho:"
echo "   - Verificar logs: docker-compose logs -f backend"
echo "   - Estatísticas do banco: docker exec tibia-tracker-postgres psql -U postgres -d tibia_tracker_db -c \"SELECT * FROM pg_stat_user_tables;\""
echo "   - Testar endpoint: curl http://localhost:8000/api/v1/bulk/stats/rubinot/auroria"
echo ""
echo "⚠️ Lembre-se:"
echo "   - O backup está salvo em: $BACKUP_FILE"
echo "   - Monitore o uso de memória e CPU"
echo "   - Considere ajustar configurações do PostgreSQL se necessário" 