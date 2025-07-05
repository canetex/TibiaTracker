#!/bin/bash

# =============================================================================
# TIBIA TRACKER - SCRIPT DE BACKUP SIMPLIFICADO
# =============================================================================
# Script para fazer backup completo do banco PostgreSQL (versão simplificada)

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

# Configurações do backup (valores padrão)
BACKUP_DIR="./backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="tibia_tracker_backup_${TIMESTAMP}.sql"
BACKUP_PATH="${BACKUP_DIR}/${BACKUP_NAME}"
COMPRESSED_BACKUP="${BACKUP_PATH}.gz"

# Criar diretório de backup se não existir
mkdir -p "$BACKUP_DIR"

log "Iniciando backup do banco de dados..."
log "Backup será salvo em: $COMPRESSED_BACKUP"

# Verificar se o container do PostgreSQL está rodando
if ! docker ps | grep -q "tibia-tracker-postgres"; then
    error "Container do PostgreSQL não está rodando!"
    error "Execute: docker-compose up -d postgres"
    exit 1
fi

# Fazer backup usando pg_dump (valores padrão)
log "Executando pg_dump..."
docker exec tibia-tracker-postgres pg_dump \
    -U "tibia_user" \
    -d "tibia_tracker" \
    -h localhost \
    -p 5432 \
    --verbose \
    --clean \
    --if-exists \
    --create \
    --no-owner \
    --no-privileges \
    --format=plain \
    > "$BACKUP_PATH"

# Verificar se o backup foi criado com sucesso
if [ $? -eq 0 ] && [ -f "$BACKUP_PATH" ]; then
    log "Backup criado com sucesso: $BACKUP_PATH"
    
    # Comprimir o backup
    log "Comprimindo backup..."
    gzip "$BACKUP_PATH"
    
    if [ -f "$COMPRESSED_BACKUP" ]; then
        BACKUP_SIZE=$(du -h "$COMPRESSED_BACKUP" | cut -f1)
        log "Backup comprimido criado: $COMPRESSED_BACKUP ($BACKUP_SIZE)"
        
        # Criar arquivo de metadados
        METADATA_FILE="${COMPRESSED_BACKUP}.meta"
        cat > "$METADATA_FILE" << EOF
# Metadados do Backup - Tibia Tracker
# ===================================

Data/Hora: $(date)
Arquivo: $(basename "$COMPRESSED_BACKUP")
Tamanho: $BACKUP_SIZE
Banco: tibia_tracker
Host: localhost
Porta: 5432
Usuário: tibia_user

# Comando para restaurar:
# gunzip -c $COMPRESSED_BACKUP | docker exec -i tibia-tracker-postgres psql -U tibia_user -d tibia_tracker

# Comando para verificar:
# docker exec tibia-tracker-postgres psql -U tibia_user -d tibia_tracker -c "SELECT COUNT(*) FROM characters;"
EOF
        
        log "Metadados salvos em: $METADATA_FILE"
        
        # Listar backups recentes
        log "Backups recentes:"
        ls -lh "$BACKUP_DIR"/*.sql.gz 2>/dev/null | tail -5 || true
        
    else
        error "Falha ao comprimir o backup!"
        exit 1
    fi
    
else
    error "Falha ao criar o backup!"
    exit 1
fi

log "Backup concluído com sucesso!"
log "Arquivo: $COMPRESSED_BACKUP"
log "Tamanho: $BACKUP_SIZE"

# Verificar integridade do backup
log "Verificando integridade do backup..."
if gunzip -t "$COMPRESSED_BACKUP" 2>/dev/null; then
    log "✅ Backup íntegro e válido"
else
    error "❌ Backup corrompido!"
    exit 1
fi

echo ""
log "🎉 Backup realizado com sucesso!"
log "📁 Local: $COMPRESSED_BACKUP"
log "📊 Tamanho: $BACKUP_SIZE"
echo ""
log "Para restaurar este backup:"
log "  gunzip -c $COMPRESSED_BACKUP | docker exec -i tibia-tracker-postgres psql -U tibia_user -d tibia_tracker"
echo "" 