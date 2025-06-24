#!/bin/bash

# =============================================================================
# TIBIA TRACKER - TESTE DE CONECTIVIDADE DE REDE
# =============================================================================
# Este script testa conectividade de rede, portas e comunicação entre serviços
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
LOG_FILE="/var/log/tibia-tracker/network-test.log"

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
}

fail() {
    echo -e "${RED}[✗]${NC} $1" | tee -a "$LOG_FILE"
}

# =============================================================================
# VERIFICAÇÕES PRÉ-EXECUÇÃO
# =============================================================================

check_prerequisites() {
    log "Verificando pré-requisitos..."
    
    if [[ ! -d "$PROJECT_DIR" ]]; then
        error "Diretório do projeto não encontrado: $PROJECT_DIR"
        exit 1
    fi
    
    cd "$PROJECT_DIR"
    
    if [[ -f ".env" ]]; then
        source .env
    else
        warning "Arquivo .env não encontrado, usando configurações padrão"
    fi
    
    # Verificar ferramentas necessárias
    local tools=("curl" "nc" "nmap" "dig")
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            warning "$tool não está instalado, alguns testes podem falhar"
        fi
    done
    
    log "Pré-requisitos verificados!"
}

# =============================================================================
# TESTE DE CONECTIVIDADE EXTERNA
# =============================================================================

test_external_connectivity() {
    log "=== TESTANDO CONECTIVIDADE EXTERNA ==="
    
    # Teste básico de internet
    info "Testando conectividade com a internet..."
    if ping -c 3 -W 5 8.8.8.8 &> /dev/null; then
        success "Conectividade com internet OK (8.8.8.8)"
    else
        fail "Sem conectividade com internet"
    fi
    
    # Teste DNS
    info "Testando resolução DNS..."
    if nslookup google.com &> /dev/null; then
        success "Resolução DNS funcionando"
    else
        fail "Problemas na resolução DNS"
    fi
    
    # Teste HTTPS
    info "Testando conectividade HTTPS..."
    if curl -f -s -m 10 https://www.google.com > /dev/null; then
        success "Conectividade HTTPS OK"
    else
        fail "Problemas na conectividade HTTPS"
    fi
    
    # Teste dos servidores Taleon
    info "Testando conectividade com servidores Taleon..."
    local taleon_servers=("san.taleon.online" "aura.taleon.online" "gaia.taleon.online")
    
    for server in "${taleon_servers[@]}"; do
        if curl -f -s -m 10 "https://$server" > /dev/null; then
            success "Servidor $server acessível"
        else
            fail "Servidor $server não acessível"
        fi
    done
}

# =============================================================================
# TESTE DE PORTAS LOCAIS
# =============================================================================

test_local_ports() {
    log "=== TESTANDO PORTAS LOCAIS ==="
    
    # Definir portas a serem testadas
    local ports=(
        "80:HTTP (Caddy)"
        "443:HTTPS (Caddy)"
        "5432:PostgreSQL"
        "6379:Redis"
        "8000:Backend API"
        "3000:Frontend"
        "9090:Prometheus"
        "9100:Node Exporter"
    )
    
    for port_info in "${ports[@]}"; do
        local port=$(echo "$port_info" | cut -d: -f1)
        local description=$(echo "$port_info" | cut -d: -f2)
        
        info "Testando porta $port ($description)..."
        
        if nc -z localhost "$port" 2>/dev/null; then
            success "Porta $port está aberta ($description)"
        else
            warning "Porta $port não está acessível ($description)"
        fi
    done
}

# =============================================================================
# TESTE DE COMUNICAÇÃO ENTRE CONTAINERS
# =============================================================================

test_container_communication() {
    log "=== TESTANDO COMUNICAÇÃO ENTRE CONTAINERS ==="
    
    # Verificar se containers estão rodando
    if ! sudo docker-compose ps | grep -q "Up"; then
        warning "Containers não estão rodando, pulando testes de comunicação"
        return
    fi
    
    # Teste: Backend -> PostgreSQL
    info "Testando comunicação Backend -> PostgreSQL..."
    if sudo docker-compose exec backend python -c "
import psycopg2
import os
try:
    conn = psycopg2.connect(
        host='postgres',
        database=os.getenv('DB_NAME', 'tibia_tracker'),
        user=os.getenv('DB_USER', 'tibia_user'),
        password=os.getenv('DB_PASSWORD', '')
    )
    conn.close()
    print('OK')
except Exception as e:
    print(f'ERRO: {e}')
" 2>/dev/null | grep -q "OK"; then
        success "Backend consegue conectar ao PostgreSQL"
    else
        fail "Backend não consegue conectar ao PostgreSQL"
    fi
    
    # Teste: Backend -> Redis
    info "Testando comunicação Backend -> Redis..."
    if sudo docker-compose exec backend python -c "
import redis
import os
try:
    r = redis.Redis(host='redis', port=6379, password=os.getenv('REDIS_PASSWORD', ''))
    r.ping()
    print('OK')
except Exception as e:
    print(f'ERRO: {e}')
" 2>/dev/null | grep -q "OK"; then
        success "Backend consegue conectar ao Redis"
    else
        fail "Backend não consegue conectar ao Redis"
    fi
    
    # Teste: Frontend -> Backend
    info "Testando comunicação Frontend -> Backend..."
    if sudo docker-compose exec frontend curl -f -s http://backend:8000/health > /dev/null; then
        success "Frontend consegue acessar Backend"
    else
        fail "Frontend não consegue acessar Backend"
    fi
    
    # Teste: Caddy -> Frontend
    info "Testando comunicação Caddy -> Frontend..."
    if sudo docker-compose exec caddy curl -f -s http://frontend:3000 > /dev/null; then
        success "Caddy consegue acessar Frontend"
    else
        fail "Caddy não consegue acessar Frontend"
    fi
    
    # Teste: Caddy -> Backend
    info "Testando comunicação Caddy -> Backend..."
    if sudo docker-compose exec caddy curl -f -s http://backend:8000/health > /dev/null; then
        success "Caddy consegue acessar Backend"
    else
        fail "Caddy não consegue acessar Backend"
    fi
}

# =============================================================================
# TESTE DE LATÊNCIA E PERFORMANCE
# =============================================================================

test_performance() {
    log "=== TESTANDO LATÊNCIA E PERFORMANCE ==="
    
    # Teste de latência para API
    info "Testando latência da API..."
    local api_times=()
    for i in {1..5}; do
        local time=$(curl -o /dev/null -s -w "%{time_total}" http://localhost:8000/health 2>/dev/null)
        api_times+=("$time")
    done
    
    # Calcular média de latência
    local total=0
    for time in "${api_times[@]}"; do
        total=$(echo "$total + $time" | bc -l)
    done
    local avg=$(echo "scale=3; $total / ${#api_times[@]}" | bc -l)
    
    if (( $(echo "$avg < 1.0" | bc -l) )); then
        success "Latência média da API: ${avg}s (excelente)"
    elif (( $(echo "$avg < 2.0" | bc -l) )); then
        success "Latência média da API: ${avg}s (boa)"
    else
        warning "Latência média da API: ${avg}s (pode ser melhorada)"
    fi
    
    # Teste de throughput simples
    info "Testando throughput da API..."
    local start_time=$(date +%s.%N)
    for i in {1..10}; do
        curl -f -s http://localhost:8000/health > /dev/null &
    done
    wait
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l)
    local rps=$(echo "scale=2; 10 / $duration" | bc -l)
    
    success "Throughput da API: ${rps} req/s"
    
    # Teste de latência do banco
    info "Testando latência do banco..."
    if sudo docker-compose exec postgres psql -U "${DB_USER:-tibia_user}" -d "${DB_NAME:-tibia_tracker}" -c "SELECT 1;" &> /dev/null; then
        local db_time=$(sudo docker-compose exec postgres time psql -U "${DB_USER:-tibia_user}" -d "${DB_NAME:-tibia_tracker}" -c "SELECT 1;" 2>&1 | grep real | awk '{print $2}')
        success "Latência do banco: ${db_time:-< 0.1s}"
    else
        fail "Não foi possível testar latência do banco"
    fi
}

# =============================================================================
# TESTE DE ROTAS E ENDPOINTS
# =============================================================================

test_api_routes() {
    log "=== TESTANDO ROTAS E ENDPOINTS ==="
    
    local base_url="http://localhost:8000"
    
    # Endpoints básicos
    local endpoints=(
        "/health:GET:200"
        "/docs:GET:200"
        "/openapi.json:GET:200"
        "/characters:GET:200,404"
    )
    
    for endpoint_info in "${endpoints[@]}"; do
        local endpoint=$(echo "$endpoint_info" | cut -d: -f1)
        local method=$(echo "$endpoint_info" | cut -d: -f2)
        local expected_codes=$(echo "$endpoint_info" | cut -d: -f3)
        
        info "Testando $method $endpoint..."
        
        local status_code
        if [[ "$method" == "GET" ]]; then
            status_code=$(curl -s -o /dev/null -w "%{http_code}" "$base_url$endpoint")
        else
            status_code=$(curl -s -o /dev/null -w "%{http_code}" -X "$method" "$base_url$endpoint")
        fi
        
        if echo "$expected_codes" | grep -q "$status_code"; then
            success "$method $endpoint retornou $status_code"
        else
            fail "$method $endpoint retornou $status_code (esperado: $expected_codes)"
        fi
    done
}

# =============================================================================
# TESTE DE PROXY REVERSO
# =============================================================================

test_reverse_proxy() {
    log "=== TESTANDO PROXY REVERSO (CADDY) ==="
    
    # Teste direto ao Caddy
    info "Testando acesso direto ao Caddy..."
    local caddy_response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost)
    if [[ "$caddy_response" == "200" ]]; then
        success "Caddy respondendo na porta 80"
    else
        fail "Caddy não está respondendo corretamente (status: $caddy_response)"
    fi
    
    # Teste redirecionamento para API
    info "Testando redirecionamento para API..."
    local api_via_proxy=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/api/health)
    if [[ "$api_via_proxy" == "200" ]]; then
        success "Proxy redirecionando para API corretamente"
    else
        warning "Proxy pode não estar redirecionando para API (status: $api_via_proxy)"
    fi
    
    # Teste headers de segurança
    info "Testando headers de segurança..."
    local security_headers=$(curl -s -I http://localhost | grep -i "x-\|security\|strict")
    if [[ -n "$security_headers" ]]; then
        success "Headers de segurança presentes"
        info "Headers encontrados: $security_headers"
    else
        warning "Nenhum header de segurança detectado"
    fi
}

# =============================================================================
# RELATÓRIO DE REDE
# =============================================================================

generate_network_report() {
    log "=== RELATÓRIO DE REDE ==="
    
    # Informações de interface de rede
    info "Interfaces de rede:"
    ip addr show | grep -E "inet |mtu" | head -10
    
    # Rotas
    info "Tabela de rotas:"
    ip route show | head -5
    
    # Conexões ativas
    info "Conexões ativas (amostra):"
    netstat -tuln | grep LISTEN | head -10
    
    # Estatísticas Docker
    if command -v docker &> /dev/null; then
        info "Redes Docker:"
        sudo docker network ls
        
        info "Estatísticas de rede dos containers:"
        sudo docker stats --no-stream --format "table {{.Name}}\t{{.NetIO}}" | head -10
    fi
}

# =============================================================================
# FUNÇÃO PRINCIPAL
# =============================================================================

main() {
    log "=== INICIANDO TESTE DE CONECTIVIDADE DE REDE ==="
    
    # Criar diretório de log
    sudo mkdir -p "$(dirname "$LOG_FILE")"
    
    check_prerequisites
    test_external_connectivity
    test_local_ports
    test_container_communication
    test_performance
    test_api_routes
    test_reverse_proxy
    generate_network_report
    
    log "=== TESTE DE REDE CONCLUÍDO ==="
    log "Log completo salvo em: $LOG_FILE"
}

# =============================================================================
# EXECUÇÃO
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 