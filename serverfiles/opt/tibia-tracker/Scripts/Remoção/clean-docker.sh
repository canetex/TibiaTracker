#!/bin/bash

# =============================================================================
# TIBIA TRACKER - LIMPEZA ESPECÍFICA DO DOCKER
# =============================================================================
# Este script remove apenas recursos Docker do Tibia Tracker
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
LOG_FILE="/var/log/tibia-tracker/clean-docker.log"

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
# VERIFICAÇÕES PRÉ-EXECUÇÃO
# =============================================================================

check_prerequisites() {
    log "Verificando pré-requisitos..."
    
    if ! command -v docker &> /dev/null; then
        error "Docker não está instalado"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        error "Docker Compose não está instalado"
        exit 1
    fi
    
    log "Pré-requisitos verificados!"
}

# =============================================================================
# PARAR CONTAINERS
# =============================================================================

stop_containers() {
    log "=== PARANDO CONTAINERS DO TIBIA TRACKER ==="
    
    if [[ -d "$PROJECT_DIR" ]] && [[ -f "$PROJECT_DIR/docker-compose.yml" ]]; then
        cd "$PROJECT_DIR"
        
        log "Parando containers via docker-compose..."
        sudo docker-compose down --remove-orphans || warning "Falha ao parar alguns containers"
        
        log "Containers parados via docker-compose!"
    else
        warning "docker-compose.yml não encontrado em $PROJECT_DIR"
    fi
    
    # Parar containers por nome (fallback)
    log "Verificando containers com nome 'tibia-tracker'..."
    local containers=$(sudo docker ps --filter "name=tibia-tracker" --format "{{.ID}} {{.Names}}")
    
    if [[ -n "$containers" ]]; then
        echo "$containers" | while read -r container_id container_name; do
            log "Parando container: $container_name ($container_id)"
            sudo docker stop "$container_id" || warning "Falha ao parar $container_name"
        done
    else
        info "Nenhum container do Tibia Tracker em execução"
    fi
}

# =============================================================================
# REMOVER CONTAINERS
# =============================================================================

remove_containers() {
    log "=== REMOVENDO CONTAINERS DO TIBIA TRACKER ==="
    
    # Remover containers parados com nome tibia-tracker
    local containers=$(sudo docker ps -a --filter "name=tibia-tracker" --format "{{.ID}} {{.Names}}")
    
    if [[ -n "$containers" ]]; then
        echo "$containers" | while read -r container_id container_name; do
            log "Removendo container: $container_name ($container_id)"
            sudo docker rm -f "$container_id" || warning "Falha ao remover $container_name"
        done
        
        log "Containers do Tibia Tracker removidos!"
    else
        info "Nenhum container do Tibia Tracker encontrado para remoção"
    fi
    
    # Limpeza geral de containers parados
    log "Removendo containers parados gerais..."
    sudo docker container prune -f || warning "Falha na limpeza de containers parados"
}

# =============================================================================
# REMOVER IMAGENS
# =============================================================================

remove_images() {
    log "=== REMOVENDO IMAGENS DO TIBIA TRACKER ==="
    
    # Lista de padrões de imagens do projeto
    local image_patterns=(
        "tibia-tracker"
        "tibia_tracker"
        "tibia-tracker_backend"
        "tibia-tracker_frontend"
        "tibia_tracker_backend"
        "tibia_tracker_frontend"
    )
    
    for pattern in "${image_patterns[@]}"; do
        log "Procurando imagens com padrão: $pattern"
        local images=$(sudo docker images --filter "reference=*${pattern}*" --format "{{.ID}} {{.Repository}}:{{.Tag}}")
        
        if [[ -n "$images" ]]; then
            echo "$images" | while read -r image_id image_name; do
                log "Removendo imagem: $image_name ($image_id)"
                sudo docker rmi -f "$image_id" || warning "Falha ao remover imagem $image_name"
            done
        fi
    done
    
    # Remover imagens órfãs
    log "Removendo imagens órfãs..."
    sudo docker image prune -f || warning "Falha na limpeza de imagens órfãs"
    
    # Remover imagens não utilizadas
    log "Removendo imagens não utilizadas..."
    local unused_images=$(sudo docker images --filter "dangling=true" -q)
    if [[ -n "$unused_images" ]]; then
        sudo docker rmi $unused_images || warning "Falha ao remover algumas imagens não utilizadas"
    fi
    
    log "Limpeza de imagens concluída!"
}

# =============================================================================
# REMOVER VOLUMES
# =============================================================================

remove_volumes() {
    log "=== REMOVENDO VOLUMES DO TIBIA TRACKER ==="
    
    # Lista de volumes específicos do projeto
    local volume_patterns=(
        "tibia-tracker"
        "tibia_tracker"
        "postgres_data"
        "redis_data"
        "backend_logs"
        "caddy_data"
        "caddy_config"
        "prometheus_data"
    )
    
    for pattern in "${volume_patterns[@]}"; do
        log "Procurando volumes com padrão: $pattern"
        local volumes=$(sudo docker volume ls --filter "name=$pattern" --format "{{.Name}}")
        
        if [[ -n "$volumes" ]]; then
            echo "$volumes" | while read -r volume_name; do
                log "Removendo volume: $volume_name"
                sudo docker volume rm "$volume_name" || warning "Falha ao remover volume $volume_name"
            done
        fi
    done
    
    # Remover volumes órfãos
    log "Removendo volumes órfãos..."
    sudo docker volume prune -f || warning "Falha na limpeza de volumes órfãos"
    
    log "Limpeza de volumes concluída!"
}

# =============================================================================
# REMOVER NETWORKS
# =============================================================================

remove_networks() {
    log "=== REMOVENDO NETWORKS DO TIBIA TRACKER ==="
    
    # Network específica do projeto
    local networks=("tibia-network" "tibia_tracker_default")
    
    for network in "${networks[@]}"; do
        if sudo docker network ls --filter "name=$network" --format "{{.Name}}" | grep -q "$network"; then
            log "Removendo network: $network"
            sudo docker network rm "$network" || warning "Falha ao remover network $network"
        else
            info "Network $network não encontrada"
        fi
    done
    
    # Remover networks órfãs
    log "Removendo networks órfãs..."
    sudo docker network prune -f || warning "Falha na limpeza de networks órfãs"
    
    log "Limpeza de networks concluída!"
}

# =============================================================================
# LIMPEZA DO CACHE DE BUILD
# =============================================================================

clean_build_cache() {
    log "=== LIMPANDO CACHE DE BUILD ==="
    
    # Limpar cache de build do Docker
    log "Limpando cache de build do Docker..."
    sudo docker builder prune -a -f || warning "Falha na limpeza do cache de build"
    
    log "Cache de build limpo!"
}

# =============================================================================
# RELATÓRIO DE LIMPEZA
# =============================================================================

generate_cleanup_report() {
    log "=== RELATÓRIO DE LIMPEZA DOCKER ==="
    
    info "Status atual do Docker após limpeza:"
    
    # Containers
    local containers_count=$(sudo docker ps -a | wc -l)
    info "Containers totais no sistema: $((containers_count - 1))"
    
    # Imagens
    local images_count=$(sudo docker images | wc -l)
    info "Imagens totais no sistema: $((images_count - 1))"
    
    # Volumes
    local volumes_count=$(sudo docker volume ls | wc -l)
    info "Volumes totais no sistema: $((volumes_count - 1))"
    
    # Networks
    local networks_count=$(sudo docker network ls | wc -l)
    info "Networks totais no sistema: $((networks_count - 1))"
    
    # Espaço ocupado
    info "Uso de espaço do Docker:"
    sudo docker system df
    
    # Verificar se ainda existem recursos do Tibia Tracker
    info "Verificando recursos remanescentes do Tibia Tracker:"
    
    local remaining_containers=$(sudo docker ps -a --filter "name=tibia-tracker" --format "{{.Names}}" | wc -l)
    local remaining_images=$(sudo docker images --filter "reference=*tibia-tracker*" --format "{{.Repository}}" | wc -l)
    local remaining_volumes=$(sudo docker volume ls --filter "name=tibia-tracker" --format "{{.Name}}" | wc -l)
    
    if [[ $remaining_containers -eq 0 ]] && [[ $remaining_images -eq 0 ]] && [[ $remaining_volumes -eq 0 ]]; then
        log "✅ LIMPEZA COMPLETA - NENHUM RECURSO DO TIBIA TRACKER ENCONTRADO!"
    else
        warning "⚠️ RECURSOS REMANESCENTES ENCONTRADOS:"
        [[ $remaining_containers -gt 0 ]] && warning "  • $remaining_containers containers"
        [[ $remaining_images -gt 0 ]] && warning "  • $remaining_images imagens"
        [[ $remaining_volumes -gt 0 ]] && warning "  • $remaining_volumes volumes"
    fi
}

# =============================================================================
# MENU INTERATIVO
# =============================================================================

show_menu() {
    echo
    echo "=== TIBIA TRACKER - LIMPEZA DOCKER ==="
    echo
    echo "Escolha uma opção:"
    echo "1) Limpeza completa (todos os recursos Docker)"
    echo "2) Apenas parar containers"
    echo "3) Apenas remover containers"
    echo "4) Apenas remover imagens"
    echo "5) Apenas remover volumes"
    echo "6) Apenas remover networks"
    echo "7) Apenas limpar cache de build"
    echo "8) Relatório de status Docker"
    echo "0) Sair"
    echo
    echo -n "Opção: "
}

handle_menu_option() {
    local option=$1
    
    case $option in
        1)
            log "Iniciando limpeza completa do Docker..."
            stop_containers
            remove_containers
            remove_images
            remove_volumes
            remove_networks
            clean_build_cache
            generate_cleanup_report
            ;;
        2)
            stop_containers
            ;;
        3)
            stop_containers
            remove_containers
            ;;
        4)
            remove_images
            ;;
        5)
            remove_volumes
            ;;
        6)
            remove_networks
            ;;
        7)
            clean_build_cache
            ;;
        8)
            generate_cleanup_report
            ;;
        0)
            info "Saindo..."
            exit 0
            ;;
        *)
            error "Opção inválida!"
            ;;
    esac
}

# =============================================================================
# FUNÇÃO PRINCIPAL
# =============================================================================

main() {
    log "=== INICIANDO LIMPEZA DOCKER DO TIBIA TRACKER ==="
    
    # Criar diretório de log
    sudo mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    
    check_prerequisites
    
    # Se argumentos foram passados, executar diretamente
    if [[ $# -gt 0 ]]; then
        case $1 in
            "all"|"full")
                handle_menu_option 1
                ;;
            "stop")
                handle_menu_option 2
                ;;
            "containers")
                handle_menu_option 3
                ;;
            "images")
                handle_menu_option 4
                ;;
            "volumes")
                handle_menu_option 5
                ;;
            "networks")
                handle_menu_option 6
                ;;
            "cache")
                handle_menu_option 7
                ;;
            "report")
                handle_menu_option 8
                ;;
            *)
                error "Argumento inválido. Use: all, stop, containers, images, volumes, networks, cache, ou report"
                ;;
        esac
    else
        # Menu interativo
        while true; do
            show_menu
            read -r option
            handle_menu_option "$option"
            echo
            echo "Pressione Enter para continuar..."
            read -r
        done
    fi
    
    log "=== LIMPEZA DOCKER CONCLUÍDA ==="
    log "Log completo salvo em: $LOG_FILE"
}

# =============================================================================
# EXECUÇÃO
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 