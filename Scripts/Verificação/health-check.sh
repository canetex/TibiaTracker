#!/bin/bash

# =============================================================================
# TIBIA TRACKER - VERIFICAÇÃO DE SAÚDE DO SISTEMA
# =============================================================================
# Este script verifica a saúde completa do sistema
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
LOG_FILE="/var/log/tibia-tracker/health-check.log"

# Contadores
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# =============================================================================
# FUNÇÕES AUXILIARES
# =============================================================================

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR $(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[WARNING $(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[INFO $(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[✓]${NC} $1" | tee -a "$LOG_FILE"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

fail() {
    echo -e "${RED}[✗]${NC} $1" | tee -a "$LOG_FILE"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

test_start() {
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    info "Teste $TESTS_TOTAL: $1"
}

# =============================================================================
# VERIFICAÇÕES BÁSICAS DO SISTEMA
# =============================================================================

check_system_basics() {
    log "=== VERIFICAÇÕES BÁSICAS DO SISTEMA ==="
    
    # Verificar se é Linux
    test_start "Sistema operacional"
    if [[ "$(uname)" == "Linux" ]]; then
        success "Sistema Linux detectado: $(uname -r)"
    else
        fail "Sistema não é Linux: $(uname)"
    fi
    
    # Verificar espaço em disco
    test_start "Espaço em disco"
    local disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    if [[ $disk_usage -lt 90 ]]; then
        success "Espaço em disco OK: ${disk_usage}% usado"
    else
        fail "Espaço em disco crítico: ${disk_usage}% usado"
    fi
    
    # Verificar memória RAM
    test_start "Memória RAM"
    local mem_total=$(free -m | awk 'NR==2{print $2}')
    local mem_used=$(free -m | awk 'NR==2{print $3}')
    local mem_percent=$((mem_used * 100 / mem_total))
    if [[ $mem_percent -lt 85 ]]; then
        success "Memória RAM OK: ${mem_percent}% usado (${mem_used}MB/${mem_total}MB)"
    else
        warning "Memória RAM alta: ${mem_percent}% usado (${mem_used}MB/${mem_total}MB)"
    fi
    
    # Verificar carga do sistema
    test_start "Carga do sistema"
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',')
    local cpu_cores=$(nproc)
    if (( $(echo "$load_avg < $cpu_cores" | bc -l) )); then
        success "Carga do sistema OK: $load_avg (CPUs: $cpu_cores)"
    else
        warning "Carga do sistema alta: $load_avg (CPUs: $cpu_cores)"
    fi
}

# =============================================================================
# VERIFICAÇÕES DE REQUISITOS
# =============================================================================

check_requirements() {
    log "=== VERIFICAÇÕES DE REQUISITOS ==="
    
    # Docker
    test_start "Docker instalado"
    if command -v docker &> /dev/null; then
        local docker_version=$(docker --version | cut -d' ' -f3 | cut -d',' -f1)
        success "Docker instalado: $docker_version"
    else
        fail "Docker não está instalado"
    fi
    
    # Docker Compose
    test_start "Docker Compose instalado"
    if command -v docker-compose &> /dev/null; then
        local compose_version=$(docker-compose --version | cut -d' ' -f3 | cut -d',' -f1)
        success "Docker Compose instalado: $compose_version"
    else
        fail "Docker Compose não está instalado"
    fi
    
    # Git
    test_start "Git instalado"
    if command -v git &> /dev/null; then
        local git_version=$(git --version | cut -d' ' -f3)
        success "Git instalado: $git_version"
    else
        fail "Git não está instalado"
    fi
    
    # Curl
    test_start "Curl instalado"
    if command -v curl &> /dev/null; then
        local curl_version=$(curl --version | head -1 | cut -d' ' -f2)
        success "Curl instalado: $curl_version"
    else
        fail "Curl não está instalado"
    fi
}

# =============================================================================
# VERIFICAÇÕES DO PROJETO
# =============================================================================

check_project() {
    log "=== VERIFICAÇÕES DO PROJETO ==="
    
    # Diretório do projeto
    test_start "Diretório do projeto"
    if [[ -d "$PROJECT_DIR" ]]; then
        success "Diretório do projeto existe: $PROJECT_DIR"
        cd "$PROJECT_DIR"
    else
        fail "Diretório do projeto não encontrado: $PROJECT_DIR"
        return 1
    fi
    
    # Arquivo docker-compose.yml
    test_start "docker-compose.yml"
    if [[ -f "docker-compose.yml" ]]; then
        success "docker-compose.yml encontrado"
    else
        fail "docker-compose.yml não encontrado"
    fi
    
    # Arquivo .env
    test_start "Arquivo .env"
    if [[ -f ".env" ]]; then
        success "Arquivo .env encontrado"
        source .env
    else
        fail "Arquivo .env não encontrado"
    fi
    
    # Estrutura de diretórios
    test_start "Estrutura de diretórios"
    local required_dirs=("Backend" "Frontend" "Scripts")
    local missing_dirs=()
    
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            missing_dirs+=("$dir")
        fi
    done
    
    if [[ ${#missing_dirs[@]} -eq 0 ]]; then
        success "Estrutura de diretórios OK"
    else
        fail "Diretórios ausentes: ${missing_dirs[*]}"
    fi
}

# =============================================================================
# VERIFICAÇÕES DOS CONTAINERS
# =============================================================================

check_containers() {
    log "=== VERIFICAÇÕES DOS CONTAINERS ==="
    
    # Status dos containers
    test_start "Status dos containers"
    local containers_running=$(sudo docker-compose ps --services --filter "status=running" 2>/dev/null | wc -l)
    local total_containers=$(sudo docker-compose ps --services 2>/dev/null | wc -l)
    
    if [[ $containers_running -eq $total_containers ]] && [[ $total_containers -gt 0 ]]; then
        success "Todos os containers estão rodando ($containers_running/$total_containers)"
    else
        fail "Nem todos os containers estão rodando ($containers_running/$total_containers)"
    fi
    
    # Verificar containers específicos
    local required_services=("postgres" "redis" "backend" "frontend" "caddy")
    
    for service in "${required_services[@]}"; do
        test_start "Container $service"
        if sudo docker-compose ps "$service" | grep -q "Up"; then
            success "Container $service está rodando"
        else
            fail "Container $service não está rodando"
        fi
    done
    
    # Health checks dos containers
    test_start "Health checks dos containers"
    local unhealthy_containers=$(sudo docker ps --filter "health=unhealthy" --format "{{.Names}}" | wc -l)
    if [[ $unhealthy_containers -eq 0 ]]; then
        success "Todos os containers estão saudáveis"
    else
        warning "$unhealthy_containers containers não estão saudáveis"
    fi
}

# =============================================================================
# VERIFICAÇÕES DE CONECTIVIDADE
# =============================================================================

check_connectivity() {
    log "=== VERIFICAÇÕES DE CONECTIVIDADE ==="
    
    # PostgreSQL
    test_start "Conexão PostgreSQL"
    if [[ -n "${DB_USER:-}" ]] && [[ -n "${DB_NAME:-}" ]]; then
        if sudo docker-compose exec postgres pg_isready -U "$DB_USER" -d "$DB_NAME" &> /dev/null; then
            success "PostgreSQL respondendo"
        else
            fail "PostgreSQL não está respondendo"
        fi
    else
        fail "Variáveis do banco não definidas"
    fi
    
    # Redis
    test_start "Conexão Redis"
    if sudo docker-compose exec redis redis-cli ping | grep -q "PONG"; then
        success "Redis respondendo"
    else
        fail "Redis não está respondendo"
    fi
    
    # Backend API
    test_start "Backend API"
    if curl -f -s -m 10 http://localhost:8000/health > /dev/null; then
        success "Backend API respondendo"
    else
        fail "Backend API não está respondendo"
    fi
    
    # Frontend
    test_start "Frontend"
    if curl -f -s -m 10 http://localhost:3000 > /dev/null; then
        success "Frontend respondendo diretamente"
    else
        warning "Frontend não está respondendo diretamente"
    fi
    
    # Proxy (Caddy)
    test_start "Proxy Caddy"
    if curl -f -s -m 10 http://localhost > /dev/null; then
        success "Proxy Caddy respondendo"
    else
        fail "Proxy Caddy não está respondendo"
    fi
}

# =============================================================================
# VERIFICAÇÕES DE ENDPOINTS DA API
# =============================================================================

check_api_endpoints() {
    log "=== VERIFICAÇÕES DOS ENDPOINTS DA API ==="
    
    local base_url="http://localhost:8000"
    
    # Health endpoint
    test_start "Endpoint /health"
    if curl -f -s "$base_url/health" | grep -q "status"; then
        success "Endpoint /health funcionando"
    else
        fail "Endpoint /health não está funcionando"
    fi
    
    # Characters endpoint (GET)
    test_start "Endpoint /characters (GET)"
    local status_code=$(curl -s -o /dev/null -w "%{http_code}" "$base_url/characters")
    if [[ $status_code -eq 200 ]] || [[ $status_code -eq 404 ]]; then
        success "Endpoint /characters (GET) acessível (status: $status_code)"
    else
        fail "Endpoint /characters (GET) com erro (status: $status_code)"
    fi
    
    # Docs endpoint
    test_start "Endpoint /docs"
    local status_code=$(curl -s -o /dev/null -w "%{http_code}" "$base_url/docs")
    if [[ $status_code -eq 200 ]]; then
        success "Endpoint /docs acessível"
    else
        fail "Endpoint /docs com erro (status: $status_code)"
    fi
}

# =============================================================================
# VERIFICAÇÕES DO BANCO DE DADOS
# =============================================================================

check_database() {
    log "=== VERIFICAÇÕES DO BANCO DE DADOS ==="
    
    if [[ -z "${DB_USER:-}" ]] || [[ -z "${DB_NAME:-}" ]]; then
        fail "Variáveis do banco não definidas"
        return 1
    fi
    
    # Conexão com o banco
    test_start "Conexão com banco de dados"
    if sudo docker-compose exec postgres psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" &> /dev/null; then
        success "Conexão com banco OK"
    else
        fail "Falha na conexão com banco"
        return 1
    fi
    
    # Verificar tabelas
    test_start "Tabelas do banco"
    local table_count=$(sudo docker-compose exec postgres psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" | tr -d ' \r\n')
    if [[ $table_count -gt 0 ]]; then
        success "Banco possui $table_count tabelas"
    else
        warning "Banco não possui tabelas ou não foi inicializado"
    fi
    
    # Verificar índices
    test_start "Índices do banco"
    local index_count=$(sudo docker-compose exec postgres psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM pg_indexes WHERE schemaname = 'public';" | tr -d ' \r\n')
    if [[ $index_count -gt 0 ]]; then
        success "Banco possui $index_count índices"
    else
        warning "Banco não possui índices customizados"
    fi
    
    # Tamanho do banco
    test_start "Tamanho do banco"
    local db_size=$(sudo docker-compose exec postgres psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT pg_size_pretty(pg_database_size('$DB_NAME'));" | tr -d ' \r\n')
    success "Tamanho do banco: $db_size"
}

# =============================================================================
# VERIFICAÇÕES DE SEGURANÇA
# =============================================================================

check_security() {
    log "=== VERIFICAÇÕES DE SEGURANÇA ==="
    
    # Firewall UFW
    test_start "Firewall UFW"
    if command -v ufw &> /dev/null; then
        local ufw_status=$(sudo ufw status | head -1 | awk '{print $2}')
        if [[ "$ufw_status" == "active" ]]; then
            success "Firewall UFW ativo"
        else
            warning "Firewall UFW inativo"
        fi
    else
        warning "UFW não está instalado"
    fi
    
    # Fail2ban
    test_start "Fail2ban"
    if systemctl is-active --quiet fail2ban; then
        success "Fail2ban ativo"
    else
        warning "Fail2ban não está ativo"
    fi
    
    # Permissões de arquivos
    test_start "Permissões do .env"
    if [[ -f ".env" ]]; then
        local env_perms=$(stat -c "%a" .env)
        if [[ "$env_perms" == "600" ]] || [[ "$env_perms" == "644" ]]; then
            success "Permissões do .env OK: $env_perms"
        else
            warning "Permissões do .env podem ser inseguras: $env_perms"
        fi
    fi
    
    # Verificar portas expostas
    test_start "Portas expostas"
    local exposed_ports=$(sudo netstat -tuln | grep LISTEN | wc -l)
    if [[ $exposed_ports -lt 20 ]]; then
        success "Número de portas expostas razoável: $exposed_ports"
    else
        warning "Muitas portas expostas: $exposed_ports"
    fi
}

# =============================================================================
# VERIFICAÇÕES DE PERFORMANCE
# =============================================================================

check_performance() {
    log "=== VERIFICAÇÕES DE PERFORMANCE ==="
    
    # Tempo de resposta da API
    test_start "Tempo de resposta da API"
    local response_time=$(curl -o /dev/null -s -w "%{time_total}" http://localhost:8000/health)
    if (( $(echo "$response_time < 2.0" | bc -l) )); then
        success "Tempo de resposta da API OK: ${response_time}s"
    else
        warning "Tempo de resposta da API lento: ${response_time}s"
    fi
    
    # Uso de CPU dos containers
    test_start "Uso de CPU dos containers"
    local high_cpu_containers=$(sudo docker stats --no-stream --format "{{.CPUPerc}}" | sed 's/%//' | awk '$1 > 80 {count++} END {print count+0}')
    if [[ $high_cpu_containers -eq 0 ]]; then
        success "Uso de CPU dos containers OK"
    else
        warning "$high_cpu_containers containers com alto uso de CPU"
    fi
    
    # Uso de memória dos containers
    test_start "Uso de memória dos containers"
    local memory_stats=$(sudo docker stats --no-stream --format "{{.Name}}: {{.MemUsage}}")
    success "Estatísticas de memória coletadas"
    info "Detalhes: $memory_stats"
    
    # Cache Redis
    test_start "Performance do Redis"
    local redis_keys=$(sudo docker-compose exec redis redis-cli DBSIZE | tr -d '\r')
    local redis_memory=$(sudo docker-compose exec redis redis-cli INFO memory | grep "used_memory_human" | cut -d: -f2 | tr -d '\r')
    success "Redis: $redis_keys chaves, $redis_memory de memória"
}

# =============================================================================
# RELATÓRIO FINAL
# =============================================================================

generate_report() {
    log "=== RELATÓRIO FINAL ==="
    
    local success_rate=$((TESTS_PASSED * 100 / TESTS_TOTAL))
    
    info "Total de testes: $TESTS_TOTAL"
    info "Testes aprovados: $TESTS_PASSED"
    info "Testes falharam: $TESTS_FAILED"
    info "Taxa de sucesso: $success_rate%"
    
    echo
    if [[ $TESTS_FAILED -eq 0 ]]; then
        success "✅ SISTEMA COMPLETAMENTE SAUDÁVEL!"
    elif [[ $TESTS_FAILED -le 2 ]]; then
        warning "⚠️  SISTEMA FUNCIONAL COM ALERTAS MENORES"
    else
        error "❌ SISTEMA COM PROBLEMAS CRÍTICOS"
    fi
    
    echo
    info "Log completo salvo em: $LOG_FILE"
    info "Para verificar logs dos serviços: sudo docker-compose logs"
    info "Para verificar status: sudo docker-compose ps"
}

# =============================================================================
# FUNÇÃO PRINCIPAL
# =============================================================================

main() {
    log "=== INICIANDO VERIFICAÇÃO DE SAÚDE DO SISTEMA ==="
    
    # Criar diretório de log
    sudo mkdir -p "$(dirname "$LOG_FILE")"
    
    check_system_basics
    check_requirements
    check_project
    check_containers
    check_connectivity
    check_api_endpoints
    check_database
    check_security
    check_performance
    generate_report
    
    log "=== VERIFICAÇÃO CONCLUÍDA ==="
    
    # Retornar código de saída baseado no resultado
    if [[ $TESTS_FAILED -eq 0 ]]; then
        exit 0
    elif [[ $TESTS_FAILED -le 2 ]]; then
        exit 1
    else
        exit 2
    fi
}

# =============================================================================
# EXECUÇÃO
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 