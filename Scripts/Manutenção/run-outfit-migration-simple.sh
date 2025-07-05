#!/bin/bash

# =============================================================================
# TIBIA TRACKER - SCRIPT DE MIGRAÇÃO SIMPLIFICADO
# =============================================================================
# Script para executar a migração de imagens de outfit de forma segura

set -e  # Parar em caso de erro

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
    error "Execute este script no diretório raiz do projeto (onde está o docker-compose.yml)"
    exit 1
fi

# Verificar se os containers estão rodando
log "Verificando status dos containers..."

if ! docker ps | grep -q "tibia-tracker-postgres"; then
    error "Container do PostgreSQL não está rodando!"
    error "Execute: docker-compose up -d postgres"
    exit 1
fi

if ! docker ps | grep -q "tibia-tracker-backend"; then
    warn "Container do Backend não está rodando. Iniciando..."
    docker-compose up -d backend
    sleep 10
fi

# Verificar se o backend está respondendo
log "Verificando se o backend está respondendo..."
if ! curl -f http://localhost:8000/health > /dev/null 2>&1; then
    error "Backend não está respondendo!"
    error "Verifique os logs: docker-compose logs backend"
    exit 1
fi

log "✅ Todos os serviços estão funcionando"

# Confirmar com o usuário
echo ""
warn "⚠️  ATENÇÃO: Esta operação irá:"
echo "   1. Fazer backup completo do banco de dados"
echo "   2. Exportar URLs de outfit do banco"
echo "   3. Baixar todas as imagens de outfit"
echo "   4. Organizar por hash MD5 (economiza espaço)"
echo ""
echo "   📁 As imagens serão salvas em: /app/outfits/images/"
echo "   💾 Backup será salvo em: ./backups/"
echo ""

read -p "Deseja continuar? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log "Operação cancelada pelo usuário"
    exit 0
fi

# Executar backup primeiro
log "📦 Fazendo backup do banco..."
if [ -f "Scripts/Manutenção/backup-database-simple.sh" ]; then
    chmod +x Scripts/Manutenção/backup-database-simple.sh
    ./Scripts/Manutenção/backup-database-simple.sh
else
    warn "Script de backup não encontrado, pulando..."
fi

# Exportar URLs do banco
log "📤 Exportando URLs de outfit do banco..."
docker exec tibia-tracker-postgres psql -U tibia_user -d tibia_tracker -t -c "SELECT DISTINCT outfit_image_url FROM characters WHERE outfit_image_url IS NOT NULL AND outfit_image_url != '';" > /tmp/outfit_urls.txt

# Verificar quantas URLs foram exportadas
URL_COUNT=$(wc -l < /tmp/outfit_urls.txt)
log "📊 Exportadas $URL_COUNT URLs únicas"

# Copiar arquivo para o container
log "📋 Copiando arquivo de URLs para o container..."
docker cp /tmp/outfit_urls.txt tibia-tracker-backend:/tmp/outfit_urls.txt

# Executar migração
log "🚀 Iniciando migração de imagens de outfit..."

# Executar script Python dentro do container do backend
docker exec -w /app -e PYTHONPATH=/app tibia-tracker-backend python /app/Scripts/Manutenção/migrate-outfit-images.py

if [ $? -eq 0 ]; then
    log "🎉 Migração concluída com sucesso!"
    
    # Mostrar estatísticas finais
    echo ""
    log "📊 Estatísticas finais:"
    
    # Contar arquivos de imagem
    IMAGE_COUNT=$(docker exec tibia-tracker-backend find /app/outfits/images -type f 2>/dev/null | wc -l || echo "0")
    log "   - Imagens baixadas: $IMAGE_COUNT"
    
    # Tamanho total
    TOTAL_SIZE=$(docker exec tibia-tracker-backend du -sh /app/outfits/images 2>/dev/null | cut -f1 || echo "0")
    log "   - Tamanho total: $TOTAL_SIZE"
    
    # Verificar registros atualizados
    CHARACTERS_UPDATED=$(docker exec tibia-tracker-postgres psql -U "tibia_user" -d "tibia_tracker" -t -c "SELECT COUNT(*) FROM characters WHERE outfit_image_path IS NOT NULL;" 2>/dev/null | tr -d ' ' || echo "0")
    SNAPSHOTS_UPDATED=$(docker exec tibia-tracker-postgres psql -U "tibia_user" -d "tibia_tracker" -t -c "SELECT COUNT(*) FROM character_snapshots WHERE outfit_image_path IS NOT NULL;" 2>/dev/null | tr -d ' ' || echo "0")
    
    log "   - Characters atualizados: $CHARACTERS_UPDATED"
    log "   - Snapshots atualizados: $SNAPSHOTS_UPDATED"
    
    echo ""
    log "📁 Localização dos arquivos:"
    log "   - Imagens: /app/outfits/images/ (dentro do container)"
    log "   - Backup: ./backups/ (no host)"
    log "   - URLs: /tmp/outfit_urls.txt (no host)"
    
    echo ""
    log "✅ Migração finalizada com sucesso!"
    
else
    error "❌ Falha na migração!"
    error "Verifique os logs:"
    error "  docker-compose logs backend"
    error "  cat migration_outfit_images.log"
    exit 1
fi 