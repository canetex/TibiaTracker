#!/bin/bash

# =============================================================================
# TIBIA TRACKER - SCRIPT DE DEPLOY
# =============================================================================
# Este script realiza o deploy completo da aplicação em um servidor LXC Debian
# Autor: Tibia Tracker Team
# Data: $(date +'%Y-%m-%d')
# =============================================================================

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configurações
PROJECT_DIR="/opt/tibia-tracker"
BACKUP_DIR="/opt/backups/tibia-tracker"
LOG_FILE="/var/log/tibia-tracker/deploy.log"
GITHUB_REPO="https://github.com/canetex/tibia-tracker.git"

# =============================================================================
# FUNÇÕES AUXILIARES
# =============================================================================

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR $(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING $(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[INFO $(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

# =============================================================================
# VERIFICAÇÕES PRÉ-DEPLOY
# =============================================================================

check_prerequisites() {
    log "Verificando pré-requisitos..."
    
    # Verificar se é root ou tem sudo
    if [[ $EUID -ne 0 ]] && ! sudo -n true 2>/dev/null; then
        error "Este script precisa ser executado como root ou ter acesso sudo sem senha"
    fi
    
    # Verificar se o Git está instalado
    if ! command -v git &> /dev/null; then
        error "Git não está instalado. Execute primeiro o script install-requirements.sh"
    fi
    
    # Verificar se o Docker está instalado
    if ! command -v docker &> /dev/null; then
        error "Docker não está instalado. Execute primeiro o script install-requirements.sh"
    fi
    
    # Verificar se o Docker Compose está instalado
    if ! command -v docker-compose &> /dev/null; then
        error "Docker Compose não está instalado. Execute primeiro o script install-requirements.sh"
    fi
    
    log "Pré-requisitos verificados com sucesso!"
}

# =============================================================================
# BACKUP ANTES DO DEPLOY
# =============================================================================

create_backup() {
    if [[ -d "$PROJECT_DIR" ]]; then
        log "Criando backup da instalação atual..."
        
        # Criar diretório de backup se não existir
        sudo mkdir -p "$BACKUP_DIR"
        
        # Backup timestamp
        BACKUP_NAME="backup-$(date +'%Y%m%d-%H%M%S')"
        
        # Parar containers antes do backup
        cd "$PROJECT_DIR"
        sudo docker-compose down || true
        
        # Criar backup
        sudo tar -czf "$BACKUP_DIR/$BACKUP_NAME.tar.gz" -C "$(dirname "$PROJECT_DIR")" "$(basename "$PROJECT_DIR")"
        
        log "Backup criado em: $BACKUP_DIR/$BACKUP_NAME.tar.gz"
        
        # Manter apenas os últimos 5 backups
        sudo find "$BACKUP_DIR" -name "backup-*.tar.gz" -type f -mtime +5 -delete
    fi
}

# =============================================================================
# DEPLOY DA APLICAÇÃO
# =============================================================================

deploy_application() {
    log "Iniciando deploy da aplicação..."
    
    # Criar diretório do projeto se não existir
    sudo mkdir -p "$PROJECT_DIR"
    
    # Se é primeira instalação, fazer clone
    if [[ ! -d "$PROJECT_DIR/.git" ]]; then
        log "Primeira instalação - clonando repositório..."
        sudo git clone "$GITHUB_REPO" "$PROJECT_DIR"
    else
        log "Atualizando código do repositório..."
        cd "$PROJECT_DIR"
        sudo git fetch origin
        sudo git reset --hard origin/main
        sudo git pull origin main
    fi
    
    # Entrar no diretório do projeto
    cd "$PROJECT_DIR"
    
    # Verificar se arquivo .env existe
    if [[ ! -f ".env" ]]; then
        if [[ -f "env.template" ]]; then
            log "Copiando env.template para .env..."
            sudo cp env.template .env
            warning "IMPORTANTE: Configure as variáveis em $PROJECT_DIR/.env antes de continuar!"
            warning "Pressione Enter após configurar o .env ou Ctrl+C para sair..."
            read -r
        else
            error "Arquivo .env não encontrado e env.template não existe!"
        fi
    fi
    
    # Criar diretórios necessários
    sudo mkdir -p /var/log/tibia-tracker
    sudo chmod 755 /var/log/tibia-tracker
    
    # Limpar containers e volumes antigos se existirem
    log "Limpando containers antigos..."
    sudo docker-compose down --remove-orphans || true
    sudo docker system prune -f || true
    
    # Build e start dos containers
    log "Construindo e iniciando containers..."
    sudo docker-compose up -d --build
    
    # Aguardar containers ficarem prontos
    log "Aguardando containers ficarem prontos..."
    sleep 30
    
    # Verificar status dos containers
    sudo docker-compose ps
}

# =============================================================================
# CONFIGURAÇÃO DE SERVIÇOS SYSTEMD
# =============================================================================

setup_systemd() {
    log "Configurando serviços systemd..."
    
    # Criar serviço systemd para o Tibia Tracker
    sudo tee /etc/systemd/system/tibia-tracker.service > /dev/null <<EOF
[Unit]
Description=Tibia Tracker Application
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$PROJECT_DIR
ExecStart=/usr/bin/docker-compose up -d
ExecStop=/usr/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

    # Recarregar systemd e habilitar serviço
    sudo systemctl daemon-reload
    sudo systemctl enable tibia-tracker.service
    
    log "Serviço systemd configurado e habilitado!"
}

# =============================================================================
# CONFIGURAÇÃO DE FIREWALL
# =============================================================================

setup_firewall() {
    log "Configurando firewall..."
    
    # Habilitar UFW se não estiver
    sudo ufw --force enable
    
    # Permitir SSH
    sudo ufw allow ssh
    
    # Permitir HTTP e HTTPS
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    
    # Permitir portas da aplicação (apenas se necessário para desenvolvimento)
    # sudo ufw allow 8000/tcp  # Backend API
    # sudo ufw allow 3000/tcp  # Frontend Dev
    
    # Mostrar status
    sudo ufw status verbose
    
    log "Firewall configurado!"
}

# =============================================================================
# VERIFICAÇÃO PÓS-DEPLOY
# =============================================================================

verify_deployment() {
    log "Verificando deployment..."
    
    # Verificar containers
    local containers_running=$(sudo docker-compose ps --services --filter "status=running" | wc -l)
    local total_containers=$(sudo docker-compose ps --services | wc -l)
    
    if [[ $containers_running -eq $total_containers ]]; then
        log "Todos os containers estão rodando ($containers_running/$total_containers)"
    else
        warning "Nem todos os containers estão rodando ($containers_running/$total_containers)"
        sudo docker-compose ps
    fi
    
    # Testar endpoints
    sleep 10
    
    # Testar backend
    if curl -f -s http://localhost:8000/health > /dev/null; then
        log "Backend respondendo corretamente"
    else
        warning "Backend não está respondendo"
    fi
    
    # Testar frontend (através do Caddy se configurado)
    if curl -f -s http://localhost > /dev/null; then
        log "Frontend acessível através do proxy"
    else
        warning "Frontend não acessível através do proxy"
    fi
}

# =============================================================================
# FUNÇÃO PRINCIPAL
# =============================================================================

main() {
    log "=== INICIANDO DEPLOY DO TIBIA TRACKER ==="
    
    # Criar diretório de log
    sudo mkdir -p "$(dirname "$LOG_FILE")"
    
    check_prerequisites
    create_backup
    deploy_application
    setup_systemd
    setup_firewall
    verify_deployment
    
    log "=== DEPLOY CONCLUÍDO COM SUCESSO ==="
    log "Aplicação disponível em: http://$(hostname -I | awk '{print $1}')"
    log "Logs da aplicação: $LOG_FILE"
    log "Diretório da aplicação: $PROJECT_DIR"
    
    info "Para gerenciar a aplicação, use:"
    info "  sudo systemctl start tibia-tracker    # Iniciar"
    info "  sudo systemctl stop tibia-tracker     # Parar"
    info "  sudo systemctl status tibia-tracker   # Status"
    info "  sudo docker-compose logs -f           # Ver logs"
}

# =============================================================================
# EXECUÇÃO
# =============================================================================

# Verificar se script está sendo executado
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 