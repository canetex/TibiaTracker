#!/bin/bash

# =============================================================================
# TIBIA TRACKER - REBUILD DE CONTAINERS
# =============================================================================
# Este script realiza rebuild completo de todos os containers
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
LOG_FILE="/var/log/tibia-tracker/rebuild-containers.log"

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
    
    if ! command -v docker &> /dev/null; then
        error "Docker não está instalado"
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        error "Docker Compose não está instalado"
    fi
    
    log "Pré-requisitos verificados!"
}

# =============================================================================
# PARAR CONTAINERS
# =============================================================================

stop_containers() {
    log "Parando todos os containers..."
    
    sudo docker-compose down --remove-orphans
    
    log "Containers parados!"
}

# =============================================================================
# LIMPEZA DE RECURSOS DOCKER
# =============================================================================

cleanup_docker_resources() {
    log "Limpando recursos Docker..."
    
    # Remover containers parados
    log "Removendo containers parados..."
    sudo docker container prune -f
    
    # Remover imagens não utilizadas
    log "Removendo imagens não utilizadas..."
    sudo docker image prune -f
    
    # Remover networks não utilizadas
    log "Removendo networks não utilizadas..."
    sudo docker network prune -f
    
    # Remover volumes órfãos (cuidado com dados importantes)
    warning "Removendo volumes órfãos..."
    sudo docker volume prune -f
    
    # Limpeza geral do sistema Docker
    log "Executando limpeza geral do Docker..."
    sudo docker system prune -f
    
    log "Limpeza concluída!"
}

# =============================================================================
# REBUILD ESPECÍFICO POR SERVIÇO
# =============================================================================

rebuild_backend() {
    log "Rebuilding Backend..."
    
    # Remove imagem específica do backend se existir
    sudo docker rmi $(sudo docker images -q tibia-tracker_backend) 2>/dev/null || true
    
    # Build do backend
    sudo docker-compose build --no-cache backend
    
    log "Backend rebuilt!"
}

rebuild_frontend() {
    log "Rebuilding Frontend..."
    
    # Remove imagem específica do frontend se existir
    sudo docker rmi $(sudo docker images -q tibia-tracker_frontend) 2>/dev/null || true
    
    # Build do frontend
    sudo docker-compose build --no-cache frontend
    
    log "Frontend rebuilt!"
}

# =============================================================================
# REBUILD COMPLETO
# =============================================================================

rebuild_all_containers() {
    log "Rebuilding todos os containers..."
    
    # Rebuild completo sem cache
    sudo docker-compose build --no-cache --parallel
    
    log "Todos os containers rebuilt!"
}

# =============================================================================
# INICIAR SERVIÇOS
# =============================================================================

start_services() {
    log "Iniciando serviços..."
    
    # Iniciar em ordem específica para respeitar dependências
    log "Iniciando PostgreSQL..."
    sudo docker-compose up -d postgres
    sleep 15
    
    log "Iniciando Redis..."
    sudo docker-compose up -d redis
    sleep 10
    
    log "Iniciando Backend..."
    sudo docker-compose up -d backend
    sleep 20
    
    log "Iniciando Frontend..."
    sudo docker-compose up -d frontend
    sleep 10
    
    log "Iniciando Caddy..."
    sudo docker-compose up -d caddy
    sleep 5
    
    log "Iniciando serviços de monitoramento..."
    sudo docker-compose up -d prometheus node-exporter
    
    log "Todos os serviços iniciados!"
}

# =============================================================================
# VERIFICAÇÃO PÓS-REBUILD
# =============================================================================

verify_rebuild() {
    log "Verificando rebuild..."
    
    # Aguardar serviços ficarem prontos
    log "Aguardando serviços ficarem prontos..."
    sleep 30
    
    # Verificar status dos containers
    log "Status dos containers:"
    sudo docker-compose ps
    
    # Verificar logs de erro
    log "Verificando logs de erro..."
    
    local services=("postgres" "redis" "backend" "frontend" "caddy")
    for service in "${services[@]}"; do
        local errors=$(sudo docker-compose logs "$service" 2>&1 | grep -i error | wc -l)
        if [[ $errors -gt 0 ]]; then
            warning "Encontrados $errors erros no serviço $service"
            info "Para ver os logs: sudo docker-compose logs $service"
        else
            log "Serviço $service: OK"
        fi
    done
    
    # Testar endpoints
    log "Testando endpoints..."
    
    sleep 10
    
    # Testar backend
    if curl -f -s http://localhost:8000/health > /dev/null; then
        log "Backend respondendo: ✓"
    else
        warning "Backend não está respondendo: ✗"
    fi
    
    # Testar frontend através do proxy
    if curl -f -s http://localhost > /dev/null; then
        log "Frontend através do proxy: ✓"
    else
        warning "Frontend não acessível através do proxy: ✗"
    fi
    
    # Verificar uso de recursos
    log "Uso de recursos:"
    sudo docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"
}

# =============================================================================
# MENU INTERATIVO
# =============================================================================

show_menu() {
    echo
    echo "=== TIBIA TRACKER - REBUILD DE CONTAINERS ==="
    echo
    echo "Escolha uma opção:"
    echo "1) Rebuild completo (todos os containers)"
    echo "2) Rebuild apenas Backend"
    echo "3) Rebuild apenas Frontend"
    echo "4) Limpeza Docker + Rebuild completo"
    echo "5) Apenas limpeza Docker"
    echo "0) Sair"
    echo
    echo -n "Opção: "
}

handle_menu_option() {
    local option=$1
    
    case $option in
        1)
            log "Iniciando rebuild completo..."
            stop_containers
            rebuild_all_containers
            start_services
            verify_rebuild
            ;;
        2)
            log "Iniciando rebuild do Backend..."
            sudo docker-compose stop backend
            rebuild_backend
            sudo docker-compose up -d backend
            sleep 20
            verify_rebuild
            ;;
        3)
            log "Iniciando rebuild do Frontend..."
            sudo docker-compose stop frontend caddy
            rebuild_frontend
            sudo docker-compose up -d frontend caddy
            sleep 15
            verify_rebuild
            ;;
        4)
            log "Iniciando limpeza + rebuild completo..."
            stop_containers
            cleanup_docker_resources
            rebuild_all_containers
            start_services
            verify_rebuild
            ;;
        5)
            log "Iniciando apenas limpeza Docker..."
            stop_containers
            cleanup_docker_resources
            log "Limpeza concluída. Serviços parados."
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
    log "=== INICIANDO REBUILD DE CONTAINERS ==="
    
    # Criar diretório de log
    sudo mkdir -p "$(dirname "$LOG_FILE")"
    
    check_prerequisites
    
    # Se argumentos foram passados, executar diretamente
    if [[ $# -gt 0 ]]; then
        case $1 in
            "full"|"all")
                handle_menu_option 1
                ;;
            "backend")
                handle_menu_option 2
                ;;
            "frontend")
                handle_menu_option 3
                ;;
            "clean")
                handle_menu_option 4
                ;;
            "cleanup")
                handle_menu_option 5
                ;;
            *)
                error "Argumento inválido. Use: full, backend, frontend, clean, ou cleanup"
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
    
    log "=== REBUILD CONCLUÍDO ==="
    log "Logs salvos em: $LOG_FILE"
}

# =============================================================================
# EXECUÇÃO
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 