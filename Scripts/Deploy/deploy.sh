#!/bin/bash

# =============================================================================
# TIBIA TRACKER - SCRIPT DE DEPLOY
# =============================================================================
# Este script realiza o deploy completo da aplicação em um servidor LXC Debian
# IMPORTANTE: Execute a partir do diretório raiz do projeto já baixado
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
# VERIFICAÇÕES PRÉ-DEPLOY
# =============================================================================

check_prerequisites() {
    log "Verificando pré-requisitos..."
    
    # Verificar se estamos no diretório correto
    if [[ ! -f "docker-compose.yml" ]] || [[ ! -f "env.template" ]]; then
        error "Execute este script a partir do diretório raiz do projeto Tibia Tracker"
    fi
    
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
    
    # Verificar se Docker daemon está rodando
    if ! systemctl is-active --quiet docker; then
        log "Iniciando Docker daemon..."
        sudo systemctl start docker
        sleep 5
        if ! systemctl is-active --quiet docker; then
            error "Não foi possível iniciar o Docker daemon"
        fi
    fi
    
    # Testar conectividade com Docker
    if ! sudo docker info &> /dev/null; then
        error "Não é possível conectar ao Docker daemon"
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
    
    # Obter diretório atual (onde está o código)
    CURRENT_DIR=$(pwd)
    log "Usando código do diretório: $CURRENT_DIR"
    
    # Criar diretório do projeto se não existir
    sudo mkdir -p "$PROJECT_DIR"
    
    # Copiar código do diretório atual para o destino de produção
    log "Copiando código do projeto para $PROJECT_DIR..."
    sudo rsync -av --delete \
        --exclude='.git' \
        --exclude='node_modules' \
        --exclude='__pycache__' \
        --exclude='*.pyc' \
        --exclude='.vscode' \
        --exclude='*.log' \
        --exclude='.env' \
        "$CURRENT_DIR/" "$PROJECT_DIR/"
    
    # Copiar .env do diretório atual se existir, senão tentar do /opt
    if [[ -f "$CURRENT_DIR/.env" ]]; then
        # Verificar se origem e destino são diferentes
        if [[ "$CURRENT_DIR" != "$PROJECT_DIR" ]]; then
            log "Copiando arquivo .env do diretório atual..."
            sudo cp "$CURRENT_DIR/.env" "$PROJECT_DIR/.env"
        else
            log "Arquivo .env já está no diretório correto, pulando cópia..."
        fi
    elif [[ -f "/opt/.env" ]]; then
        # Verificar se origem e destino são diferentes
        if [[ "/opt" != "$PROJECT_DIR" ]]; then
            log "Copiando arquivo .env de /opt/..."
            sudo cp "/opt/.env" "$PROJECT_DIR/.env"
        else
            log "Arquivo .env já está no diretório correto, pulando cópia..."
        fi
    else
        log "Nenhum arquivo .env encontrado para copiar"
    fi

    # Entrar no diretório do projeto
    cd "$PROJECT_DIR"
    
    # Verificar se arquivo .env existe
    if [[ ! -f ".env" ]]; then
        if [[ -f "env.template" ]]; then
            log "Copiando env.template para .env..."
            #sudo cp env.template .env
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
    sudo docker-compose down --remove-orphans --volumes || true
    
    # Limpar containers órfãos do projeto especificamente
    log "Removendo containers órfãos do Tibia Tracker..."
    local old_containers=$(sudo docker ps -aq --filter "name=tibia-tracker" 2>/dev/null || true)
    if [[ -n "$old_containers" ]]; then
        sudo docker rm -f $old_containers || warning "Falha ao remover alguns containers antigos"
    fi
    
    # Limpar imagens órfãs relacionadas ao projeto
    log "Removendo imagens órfãs do projeto..."
    sudo docker image prune -f || true
    
    # Build e start dos containers
    log "Construindo e iniciando containers..."
    if ! sudo docker-compose up -d --build; then
        error "Falha ao iniciar containers. Verificando logs..."
        sudo docker-compose logs --tail=50
        exit 1
    fi
    
    # Aguardar containers ficarem prontos com verificação progressiva
    log "Aguardando containers ficarem prontos..."
    local max_wait=120  # 2 minutos
    local wait_time=0
    local check_interval=10
    
    while [[ $wait_time -lt $max_wait ]]; do
        local running_containers=$(sudo docker-compose ps --services --filter "status=running" | wc -l)
        local total_containers=$(sudo docker-compose ps --services | wc -l)
        
        log "Containers rodando: $running_containers/$total_containers"
        
        if [[ $running_containers -eq $total_containers ]] && [[ $total_containers -gt 0 ]]; then
            log "Todos os containers estão rodando!"
            break
        fi
        
        if [[ $wait_time -ge $max_wait ]]; then
            warning "Timeout aguardando containers. Verificando status..."
            sudo docker-compose ps
            sudo docker-compose logs --tail=20
            break
        fi
        
        sleep $check_interval
        wait_time=$((wait_time + check_interval))
    done
    
    # Verificar status final dos containers
    log "Status final dos containers:"
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
# CONFIGURAÇÃO DE AGENDAMENTO AUTOMÁTICO
# =============================================================================

setup_scheduling() {
    log "Configurando agendamento automático..."
    
    # Verificar se o scheduler está configurado no .env
    if [[ -f "$PROJECT_DIR/.env" ]]; then
        # Verificar se as configurações de agendamento estão definidas
        if ! grep -q "DAILY_UPDATE_HOUR" "$PROJECT_DIR/.env"; then
            log "Adicionando configurações de agendamento ao .env..."
            echo "" >> "$PROJECT_DIR/.env"
            echo "# Configurações de Agendamento" >> "$PROJECT_DIR/.env"
            echo "DAILY_UPDATE_HOUR=0" >> "$PROJECT_DIR/.env"
            echo "DAILY_UPDATE_MINUTE=10" >> "$PROJECT_DIR/.env"
            echo "SCHEDULER_TIMEZONE=America/Sao_Paulo" >> "$PROJECT_DIR/.env"
            echo "SCRAPE_DELAY_SECONDS=2" >> "$PROJECT_DIR/.env"
            echo "SCRAPE_RETRY_ATTEMPTS=3" >> "$PROJECT_DIR/.env"
            echo "SCRAPE_RETRY_DELAY_MINUTES=5" >> "$PROJECT_DIR/.env"
        fi
        
        # Verificar se o horário está configurado para 00:10
        if grep -q "DAILY_UPDATE_HOUR=0" "$PROJECT_DIR/.env" && grep -q "DAILY_UPDATE_MINUTE=10" "$PROJECT_DIR/.env"; then
            log "✅ Agendamento já configurado para 00:10"
        else
            log "Atualizando horário do agendamento para 00:10..."
            # Atualizar horário para 00:10
            sed -i 's/DAILY_UPDATE_HOUR=.*/DAILY_UPDATE_HOUR=0/' "$PROJECT_DIR/.env"
            sed -i 's/DAILY_UPDATE_MINUTE=.*/DAILY_UPDATE_MINUTE=10/' "$PROJECT_DIR/.env"
        fi
    else
        warning "Arquivo .env não encontrado. Configure manualmente as variáveis de agendamento:"
        warning "DAILY_UPDATE_HOUR=0"
        warning "DAILY_UPDATE_MINUTE=10"
        warning "SCHEDULER_TIMEZONE=America/Sao_Paulo"
    fi
    
    # Criar script de verificação do agendamento
    sudo tee /usr/local/bin/check-tibia-scheduler.sh > /dev/null <<'EOF'
#!/bin/bash
# Script para verificar status do agendamento do Tibia Tracker

PROJECT_DIR="/opt/tibia-tracker"
LOG_FILE="/var/log/tibia-tracker/scheduler.log"

echo "=== Status do Agendamento Tibia Tracker ==="
echo "Data/Hora: $(date)"
echo ""

# Verificar se o container está rodando
if docker-compose -f "$PROJECT_DIR/docker-compose.yml" ps | grep -q "backend.*Up"; then
    echo "✅ Container backend está rodando"
    
    # Verificar logs do scheduler
    echo ""
    echo "=== Últimos logs do scheduler ==="
    docker-compose -f "$PROJECT_DIR/docker-compose.yml" logs --tail=20 backend | grep -i "scheduler\|agendamento\|update" || echo "Nenhum log de scheduler encontrado"
    
    # Verificar jobs agendados via API (se disponível)
    echo ""
    echo "=== Tentando verificar jobs via API ==="
    if curl -s -f http://localhost:8000/health/ > /dev/null 2>&1; then
        echo "✅ API está respondendo"
        # Aqui você pode adicionar uma chamada para um endpoint que retorne info do scheduler
    else
        echo "❌ API não está respondendo"
    fi
    
else
    echo "❌ Container backend não está rodando"
    echo ""
    echo "=== Status dos containers ==="
    docker-compose -f "$PROJECT_DIR/docker-compose.yml" ps
fi

echo ""
echo "=== Configurações de agendamento ==="
if [[ -f "$PROJECT_DIR/.env" ]]; then
    grep -E "(DAILY_UPDATE|SCHEDULER)" "$PROJECT_DIR/.env" || echo "Configurações não encontradas no .env"
else
    echo "Arquivo .env não encontrado"
fi
EOF

    # Dar permissão de execução
    sudo chmod +x /usr/local/bin/check-tibia-scheduler.sh
    
    # Criar entrada no crontab para verificação diária do agendamento
    (crontab -l 2>/dev/null; echo "# Verificação diária do agendamento Tibia Tracker - 06:00") | crontab -
    (crontab -l 2>/dev/null; echo "0 6 * * * /usr/local/bin/check-tibia-scheduler.sh >> /var/log/tibia-tracker/scheduler-check.log 2>&1") | crontab -
    
    log "✅ Agendamento automático configurado para 00:10 todos os dias"
    log "📋 Use 'check-tibia-scheduler.sh' para verificar o status do agendamento"
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
    
    # Aguardar um pouco mais para estabilização
    sleep 15
    
    # Verificar containers detalhadamente
    local containers_running=$(sudo docker-compose ps --services --filter "status=running" | wc -l)
    local total_containers=$(sudo docker-compose ps --services | wc -l)
    
    if [[ $containers_running -eq $total_containers ]] && [[ $total_containers -gt 0 ]]; then
        log "✅ Todos os containers estão rodando ($containers_running/$total_containers)"
    else
        warning "❌ Nem todos os containers estão rodando ($containers_running/$total_containers)"
        log "Status detalhado dos containers:"
        sudo docker-compose ps
        
        # Mostrar logs dos containers com problemas
        log "Verificando logs dos containers com problemas..."
        local failed_containers=$(sudo docker-compose ps --services --filter "status=exited" 2>/dev/null || true)
        if [[ -n "$failed_containers" ]]; then
            for container in $failed_containers; do
                warning "Logs do container $container:"
                sudo docker-compose logs --tail=10 "$container" || true
            done
        fi
    fi
    
    # Testar endpoints com retry
    log "Testando endpoints da aplicação..."
    local max_health_wait=60
    local health_wait=0
    local health_check_interval=5
    
    # Testar backend com retry
    while [[ $health_wait -lt $max_health_wait ]]; do
        if curl -f -s -m 10 http://localhost:8000/health/ > /dev/null 2>&1; then
            log "✅ Backend respondendo corretamente"
            break
        else
            if [[ $health_wait -ge $max_health_wait ]]; then
                warning "❌ Backend não está respondendo após $max_health_wait segundos"
                log "Verificando logs do backend:"
                sudo docker-compose logs --tail=10 backend || true
            else
                log "⏳ Aguardando backend ficar pronto... ($health_wait/$max_health_wait)s"
            fi
        fi
        sleep $health_check_interval
        health_wait=$((health_wait + health_check_interval))
    done
    
    # Testar frontend (através do Caddy se configurado)
    if curl -f -s -m 10 http://localhost > /dev/null 2>&1; then
        log "✅ Frontend acessível através do proxy"
    else
        warning "❌ Frontend não acessível através do proxy"
        log "Verificando logs do Caddy:"
        sudo docker-compose logs --tail=10 caddy || true
    fi
    
    # Verificar conectividade do banco de dados
    if sudo docker-compose exec -T postgres pg_isready -U tibia_user > /dev/null 2>&1; then
        log "✅ Banco de dados PostgreSQL respondendo"
    else
        warning "❌ Banco de dados PostgreSQL não está respondendo"
        log "Verificando logs do PostgreSQL:"
        sudo docker-compose logs --tail=10 postgres || true
    fi
    
    # Verificar Redis
    if sudo docker-compose exec -T redis redis-cli ping | grep -q "PONG"; then
        log "✅ Redis respondendo corretamente"
    else
        warning "❌ Redis não está respondendo"
        log "Verificando logs do Redis:"
        sudo docker-compose logs --tail=10 redis || true
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
    setup_scheduling
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
    info ""
    info "Para verificar o agendamento:"
    info "  check-tibia-scheduler.sh              # Status do scheduler"
    info "  sudo docker-compose logs backend | grep -i scheduler  # Logs do scheduler"
    info ""
    info "📅 Agendamento automático configurado para 00:10 todos os dias"
    info "🔄 Todos os personagens serão atualizados automaticamente"
}

# =============================================================================
# EXECUÇÃO
# =============================================================================

# Verificar se script está sendo executado
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 