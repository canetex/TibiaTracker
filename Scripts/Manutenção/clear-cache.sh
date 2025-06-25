#!/bin/bash

# =============================================================================
# TIBIA TRACKER - LIMPEZA DE CACHE
# =============================================================================
# Este script limpa todos os caches da aplicação (Redis, Docker, logs, etc.)
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
LOG_FILE="/var/log/tibia-tracker/clear-cache.log"

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
# LIMPEZA DO REDIS
# =============================================================================

clear_redis_cache() {
    log "Limpando cache Redis..."
    
    # Verificar se Redis está rodando
    if sudo docker-compose ps redis | grep -q "Up"; then
        log "Redis está rodando, executando FLUSHALL..."
        
        # Executar FLUSHALL para limpar todo o cache
        sudo docker-compose exec redis redis-cli FLUSHALL
        
        # Verificar limpeza
        local keys_count=$(sudo docker-compose exec redis redis-cli DBSIZE | tr -d '\r')
        if [[ "$keys_count" == "0" ]]; then
            log "Cache Redis limpo com sucesso! ($keys_count chaves restantes)"
        else
            warning "Cache Redis pode não ter sido limpo completamente ($keys_count chaves restantes)"
        fi
        
        # Mostrar informações do Redis
        log "Informações do Redis:"
        sudo docker-compose exec redis redis-cli INFO memory | grep -E "used_memory_human|used_memory_peak_human"
        
    else
        warning "Redis não está rodando, pulando limpeza do cache Redis"
    fi
}

# =============================================================================
# LIMPEZA DE CACHE DO DOCKER
# =============================================================================

clear_docker_cache() {
    log "Limpando cache do Docker..."
    
    # Cache de build
    log "Limpando cache de build do Docker..."
    sudo docker builder prune -f
    
    # Imagens não utilizadas
    log "Removendo imagens não utilizadas..."
    sudo docker image prune -f
    
    # Containers parados
    log "Removendo containers parados..."
    sudo docker container prune -f
    
    # Networks não utilizadas
    log "Removendo networks não utilizadas..."
    sudo docker network prune -f
    
    # Mostrar espaço liberado
    log "Cache do Docker limpo!"
}

# =============================================================================
# LIMPEZA DE LOGS DA APLICAÇÃO
# =============================================================================

clear_application_logs() {
    log "Limpando logs da aplicação..."
    
    local log_dir="/var/log/tibia-tracker"
    
    if [[ -d "$log_dir" ]]; then
        # Fazer backup dos logs atuais se necessário
        local backup_dir="$log_dir/archive"
        sudo mkdir -p "$backup_dir"
        
        # Comprimir logs antigos (mais de 7 dias)
        find "$log_dir" -name "*.log" -type f -mtime +7 -exec gzip {} \;
        
        # Mover logs comprimidos para arquivo
        find "$log_dir" -name "*.log.gz" -type f -exec mv {} "$backup_dir/" \;
        
        # Truncar logs atuais (manter arquivo, mas zerar conteúdo)
        find "$log_dir" -name "*.log" -type f -mtime -7 -exec truncate -s 0 {} \;
        
        # Manter apenas últimos 30 dias de arquivo
        find "$backup_dir" -name "*.log.gz" -type f -mtime +30 -delete
        
        log "Logs da aplicação limpos!"
    else
        warning "Diretório de logs não encontrado: $log_dir"
    fi
}

# =============================================================================
# LIMPEZA DE LOGS DO DOCKER
# =============================================================================

clear_docker_logs() {
    log "Limpando logs dos containers Docker..."
    
    # Obter lista de containers
    local containers=$(sudo docker-compose ps -q)
    
    if [[ -n "$containers" ]]; then
        for container in $containers; do
            local container_name=$(sudo docker inspect --format='{{.Name}}' "$container" | sed 's/^\/*//')
            
            # Verificar tamanho do log
            local log_file=$(sudo docker inspect --format='{{.LogPath}}' "$container")
            if [[ -f "$log_file" ]]; then
                local log_size=$(du -h "$log_file" | cut -f1)
                log "Container $container_name: log atual $log_size"
                
                # Truncar log se maior que 100MB
                local log_size_bytes=$(stat -c%s "$log_file" 2>/dev/null || echo 0)
                if [[ $log_size_bytes -gt 104857600 ]]; then  # 100MB
                    log "Truncando log do container $container_name (tamanho: $log_size)"
                    sudo truncate -s 0 "$log_file"
                fi
            fi
        done
    else
        warning "Nenhum container encontrado"
    fi
    
    log "Logs dos containers verificados!"
}

# =============================================================================
# LIMPEZA DE CACHE DO SISTEMA
# =============================================================================

clear_system_cache() {
    log "Limpando cache do sistema..."
    
    # Limpar cache de pacotes apt
    log "Limpando cache apt..."
    sudo apt-get clean
    sudo apt-get autoclean
    
    # Limpar arquivos temporários
    log "Limpando arquivos temporários..."
    sudo find /tmp -type f -atime +7 -delete 2>/dev/null || true
    sudo find /var/tmp -type f -atime +7 -delete 2>/dev/null || true
    
    # Limpar logs do sistema antigos
    log "Limpando logs do sistema antigos..."
    sudo journalctl --vacuum-time=7d
    
    log "Cache do sistema limpo!"
}

# =============================================================================
# LIMPEZA DE CACHE DO FRONTEND
# =============================================================================

clear_frontend_cache() {
    log "Limpando cache do Frontend..."
    
    # Se o container frontend estiver rodando, executar limpeza dentro dele
    if sudo docker-compose ps frontend | grep -q "Up"; then
        log "Limpando cache npm no container frontend..."
        sudo docker-compose exec frontend npm cache clean --force 2>/dev/null || true
        
        # Limpar build cache se existir
        sudo docker-compose exec frontend rm -rf /app/.next 2>/dev/null || true
        sudo docker-compose exec frontend rm -rf /app/build 2>/dev/null || true
        sudo docker-compose exec frontend rm -rf /app/dist 2>/dev/null || true
        
        log "Cache do frontend limpo!"
    else
        warning "Container frontend não está rodando"
    fi
}

# =============================================================================
# LIMPEZA DE CACHE DO BACKEND
# =============================================================================

clear_backend_cache() {
    log "Limpando cache do Backend..."
    
    # Se o container backend estiver rodando, executar limpeza dentro dele
    if sudo docker-compose ps backend | grep -q "Up"; then
        log "Limpando cache Python no container backend..."
        sudo docker-compose exec backend find /app -name "*.pyc" -delete 2>/dev/null || true
        sudo docker-compose exec backend find /app -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
        
        # Limpar cache pip se existir
        sudo docker-compose exec backend pip cache purge 2>/dev/null || true
        
        log "Cache do backend limpo!"
    else
        warning "Container backend não está rodando"
    fi
}

# =============================================================================
# RELATÓRIO DE ESPAÇO
# =============================================================================

show_space_report() {
    log "Gerando relatório de espaço..."
    
    info "=== RELATÓRIO DE ESPAÇO LIBERADO ==="
    
    # Espaço em disco geral
    info "Espaço total em disco:"
    df -h / | tail -1
    
    # Espaço Docker
    info "Uso do Docker:"
    sudo docker system df
    
    # Logs da aplicação
    local log_dir="/var/log/tibia-tracker"
    if [[ -d "$log_dir" ]]; then
        local log_size=$(du -sh "$log_dir" 2>/dev/null | cut -f1)
        info "Logs da aplicação: $log_size"
    fi
    
    # Cache Redis
    if sudo docker-compose ps redis | grep -q "Up"; then
        local redis_memory=$(sudo docker-compose exec redis redis-cli INFO memory | grep "used_memory_human" | cut -d: -f2 | tr -d '\r')
        info "Memória Redis em uso: $redis_memory"
    fi
    
    info "=== FIM DO RELATÓRIO ==="
}

# =============================================================================
# MENU INTERATIVO
# =============================================================================

show_menu() {
    echo
    echo "=== TIBIA TRACKER - LIMPEZA DE CACHE ==="
    echo
    echo "Escolha uma opção:"
    echo "1) Limpeza completa (todos os caches)"
    echo "2) Apenas Redis"
    echo "3) Apenas Docker"
    echo "4) Apenas logs da aplicação"
    echo "5) Apenas cache do sistema"
    echo "6) Apenas frontend"
    echo "7) Apenas backend"
    echo "8) Relatório de espaço"
    echo "0) Sair"
    echo
    echo -n "Opção: "
}

handle_menu_option() {
    local option=$1
    
    case $option in
        1)
            log "Iniciando limpeza completa..."
            clear_redis_cache
            clear_frontend_cache
            clear_backend_cache
            clear_docker_cache
            clear_application_logs
            clear_docker_logs
            clear_system_cache
            show_space_report
            ;;
        2)
            clear_redis_cache
            ;;
        3)
            clear_docker_cache
            ;;
        4)
            clear_application_logs
            clear_docker_logs
            ;;
        5)
            clear_system_cache
            ;;
        6)
            clear_frontend_cache
            ;;
        7)
            clear_backend_cache
            ;;
        8)
            show_space_report
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
    log "=== INICIANDO LIMPEZA DE CACHE ==="
    
    # Criar diretório de log
    sudo mkdir -p "$(dirname "$LOG_FILE")"
    
    check_prerequisites
    
    # Se argumentos foram passados, executar diretamente
    if [[ $# -gt 0 ]]; then
        case $1 in
            "all"|"full")
                handle_menu_option 1
                ;;
            "redis")
                handle_menu_option 2
                ;;
            "docker")
                handle_menu_option 3
                ;;
            "logs")
                handle_menu_option 4
                ;;
            "system")
                handle_menu_option 5
                ;;
            "frontend")
                handle_menu_option 6
                ;;
            "backend")
                handle_menu_option 7
                ;;
            "report")
                handle_menu_option 8
                ;;
            *)
                error "Argumento inválido. Use: all, redis, docker, logs, system, frontend, backend, ou report"
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
    
    log "=== LIMPEZA CONCLUÍDA ==="
    log "Logs salvos em: $LOG_FILE"
}

# =============================================================================
# EXECUÇÃO
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 