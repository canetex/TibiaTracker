#!/bin/bash

# =============================================================================
# TIBIA TRACKER - DESINSTALAÇÃO COMPLETA
# =============================================================================
# Este script remove completamente o Tibia Tracker do sistema
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
BACKUP_DIR="/opt/backups/tibia-tracker"
LOG_FILE="/var/log/tibia-tracker/uninstall.log"

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
# CONFIRMAÇÃO DO USUÁRIO
# =============================================================================

confirm_uninstall() {
    warning "=== ATENÇÃO: DESINSTALAÇÃO COMPLETA DO TIBIA TRACKER ==="
    warning "Esta operação irá:"
    warning "  • Parar e remover todos os containers"
    warning "  • Remover todas as imagens Docker relacionadas"
    warning "  • Deletar todos os volumes e dados persistentes"
    warning "  • Remover o diretório do projeto: $PROJECT_DIR"
    warning "  • Remover logs e backups"
    warning "  • Remover serviços systemd"
    warning "  • Remover usuário tibia-tracker (se existir)"
    warning ""
    warning "TODOS OS DADOS SERÃO PERDIDOS PERMANENTEMENTE!"
    echo
    echo -n "Digite 'CONFIRMO' para continuar com a desinstalação: "
    read -r confirmation
    
    if [[ "$confirmation" != "CONFIRMO" ]]; then
        info "Desinstalação cancelada pelo usuário."
        exit 0
    fi
    
    echo
    echo -n "Tem certeza absoluta? Digite 'SIM' para prosseguir: "
    read -r final_confirmation
    
    if [[ "$final_confirmation" != "SIM" ]]; then
        info "Desinstalação cancelada pelo usuário."
        exit 0
    fi
    
    log "Usuário confirmou a desinstalação completa."
}

# =============================================================================
# BACKUP FINAL DOS DADOS
# =============================================================================

create_final_backup() {
    log "=== CRIANDO BACKUP FINAL DOS DADOS ==="
    
    if [[ -d "$PROJECT_DIR" ]]; then
        log "Criando backup final antes da remoção..."
        
        # Criar diretório de backup final
        local final_backup_dir="/tmp/tibia-tracker-final-backup-$(date +'%Y%m%d-%H%M%S')"
        sudo mkdir -p "$final_backup_dir"
        
        cd "$PROJECT_DIR"
        
        # Backup do banco de dados se estiver rodando
        if sudo docker-compose ps postgres | grep -q "Up" && [[ -f ".env" ]]; then
            source .env
            log "Fazendo backup final do banco de dados..."
            sudo docker-compose exec -T postgres pg_dump -U "$DB_USER" -d "$DB_NAME" > "$final_backup_dir/final-database-backup.sql" || warning "Falha no backup do banco"
        fi
        
        # Backup dos arquivos de configuração
        log "Fazendo backup dos arquivos de configuração..."
        sudo cp -r . "$final_backup_dir/project-files/" 2>/dev/null || warning "Falha no backup dos arquivos"
        
        # Comprimir backup final
        log "Comprimindo backup final..."
        sudo tar -czf "/tmp/tibia-tracker-final-backup-$(date +'%Y%m%d-%H%M%S').tar.gz" -C "$(dirname "$final_backup_dir")" "$(basename "$final_backup_dir")"
        
        # Remover diretório temporário
        sudo rm -rf "$final_backup_dir"
        
        log "Backup final criado em: /tmp/tibia-tracker-final-backup-$(date +'%Y%m%d-%H%M%S').tar.gz"
        warning "IMPORTANTE: Mova este backup para um local seguro se necessário!"
    else
        warning "Diretório do projeto não encontrado, pulando backup"
    fi
}

# =============================================================================
# PARAR E REMOVER CONTAINERS
# =============================================================================

stop_and_remove_containers() {
    log "=== PARANDO E REMOVENDO CONTAINERS ==="
    
    if [[ -d "$PROJECT_DIR" ]] && [[ -f "$PROJECT_DIR/docker-compose.yml" ]]; then
        cd "$PROJECT_DIR"
        
        log "Parando containers..."
        sudo docker-compose down --remove-orphans --volumes || warning "Falha ao parar containers"
        
        log "Removendo containers relacionados..."
        local containers=$(sudo docker ps -a --filter "name=tibia-tracker" --format "{{.ID}}" 2>/dev/null || true)
        if [[ -n "$containers" ]]; then
            sudo docker rm -f $containers || warning "Falha ao remover alguns containers"
        fi
        
        log "Containers removidos!"
    else
        warning "docker-compose.yml não encontrado, pulando remoção de containers"
    fi
}

# =============================================================================
# REMOVER IMAGENS DOCKER
# =============================================================================

remove_docker_images() {
    log "=== REMOVENDO IMAGENS DOCKER ==="
    
    # Remover imagens específicas do projeto
    log "Removendo imagens do Tibia Tracker..."
    local images=(
        "tibia-tracker_backend"
        "tibia-tracker_frontend"
        "tibia-tracker-backend"
        "tibia-tracker-frontend"
    )
    
    for image in "${images[@]}"; do
        local image_ids=$(sudo docker images -q "$image" 2>/dev/null || true)
        if [[ -n "$image_ids" ]]; then
            sudo docker rmi -f $image_ids || warning "Falha ao remover imagem $image"
        fi
    done
    
    # Remover imagens órfãs
    log "Removendo imagens órfãs..."
    sudo docker image prune -f || warning "Falha ao limpar imagens órfãs"
    
    log "Imagens Docker removidas!"
}

# =============================================================================
# REMOVER VOLUMES DOCKER
# =============================================================================

remove_docker_volumes() {
    log "=== REMOVENDO VOLUMES DOCKER ==="
    
    # Remover volumes específicos do projeto
    log "Removendo volumes do Tibia Tracker..."
    local volumes=(
        "tibia-tracker_postgres_data"
        "tibia-tracker_redis_data"
        "tibia-tracker_backend_logs"
        "tibia-tracker_caddy_data"
        "tibia-tracker_caddy_config"
        "tibia-tracker_prometheus_data"
    )
    
    for volume in "${volumes[@]}"; do
        sudo docker volume rm "$volume" 2>/dev/null || true
    done
    
    # Remover volumes órfãos
    log "Removendo volumes órfãos..."
    sudo docker volume prune -f || warning "Falha ao limpar volumes órfãos"
    
    log "Volumes Docker removidos!"
}

# =============================================================================
# REMOVER NETWORKS DOCKER
# =============================================================================

remove_docker_networks() {
    log "=== REMOVENDO NETWORKS DOCKER ==="
    
    # Remover network específica do projeto
    sudo docker network rm tibia-network 2>/dev/null || true
    
    # Remover networks órfãs
    log "Removendo networks órfãs..."
    sudo docker network prune -f || warning "Falha ao limpar networks órfãs"
    
    log "Networks Docker removidas!"
}

# =============================================================================
# REMOVER SERVIÇOS SYSTEMD
# =============================================================================

remove_systemd_services() {
    log "=== REMOVENDO SERVIÇOS SYSTEMD ==="
    
    # Parar e desabilitar serviço
    if systemctl is-enabled tibia-tracker.service &> /dev/null; then
        log "Parando serviço tibia-tracker..."
        sudo systemctl stop tibia-tracker.service || warning "Falha ao parar serviço"
        
        log "Desabilitando serviço tibia-tracker..."
        sudo systemctl disable tibia-tracker.service || warning "Falha ao desabilitar serviço"
    fi
    
    # Remover arquivo de serviço
    if [[ -f "/etc/systemd/system/tibia-tracker.service" ]]; then
        log "Removendo arquivo de serviço systemd..."
        sudo rm -f /etc/systemd/system/tibia-tracker.service
    fi
    
    # Recarregar systemd
    sudo systemctl daemon-reload
    
    log "Serviços systemd removidos!"
}

# =============================================================================
# REMOVER USUÁRIO DO SISTEMA
# =============================================================================

remove_system_user() {
    log "=== REMOVENDO USUÁRIO DO SISTEMA ==="
    
    if id "tibia-tracker" &>/dev/null; then
        log "Removendo usuário tibia-tracker..."
        sudo userdel -r tibia-tracker 2>/dev/null || warning "Falha ao remover usuário (pode ter processos ativos)"
        
        # Forçar remoção se necessário
        if id "tibia-tracker" &>/dev/null; then
            warning "Forçando remoção do usuário..."
            sudo pkill -u tibia-tracker || true
            sudo userdel -f tibia-tracker || warning "Falha ao forçar remoção do usuário"
        fi
        
        log "Usuário tibia-tracker removido!"
    else
        info "Usuário tibia-tracker não existe"
    fi
}

# =============================================================================
# REMOVER DIRETÓRIOS E ARQUIVOS
# =============================================================================

remove_directories() {
    log "=== REMOVENDO DIRETÓRIOS E ARQUIVOS ==="
    
    # Remover diretório principal do projeto
    if [[ -d "$PROJECT_DIR" ]]; then
        log "Removendo diretório do projeto: $PROJECT_DIR"
        sudo rm -rf "$PROJECT_DIR"
    fi
    
    # Remover diretório de backups
    if [[ -d "$BACKUP_DIR" ]]; then
        warning "Removendo diretório de backups: $BACKUP_DIR"
        sudo rm -rf "$BACKUP_DIR"
    fi
    
    # Remover logs
    if [[ -d "/var/log/tibia-tracker" ]]; then
        log "Removendo logs: /var/log/tibia-tracker"
        sudo rm -rf "/var/log/tibia-tracker"
    fi
    
    # Remover configurações logrotate
    if [[ -f "/etc/logrotate.d/tibia-tracker" ]]; then
        log "Removendo configuração logrotate..."
        sudo rm -f "/etc/logrotate.d/tibia-tracker"
    fi
    
    log "Diretórios e arquivos removidos!"
}

# =============================================================================
# LIMPEZA DE REGRAS DE FIREWALL
# =============================================================================

remove_firewall_rules() {
    log "=== REMOVENDO REGRAS DE FIREWALL ==="
    
    if command -v ufw &> /dev/null; then
        log "Removendo regras UFW específicas do Tibia Tracker..."
        
        # Remover regras específicas (se foram adicionadas)
        sudo ufw delete allow 80/tcp 2>/dev/null || true
        sudo ufw delete allow 443/tcp 2>/dev/null || true
        
        log "Regras de firewall verificadas!"
    else
        info "UFW não está instalado"
    fi
}

# =============================================================================
# LIMPEZA FINAL DO SISTEMA
# =============================================================================

final_cleanup() {
    log "=== LIMPEZA FINAL DO SISTEMA ==="
    
    # Limpeza geral do Docker
    log "Executando limpeza geral do Docker..."
    sudo docker system prune -a -f --volumes || warning "Falha na limpeza do Docker"
    
    # Limpar cache de pacotes
    log "Limpando cache de pacotes..."
    sudo apt-get clean || warning "Falha ao limpar cache apt"
    sudo apt-get autoremove -y || warning "Falha ao remover pacotes órfãos"
    
    # Limpar logs do sistema
    log "Limpando logs antigos do sistema..."
    sudo journalctl --vacuum-time=7d || warning "Falha ao limpar logs do journal"
    
    log "Limpeza final concluída!"
}

# =============================================================================
# VERIFICAÇÃO PÓS-REMOÇÃO
# =============================================================================

verify_removal() {
    log "=== VERIFICANDO REMOÇÃO ==="
    
    local issues=()
    
    # Verificar diretórios
    if [[ -d "$PROJECT_DIR" ]]; then
        issues+=("Diretório do projeto ainda existe: $PROJECT_DIR")
    fi
    
    if [[ -d "/var/log/tibia-tracker" ]]; then
        issues+=("Diretório de logs ainda existe")
    fi
    
    # Verificar containers
    local containers=$(sudo docker ps -a --filter "name=tibia-tracker" --format "{{.Names}}" 2>/dev/null || true)
    if [[ -n "$containers" ]]; then
        issues+=("Containers ainda existem: $containers")
    fi
    
    # Verificar imagens
    local images=$(sudo docker images --filter "reference=tibia-tracker*" --format "{{.Repository}}" 2>/dev/null || true)
    if [[ -n "$images" ]]; then
        issues+=("Imagens ainda existem: $images")
    fi
    
    # Verificar volumes
    local volumes=$(sudo docker volume ls --filter "name=tibia-tracker" --format "{{.Name}}" 2>/dev/null || true)
    if [[ -n "$volumes" ]]; then
        issues+=("Volumes ainda existem: $volumes")
    fi
    
    # Verificar usuário
    if id "tibia-tracker" &>/dev/null; then
        issues+=("Usuário tibia-tracker ainda existe")
    fi
    
    # Verificar serviço systemd
    if [[ -f "/etc/systemd/system/tibia-tracker.service" ]]; then
        issues+=("Arquivo de serviço systemd ainda existe")
    fi
    
    # Relatar resultados
    if [[ ${#issues[@]} -eq 0 ]]; then
        log "✅ REMOÇÃO COMPLETA VERIFICADA - NENHUM VESTÍGIO ENCONTRADO!"
    else
        warning "⚠️ PROBLEMAS ENCONTRADOS NA REMOÇÃO:"
        for issue in "${issues[@]}"; do
            warning "  • $issue"
        done
        warning "Você pode precisar remover estes itens manualmente."
    fi
}

# =============================================================================
# RELATÓRIO FINAL
# =============================================================================

generate_final_report() {
    log "=== RELATÓRIO FINAL DE DESINSTALAÇÃO ==="
    
    info "Desinstalação do Tibia Tracker concluída!"
    info "Data/Hora: $(date)"
    info "Log completo: $LOG_FILE"
    
    echo
    warning "RESUMO DA REMOÇÃO:"
    warning "  ✓ Containers Docker parados e removidos"
    warning "  ✓ Imagens Docker removidas"
    warning "  ✓ Volumes Docker removidos"
    warning "  ✓ Networks Docker removidas"
    warning "  ✓ Serviços systemd removidos"
    warning "  ✓ Usuário do sistema removido"
    warning "  ✓ Diretórios e arquivos removidos"
    warning "  ✓ Regras de firewall verificadas"
    warning "  ✓ Limpeza final executada"
    
    echo
    info "Se você precisar reinstalar o Tibia Tracker:"
    info "  1. Execute o script de instalação de requisitos"
    info "  2. Clone o repositório novamente"
    info "  3. Configure o arquivo .env"
    info "  4. Execute o script de deploy"
    
    echo
    warning "Backups finais (se criados) estão em /tmp/"
    warning "Mova-os para um local seguro se necessário!"
}

# =============================================================================
# FUNÇÃO PRINCIPAL
# =============================================================================

main() {
    log "=== INICIANDO DESINSTALAÇÃO COMPLETA DO TIBIA TRACKER ==="
    
    # Criar diretório de log se não existir
    sudo mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    
    confirm_uninstall
    create_final_backup
    stop_and_remove_containers
    remove_docker_images
    remove_docker_volumes
    remove_docker_networks
    remove_systemd_services
    remove_system_user
    remove_directories
    remove_firewall_rules
    final_cleanup
    verify_removal
    generate_final_report
    
    log "=== DESINSTALAÇÃO COMPLETA CONCLUÍDA ==="
    
    echo
    warning "🗑️  TIBIA TRACKER COMPLETAMENTE REMOVIDO DO SISTEMA!"
}

# =============================================================================
# EXECUÇÃO
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 