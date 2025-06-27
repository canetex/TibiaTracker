#!/bin/bash

# =============================================================================
# TIBIA TRACKER - REFRESH DO BANCO DE DADOS
# =============================================================================
# Este script realiza refresh completo do banco de dados PostgreSQL
# Autor: Tibia Tracker Team
# Data: $(date +'%Y-%m-%d')
# =============================================================================

set -euo pipefail

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configurações
PROJECT_DIR="/opt/tibia-tracker"
BACKUP_DIR="/opt/backups/tibia-tracker/database"
LOG_FILE="/var/log/tibia-tracker/database-refresh.log"

# =============================================================================
# FUNÇÕES AUXILIARES
# =============================================================================

log() {
    # Criar diretório de log se não existir
    sudo mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    # Criar diretório de log se não existir
    sudo mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    echo -e "${RED}[ERROR $(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

warning() {
    # Criar diretório de log se não existir
    sudo mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    echo -e "${YELLOW}[WARNING $(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

info() {
    # Criar diretório de log se não existir
    sudo mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    echo -e "${BLUE}[INFO $(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

# =============================================================================
# VERIFICAÇÕES PRÉ-EXECUÇÃO
# =============================================================================

check_prerequisites() {
    log "Verificando pré-requisitos..."
    
    if [[ ! -d "$PROJECT_DIR" ]]; then
        error "Diretório do projeto não encontrado: $PROJECT_DIR"
    fi
    
    cd "$PROJECT_DIR"
    
    if [[ ! -f "docker-compose.yml" ]]; then
        error "docker-compose.yml não encontrado em $PROJECT_DIR"
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        error "Docker Compose não está instalado"
    fi
    
    log "Pré-requisitos verificados!"
}

# =============================================================================
# BACKUP DO BANCO ATUAL
# =============================================================================

backup_database() {
    log "Criando backup do banco de dados..."
    
    # Criar diretório de backup
    sudo mkdir -p "$BACKUP_DIR"
    
    # Nome do backup com timestamp
    BACKUP_NAME="db-backup-$(date +'%Y%m%d-%H%M%S')"
    
    # Obter informações do banco do .env
    if [[ -f ".env" ]]; then
        source .env
    else
        error "Arquivo .env não encontrado"
    fi
    
    # Criar backup usando pg_dump através do container
    log "Executando pg_dump..."
    sudo docker-compose exec -T postgres pg_dump -U "$DB_USER" -d "$DB_NAME" > "$BACKUP_DIR/$BACKUP_NAME.sql"
    
    # Comprimir backup
    gzip "$BACKUP_DIR/$BACKUP_NAME.sql"
    
    log "Backup criado: $BACKUP_DIR/$BACKUP_NAME.sql.gz"
    
    # Manter apenas os últimos 10 backups
    sudo find "$BACKUP_DIR" -name "db-backup-*.sql.gz" -type f -mtime +10 -delete
}

# =============================================================================
# PARAR E REMOVER CONTAINERS
# =============================================================================

stop_containers() {
    log "Parando containers..."
    
    sudo docker-compose down
    
    log "Containers parados!"
}

# =============================================================================
# LIMPEZA DE VOLUMES E DADOS
# =============================================================================

clean_database_volumes() {
    log "Limpando volumes do banco de dados..."
    
    # Remover volumes específicos do PostgreSQL
    sudo docker volume rm $(sudo docker volume ls -q | grep postgres) 2>/dev/null || true
    
    # Remover volumes órfãos
    sudo docker volume prune -f
    
    log "Volumes limpos!"
}

# =============================================================================
# REINICIALIZAR BANCO
# =============================================================================

reinitialize_database() {
    log "Reinicializando banco de dados..."
    
    # Subir apenas o PostgreSQL primeiro
    sudo docker-compose up -d postgres
    
    # Aguardar PostgreSQL ficar pronto
    log "Aguardando PostgreSQL ficar pronto..."
    sleep 30
    
    # Verificar se PostgreSQL está respondendo
    local attempts=0
    while [[ $attempts -lt 30 ]]; do
        if sudo docker-compose exec postgres pg_isready -U "$DB_USER" -d "$DB_NAME" &> /dev/null; then
            log "PostgreSQL está pronto!"
            break
        fi
        
        attempts=$((attempts + 1))
        sleep 2
    done
    
    if [[ $attempts -eq 30 ]]; then
        error "PostgreSQL não ficou pronto após 60 segundos"
    fi
    
    # Executar migrações se existirem
    if [[ -f "Backend/alembic.ini" ]]; then
        log "Executando migrações do banco..."
        sudo docker-compose exec backend alembic upgrade head || warning "Falha ao executar migrações"
    fi
    
    log "Banco de dados reinicializado!"
}

# =============================================================================
# SUBIR TODOS OS SERVIÇOS
# =============================================================================

start_all_services() {
    log "Iniciando todos os serviços..."
    
    sudo docker-compose up -d
    
    # Aguardar todos os serviços ficarem prontos
    log "Aguardando serviços ficarem prontos..."
    sleep 30
    
    # Verificar status
    sudo docker-compose ps
    
    log "Todos os serviços iniciados!"
}

# =============================================================================
# VERIFICAÇÃO PÓS-REFRESH
# =============================================================================

verify_database() {
    log "Verificando banco de dados..."
    
    # Testar conexão com o banco
    if sudo docker-compose exec postgres psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" &> /dev/null; then
        log "Conexão com banco OK"
    else
        error "Falha na conexão com o banco"
    fi
    
    # Verificar tabelas principais
    local tables=$(sudo docker-compose exec postgres psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';")
    log "Tabelas encontradas: $(echo $tables | tr -d ' ')"
    
    # Testar API se estiver rodando
    if curl -f -s http://localhost:8000/health > /dev/null; then
        log "API respondendo corretamente"
    else
        warning "API não está respondendo"
    fi
}

# =============================================================================
# FUNÇÃO PRINCIPAL
# =============================================================================

main() {
    log "=== INICIANDO REFRESH DO BANCO DE DADOS ==="
    
    # Criar diretório de log
    sudo mkdir -p "$(dirname "$LOG_FILE")"
    
    # Confirmação do usuário
    warning "ATENÇÃO: Este processo irá resetar completamente o banco de dados!"
    warning "Todos os dados atuais serão perdidos (backup será criado)."
    echo -n "Deseja continuar? (y/N): "
    read -r response
    
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        info "Operação cancelada pelo usuário."
        exit 0
    fi
    
    check_prerequisites
    backup_database
    stop_containers
    clean_database_volumes
    reinitialize_database
    start_all_services
    verify_database
    
    log "=== REFRESH DO BANCO CONCLUÍDO COM SUCESSO ==="
    log "Backup salvo em: $BACKUP_DIR"
    log "Logs salvos em: $LOG_FILE"
    
    info "Para verificar o status dos serviços:"
    info "  sudo docker-compose ps"
    info "  sudo docker-compose logs -f"
}

# =============================================================================
# EXECUÇÃO
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 