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
    
    # Parar containers usando docker-compose se disponível
    if [[ -d "$PROJECT_DIR" ]] && [[ -f "$PROJECT_DIR/docker-compose.yml" ]]; then
        cd "$PROJECT_DIR"
        
        log "Parando containers via docker-compose..."
        sudo docker-compose down --remove-orphans --volumes --timeout 30 || warning "Falha ao parar containers via docker-compose"
    else
        warning "docker-compose.yml não encontrado"
    fi
    
    # Forçar parada de todos os containers relacionados ao projeto
    log "Parando forçadamente todos os containers do Tibia Tracker..."
    local all_containers=$(sudo docker ps -aq --filter "name=tibia-tracker" 2>/dev/null || true)
    if [[ -n "$all_containers" ]]; then
        log "Parando containers: $(echo $all_containers | tr '\n' ' ')"
        sudo docker stop $all_containers || warning "Falha ao parar alguns containers"
        
        log "Removendo containers: $(echo $all_containers | tr '\n' ' ')"
        sudo docker rm -f $all_containers || warning "Falha ao remover alguns containers"
    fi
    
    # Verificar se ainda existem containers com labels relacionados
    log "Verificando containers com labels do projeto..."
    local label_containers=$(sudo docker ps -aq --filter "label=com.docker.compose.project=tibia-tracker" 2>/dev/null || true)
    if [[ -n "$label_containers" ]]; then
        log "Removendo containers com labels do projeto..."
        sudo docker rm -f $label_containers || warning "Falha ao remover containers com labels"
    fi
    
    # Verificar containers órfãos que possam ter ficado
    log "Verificando containers órfãos..."
    local pattern_containers=$(sudo docker ps -aq --filter "name=.*tibia.*" 2>/dev/null || true)
    if [[ -n "$pattern_containers" ]]; then
        log "Removendo containers órfãos que combinam com o padrão..."
        sudo docker rm -f $pattern_containers || warning "Falha ao remover containers órfãos"
    fi
    
    log "✅ Todos os containers relacionados foram removidos!"
}

# =============================================================================
# REMOVER IMAGENS DOCKER
# =============================================================================

remove_docker_images() {
    log "=== REMOVENDO IMAGENS DOCKER ==="
    
    # Remover imagens específicas do projeto (múltiplos padrões)
    log "Removendo imagens do Tibia Tracker..."
    local image_patterns=(
        "tibia-tracker_backend"
        "tibia-tracker_frontend" 
        "tibia-tracker-backend"
        "tibia-tracker-frontend"
        "*tibia-tracker*"
        "*tibia_tracker*"
    )
    
    for pattern in "${image_patterns[@]}"; do
        local image_ids=$(sudo docker images -q "$pattern" 2>/dev/null || true)
        if [[ -n "$image_ids" ]]; then
            log "Removendo imagens que combinam com padrão '$pattern'..."
            sudo docker rmi -f $image_ids || warning "Falha ao remover algumas imagens do padrão $pattern"
        fi
    done
    
    # Remover imagens por label se existirem
    log "Removendo imagens com labels do projeto..."
    local label_images=$(sudo docker images -q --filter "label=com.docker.compose.project=tibia-tracker" 2>/dev/null || true)
    if [[ -n "$label_images" ]]; then
        sudo docker rmi -f $label_images || warning "Falha ao remover imagens com labels"
    fi
    
    # Forçar remoção de imagens que possam ter sido construídas localmente
    log "Verificando imagens construídas localmente..."
    local local_images=$(sudo docker images --filter "reference=localhost/*tibia*" -q 2>/dev/null || true)
    if [[ -n "$local_images" ]]; then
        sudo docker rmi -f $local_images || warning "Falha ao remover imagens locais"
    fi
    
    # Remover imagens órfãs e dangling
    log "Removendo imagens órfãs e dangling..."
    sudo docker image prune -f || warning "Falha ao limpar imagens órfãs"
    
    # Remover imagens intermediárias não utilizadas
    log "Removendo imagens intermediárias não utilizadas..."
    sudo docker image prune -a -f || warning "Falha ao limpar imagens intermediárias"
    
    log "✅ Todas as imagens Docker foram removidas!"
}

# =============================================================================
# REMOVER VOLUMES DOCKER
# =============================================================================

remove_docker_volumes() {
    log "=== REMOVENDO VOLUMES DOCKER ==="
    
    # Remover volumes específicos do projeto (múltiplos padrões)
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
        if sudo docker volume inspect "$volume" &>/dev/null; then
            log "Removendo volume: $volume"
            sudo docker volume rm "$volume" 2>/dev/null || warning "Falha ao remover volume $volume"
        fi
    done
    
    # Buscar volumes com padrões relacionados ao projeto
    log "Buscando volumes com padrões do projeto..."
    local pattern_volumes=$(sudo docker volume ls -q --filter "name=tibia" 2>/dev/null || true)
    if [[ -n "$pattern_volumes" ]]; then
        log "Removendo volumes que combinam com padrão 'tibia'..."
        for vol in $pattern_volumes; do
            sudo docker volume rm "$vol" 2>/dev/null || warning "Falha ao remover volume $vol"
        done
    fi
    
    # Buscar volumes com labels do projeto
    log "Removendo volumes com labels do projeto..."
    local label_volumes=$(sudo docker volume ls -q --filter "label=com.docker.compose.project=tibia-tracker" 2>/dev/null || true)
    if [[ -n "$label_volumes" ]]; then
        for vol in $label_volumes; do
            sudo docker volume rm "$vol" 2>/dev/null || warning "Falha ao remover volume com label $vol"
        done
    fi
    
    # Remover volumes órfãos
    log "Removendo volumes órfãos..."
    sudo docker volume prune -f || warning "Falha ao limpar volumes órfãos"
    
    # Forçar remoção de volumes não utilizados (mais agressivo)
    log "Executando limpeza agressiva de volumes não utilizados..."
    sudo docker volume prune -a -f || warning "Falha na limpeza agressiva de volumes"
    
    log "✅ Todos os volumes Docker foram removidos!"
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
        issues+=("❌ Diretório do projeto ainda existe: $PROJECT_DIR")
    fi
    
    if [[ -d "/var/log/tibia-tracker" ]]; then
        issues+=("❌ Diretório de logs ainda existe: /var/log/tibia-tracker")
    fi
    
    if [[ -d "$BACKUP_DIR" ]]; then
        issues+=("❌ Diretório de backups ainda existe: $BACKUP_DIR")
    fi
    
    # Verificar containers (múltiplos padrões)
    local containers_by_name=$(sudo docker ps -a --filter "name=tibia-tracker" --format "{{.Names}}" 2>/dev/null || true)
    local containers_by_label=$(sudo docker ps -a --filter "label=com.docker.compose.project=tibia-tracker" --format "{{.Names}}" 2>/dev/null || true)
    local containers_by_pattern=$(sudo docker ps -a --filter "name=.*tibia.*" --format "{{.Names}}" 2>/dev/null || true)
    
    if [[ -n "$containers_by_name" ]]; then
        issues+=("❌ Containers por nome ainda existem: $containers_by_name")
    fi
    if [[ -n "$containers_by_label" ]]; then
        issues+=("❌ Containers por label ainda existem: $containers_by_label")
    fi
    if [[ -n "$containers_by_pattern" ]]; then
        issues+=("❌ Containers por padrão ainda existem: $containers_by_pattern")
    fi
    
    # Verificar imagens (múltiplos padrões)
    local images_tibia_tracker=$(sudo docker images --filter "reference=*tibia-tracker*" --format "{{.Repository}}" 2>/dev/null || true)
    local images_tibia_underscore=$(sudo docker images --filter "reference=*tibia_tracker*" --format "{{.Repository}}" 2>/dev/null || true)
    local images_by_label=$(sudo docker images --filter "label=com.docker.compose.project=tibia-tracker" --format "{{.Repository}}" 2>/dev/null || true)
    
    if [[ -n "$images_tibia_tracker" ]]; then
        issues+=("❌ Imagens tibia-tracker ainda existem: $images_tibia_tracker")
    fi
    if [[ -n "$images_tibia_underscore" ]]; then
        issues+=("❌ Imagens tibia_tracker ainda existem: $images_tibia_underscore")
    fi
    if [[ -n "$images_by_label" ]]; then
        issues+=("❌ Imagens por label ainda existem: $images_by_label")
    fi
    
    # Verificar volumes (múltiplos padrões)
    local volumes_by_name=$(sudo docker volume ls --filter "name=tibia-tracker" --format "{{.Name}}" 2>/dev/null || true)
    local volumes_by_pattern=$(sudo docker volume ls --filter "name=*tibia*" --format "{{.Name}}" 2>/dev/null || true)
    local volumes_by_label=$(sudo docker volume ls --filter "label=com.docker.compose.project=tibia-tracker" --format "{{.Name}}" 2>/dev/null || true)
    
    if [[ -n "$volumes_by_name" ]]; then
        issues+=("❌ Volumes por nome ainda existem: $volumes_by_name")
    fi
    if [[ -n "$volumes_by_pattern" ]]; then
        issues+=("❌ Volumes por padrão ainda existem: $volumes_by_pattern")
    fi
    if [[ -n "$volumes_by_label" ]]; then
        issues+=("❌ Volumes por label ainda existem: $volumes_by_label")
    fi
    
    # Verificar networks
    local networks=$(sudo docker network ls --filter "name=tibia*" --format "{{.Name}}" 2>/dev/null || true)
    if [[ -n "$networks" ]]; then
        issues+=("❌ Networks ainda existem: $networks")
    fi
    
    # Verificar usuário
    if id "tibia-tracker" &>/dev/null; then
        issues+=("❌ Usuário tibia-tracker ainda existe")
    fi
    
    # Verificar serviço systemd
    if [[ -f "/etc/systemd/system/tibia-tracker.service" ]]; then
        issues+=("❌ Arquivo de serviço systemd ainda existe")
    fi
    
    # Verificar configurações restantes
    if [[ -f "/etc/logrotate.d/tibia-tracker" ]]; then
        issues+=("❌ Configuração logrotate ainda existe")
    fi
    
    # Verificar backups finais em /tmp
    local tmp_backups=$(ls /tmp/tibia-tracker-final-backup-*.tar.gz 2>/dev/null || true)
    if [[ -n "$tmp_backups" ]]; then
        log "📦 Backups finais encontrados em /tmp: $tmp_backups"
    fi
    
    # Relatar resultados
    if [[ ${#issues[@]} -eq 0 ]]; then
        log "✅ REMOÇÃO COMPLETA VERIFICADA - NENHUM VESTÍGIO ENCONTRADO!"
        log "🎉 Sistema completamente limpo do Tibia Tracker!"
    else
        warning "⚠️ PROBLEMAS ENCONTRADOS NA REMOÇÃO:"
        for issue in "${issues[@]}"; do
            warning "  $issue"
        done
        warning ""
        warning "💡 COMANDOS PARA LIMPEZA MANUAL (se necessário):"
        warning "  sudo docker system prune -a -f --volumes"
        warning "  sudo docker volume prune -a -f"
        warning "  sudo rm -rf $PROJECT_DIR"
        warning "  sudo rm -rf /var/log/tibia-tracker"
        warning "  sudo userdel -r tibia-tracker"
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