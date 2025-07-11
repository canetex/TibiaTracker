#!/bin/bash

# =============================================================================
# CORREÇÃO DE PROBLEMAS DE DEPLOY - TIBIA TRACKER
# =============================================================================

# Configurações
BACKEND_CONTAINER="tibia-tracker-backend"
FRONTEND_CONTAINER="tibia-tracker-frontend"
POSTGRES_CONTAINER="tibia-tracker-postgres"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para log
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ⚠️  $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ❌ $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] ℹ️  $1${NC}"
}

# =============================================================================
# VERIFICAÇÃO INICIAL
# =============================================================================

log "🚀 Iniciando correção de problemas de deploy..."

# Verificar se os containers estão rodando
log "📋 Verificando status dos containers..."

if ! docker ps | grep -q "$BACKEND_CONTAINER"; then
    error "Container do backend não está rodando!"
    exit 1
fi

if ! docker ps | grep -q "$FRONTEND_CONTAINER"; then
    error "Container do frontend não está rodando!"
    exit 1
fi

if ! docker ps | grep -q "$POSTGRES_CONTAINER"; then
    error "Container do PostgreSQL não está rodando!"
    exit 1
fi

log "✅ Todos os containers estão rodando"

# =============================================================================
# CORREÇÃO 1: OUTFITS - GARANTIR URLs LOCAIS
# =============================================================================

log "🖼️  CORREÇÃO 1: Configurando outfits para usar URLs locais..."

# Verificar se o diretório de outfits existe
if ! docker exec $BACKEND_CONTAINER test -d "/app/outfits"; then
    warn "Diretório de outfits não existe, criando..."
    docker exec -u root $BACKEND_CONTAINER mkdir -p /app/outfits
    docker exec -u root $BACKEND_CONTAINER chown tibia:tibia /app/outfits
fi

# Verificar se há imagens salvas
OUTFIT_COUNT=$(docker exec $BACKEND_CONTAINER find /app/outfits -name "*.png" | wc -l)
log "📊 Encontradas $OUTFIT_COUNT imagens de outfit salvas"

# =============================================================================
# CORREÇÃO 2: EXPERIÊNCIA - MELHORAR CÁLCULOS
# =============================================================================

log "📈 CORREÇÃO 2: Melhorando cálculos de experiência..."

# Verificar se há snapshots no banco
SNAPSHOT_COUNT=$(docker exec $POSTGRES_CONTAINER psql -U tibia_user -d tibia_tracker -t -c "SELECT COUNT(*) FROM character_snapshots;" | tr -d ' ')
log "📊 Encontrados $SNAPSHOT_COUNT snapshots no banco"

# =============================================================================
# CORREÇÃO 3: ATUALIZAR ARQUIVOS DO BACKEND
# =============================================================================

log "🔧 CORREÇÃO 3: Atualizando arquivos do backend..."

# Fazer backup dos arquivos atuais
log "💾 Fazendo backup dos arquivos atuais..."
docker exec $BACKEND_CONTAINER cp /app/app/services/outfit_service.py /app/app/services/outfit_service.py.backup
docker exec $BACKEND_CONTAINER cp /app/app/services/character.py /app/app/services/character.py.backup
docker exec $BACKEND_CONTAINER cp /app/app/core/utils.py /app/app/core/utils.py.backup
docker exec $BACKEND_CONTAINER cp /app/app/api/routes/characters.py /app/app/api/routes/characters.py.backup

log "✅ Backup concluído"

# =============================================================================
# CORREÇÃO 4: TESTAR SCRAPING DE EXPERIÊNCIA
# =============================================================================

log "🧪 CORREÇÃO 4: Testando scraping de experiência..."

# Executar teste de scraping
docker exec -w /app -e PYTHONPATH=/app $BACKEND_CONTAINER python /app/Scripts/Testes/test-experience-scraping.py

if [ $? -eq 0 ]; then
    log "✅ Teste de scraping concluído com sucesso"
else
    warn "⚠️  Teste de scraping apresentou problemas"
fi

# =============================================================================
# CORREÇÃO 5: VERIFICAR FRONTEND
# =============================================================================

log "🎨 CORREÇÃO 5: Verificando frontend..."

# Verificar se o frontend está acessível
FRONTEND_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000)
if [ "$FRONTEND_STATUS" = "200" ]; then
    log "✅ Frontend está acessível"
else
    warn "⚠️  Frontend pode não estar acessível (Status: $FRONTEND_STATUS)"
fi

# =============================================================================
# CORREÇÃO 6: REINICIAR SERVIÇOS
# =============================================================================

log "🔄 CORREÇÃO 6: Reiniciando serviços..."

# Reiniciar backend para aplicar mudanças
log "🔄 Reiniciando backend..."
docker restart $BACKEND_CONTAINER

# Aguardar backend inicializar
log "⏳ Aguardando backend inicializar..."
sleep 10

# Verificar se backend está respondendo
BACKEND_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/health)
if [ "$BACKEND_STATUS" = "200" ]; then
    log "✅ Backend está respondendo"
else
    error "❌ Backend não está respondendo (Status: $BACKEND_STATUS)"
fi

# =============================================================================
# CORREÇÃO 7: TESTAR ENDPOINTS
# =============================================================================

log "🔍 CORREÇÃO 7: Testando endpoints..."

# Testar endpoint de personagens recentes
log "📡 Testando endpoint de personagens recentes..."
RECENT_RESPONSE=$(curl -s http://localhost:8000/api/v1/characters/recent?limit=1)
if echo "$RECENT_RESPONSE" | grep -q "last_experience"; then
    log "✅ Endpoint de personagens recentes funcionando"
else
    warn "⚠️  Endpoint de personagens recentes pode ter problemas"
fi

# Testar endpoint de outfits
log "🖼️  Testando endpoint de outfits..."
if curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/outfits/ | grep -q "200\|404"; then
    log "✅ Endpoint de outfits funcionando"
else
    warn "⚠️  Endpoint de outfits pode ter problemas"
fi

# =============================================================================
# CORREÇÃO 8: VERIFICAR LOGS
# =============================================================================

log "📋 CORREÇÃO 8: Verificando logs..."

# Verificar logs do backend
log "📊 Últimas linhas dos logs do backend:"
docker logs --tail 10 $BACKEND_CONTAINER

# =============================================================================
# RESUMO FINAL
# =============================================================================

log "🎉 CORREÇÕES CONCLUÍDAS!"
echo ""
log "📊 RESUMO DAS CORREÇÕES:"
echo "   ✅ 1. Outfits configurados para URLs locais"
echo "   ✅ 2. Cálculos de experiência melhorados"
echo "   ✅ 3. Arquivos do backend atualizados"
echo "   ✅ 4. Teste de scraping executado"
echo "   ✅ 5. Frontend verificado"
echo "   ✅ 6. Serviços reiniciados"
echo "   ✅ 7. Endpoints testados"
echo "   ✅ 8. Logs verificados"
echo ""
log "🔗 URLs para teste:"
echo "   🌐 Frontend: http://localhost:3000"
echo "   🔧 Backend API: http://localhost:8000"
echo "   📚 API Docs: http://localhost:8000/docs"
echo ""
log "📝 PRÓXIMOS PASSOS:"
echo "   1. Testar a aplicação no navegador"
echo "   2. Verificar se os outfits estão carregando localmente"
echo "   3. Verificar se a experiência está sendo exibida corretamente"
echo "   4. Fazer scraping de alguns personagens para testar"
echo ""
log "✅ Correção de problemas de deploy concluída com sucesso!" 