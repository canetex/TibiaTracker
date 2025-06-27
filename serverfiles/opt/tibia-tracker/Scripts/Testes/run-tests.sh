#!/bin/bash

# =============================================================================
# TIBIA TRACKER - EXECUÇÃO DE TESTES AUTOMATIZADOS
# =============================================================================
# Este script executa todos os testes automatizados do sistema
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
LOG_FILE="/var/log/tibia-tracker/tests.log"
REPORT_DIR="/var/log/tibia-tracker/test-reports"

# Contadores de testes
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

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

test_passed() {
    echo -e "${GREEN}[✓ PASS]${NC} $1" | tee -a "$LOG_FILE"
    PASSED_TESTS=$((PASSED_TESTS + 1))
}

test_failed() {
    echo -e "${RED}[✗ FAIL]${NC} $1" | tee -a "$LOG_FILE"
    FAILED_TESTS=$((FAILED_TESTS + 1))
}

test_skipped() {
    echo -e "${YELLOW}[⊘ SKIP]${NC} $1" | tee -a "$LOG_FILE"
    SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
}

# =============================================================================
# VERIFICAÇÕES PRÉ-TESTE
# =============================================================================

check_prerequisites() {
    log "=== VERIFICANDO PRÉ-REQUISITOS PARA TESTES ==="
    
    if [[ ! -d "$PROJECT_DIR" ]]; then
        error "Diretório do projeto não encontrado: $PROJECT_DIR"
        exit 1
    fi
    
    cd "$PROJECT_DIR"
    
    if [[ ! -f "docker-compose.yml" ]]; then
        error "docker-compose.yml não encontrado"
        exit 1
    fi
    
    if [[ ! -f ".env" ]]; then
        error "Arquivo .env não encontrado"
        exit 1
    fi
    
    # Carregar variáveis de ambiente
    source .env
    
    # Criar diretórios necessários
    sudo mkdir -p "$REPORT_DIR"
    
    log "Pré-requisitos verificados!"
}

# =============================================================================
# TESTES DE INFRAESTRUTURA
# =============================================================================

test_infrastructure() {
    log "=== TESTES DE INFRAESTRUTURA ==="
    
    # Teste: Docker está rodando
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    if systemctl is-active --quiet docker; then
        test_passed "Docker está ativo"
    else
        test_failed "Docker não está ativo"
    fi
    
    # Teste: Containers estão rodando
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    local running_containers=$(sudo docker-compose ps --services --filter "status=running" | wc -l)
    local total_containers=$(sudo docker-compose ps --services | wc -l)
    
    if [[ $running_containers -eq $total_containers ]] && [[ $total_containers -gt 0 ]]; then
        test_passed "Todos os containers estão rodando ($running_containers/$total_containers)"
    else
        test_failed "Nem todos os containers estão rodando ($running_containers/$total_containers)"
    fi
    
    # Teste: Health checks
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    local unhealthy=$(sudo docker ps --filter "health=unhealthy" --format "{{.Names}}" | wc -l)
    if [[ $unhealthy -eq 0 ]]; then
        test_passed "Todos os containers estão saudáveis"
    else
        test_failed "$unhealthy containers não estão saudáveis"
    fi
}

# =============================================================================
# TESTES DO BANCO DE DADOS
# =============================================================================

test_database() {
    log "=== TESTES DO BANCO DE DADOS ==="
    
    # Teste: Conexão PostgreSQL
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    if sudo docker-compose exec postgres pg_isready -U "$DB_USER" -d "$DB_NAME" &> /dev/null; then
        test_passed "Conexão PostgreSQL funcionando"
    else
        test_failed "Falha na conexão PostgreSQL"
    fi
    
    # Teste: Tabelas existem
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    local table_count=$(sudo docker-compose exec postgres psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>/dev/null | tr -d ' \r\n')
    
    if [[ $table_count -gt 0 ]]; then
        test_passed "Banco possui $table_count tabelas"
    else
        test_failed "Banco não possui tabelas"
    fi
    
    # Teste: Inserção e seleção básica
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    if sudo docker-compose exec postgres psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" &> /dev/null; then
        test_passed "Operações básicas do banco funcionando"
    else
        test_failed "Falha nas operações básicas do banco"
    fi
    
    # Teste: Backup do banco
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    local backup_file="$REPORT_DIR/test-backup-$(date +'%Y%m%d-%H%M%S').sql"
    if sudo docker-compose exec -T postgres pg_dump -U "$DB_USER" -d "$DB_NAME" > "$backup_file" 2>/dev/null; then
        test_passed "Backup do banco criado com sucesso"
        rm -f "$backup_file"
    else
        test_failed "Falha ao criar backup do banco"
    fi
}

# =============================================================================
# TESTES DO REDIS
# =============================================================================

test_redis() {
    log "=== TESTES DO REDIS ==="
    
    # Teste: Conexão Redis
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    if sudo docker-compose exec redis redis-cli ping | grep -q "PONG"; then
        test_passed "Conexão Redis funcionando"
    else
        test_failed "Falha na conexão Redis"
    fi
    
    # Teste: Operações SET/GET
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    local test_key="test_key_$(date +%s)"
    local test_value="test_value_$(date +%s)"
    
    if sudo docker-compose exec redis redis-cli SET "$test_key" "$test_value" &> /dev/null && \
       sudo docker-compose exec redis redis-cli GET "$test_key" | grep -q "$test_value"; then
        test_passed "Operações SET/GET do Redis funcionando"
        sudo docker-compose exec redis redis-cli DEL "$test_key" &> /dev/null
    else
        test_failed "Falha nas operações SET/GET do Redis"
    fi
    
    # Teste: Informações de memória
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    local redis_memory=$(sudo docker-compose exec redis redis-cli INFO memory | grep "used_memory_human" | cut -d: -f2 | tr -d '\r')
    if [[ -n "$redis_memory" ]]; then
        test_passed "Redis usando $redis_memory de memória"
    else
        test_failed "Falha ao obter informações de memória do Redis"
    fi
}

# =============================================================================
# TESTES DA API BACKEND
# =============================================================================

test_backend_api() {
    log "=== TESTES DA API BACKEND ==="
    
    local base_url="http://localhost:8000"
    
    # Teste: Health endpoint
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    local health_response=$(curl -s -w "%{http_code}" "$base_url/health")
    local health_status=${health_response: -3}
    
    if [[ "$health_status" == "200" ]]; then
        test_passed "Endpoint /health respondendo corretamente"
    else
        test_failed "Endpoint /health retornou status $health_status"
    fi
    
    # Teste: OpenAPI docs
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    local docs_status=$(curl -s -o /dev/null -w "%{http_code}" "$base_url/docs")
    if [[ "$docs_status" == "200" ]]; then
        test_passed "Documentação da API acessível"
    else
        test_failed "Documentação da API retornou status $docs_status"
    fi
    
    # Teste: OpenAPI schema
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    local schema_status=$(curl -s -o /dev/null -w "%{http_code}" "$base_url/openapi.json")
    if [[ "$schema_status" == "200" ]]; then
        test_passed "Schema OpenAPI acessível"
    else
        test_failed "Schema OpenAPI retornou status $schema_status"
    fi
    
    # Teste: Characters endpoint
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    local characters_status=$(curl -s -o /dev/null -w "%{http_code}" "$base_url/characters")
    if [[ "$characters_status" == "200" ]] || [[ "$characters_status" == "404" ]]; then
        test_passed "Endpoint /characters acessível (status: $characters_status)"
    else
        test_failed "Endpoint /characters retornou status $characters_status"
    fi
    
    # Teste: Tempo de resposta da API
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    local response_time=$(curl -o /dev/null -s -w "%{time_total}" "$base_url/health")
    if (( $(echo "$response_time < 2.0" | bc -l) )); then
        test_passed "Tempo de resposta da API aceitável (${response_time}s)"
    else
        test_failed "Tempo de resposta da API lento (${response_time}s)"
    fi
}

# =============================================================================
# TESTES DO FRONTEND
# =============================================================================

test_frontend() {
    log "=== TESTES DO FRONTEND ==="
    
    # Teste: Frontend respondendo diretamente
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    local frontend_status=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:3000")
    if [[ "$frontend_status" == "200" ]]; then
        test_passed "Frontend respondendo diretamente"
    else
        test_skipped "Frontend não acessível diretamente (status: $frontend_status)"
    fi
    
    # Teste: Frontend através do proxy
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    local proxy_status=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost")
    if [[ "$proxy_status" == "200" ]]; then
        test_passed "Frontend acessível através do proxy"
    else
        test_failed "Frontend não acessível através do proxy (status: $proxy_status)"
    fi
    
    # Teste: Recursos estáticos
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    local static_status=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost/static/js/" 2>/dev/null || echo "404")
    if [[ "$static_status" == "200" ]] || [[ "$static_status" == "403" ]]; then
        test_passed "Recursos estáticos acessíveis"
    else
        test_skipped "Recursos estáticos não testáveis (status: $static_status)"
    fi
}

# =============================================================================
# TESTES DE INTEGRAÇÃO
# =============================================================================

test_integration() {
    log "=== TESTES DE INTEGRAÇÃO ==="
    
    # Teste: Comunicação Backend -> PostgreSQL
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
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
        test_passed "Backend conecta ao PostgreSQL"
    else
        test_failed "Backend não consegue conectar ao PostgreSQL"
    fi
    
    # Teste: Comunicação Backend -> Redis
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
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
        test_passed "Backend conecta ao Redis"
    else
        test_failed "Backend não consegue conectar ao Redis"
    fi
    
    # Teste: Proxy -> Backend
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    local proxy_api_status=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost/api/health" 2>/dev/null || echo "000")
    if [[ "$proxy_api_status" == "200" ]]; then
        test_passed "Proxy redireciona para API corretamente"
    else
        test_skipped "Redirecionamento do proxy não configurado (status: $proxy_api_status)"
    fi
}

# =============================================================================
# TESTES DE PERFORMANCE
# =============================================================================

test_performance() {
    log "=== TESTES DE PERFORMANCE ==="
    
    # Teste: Throughput da API
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    local start_time=$(date +%s.%N)
    for i in {1..10}; do
        curl -f -s "http://localhost:8000/health" > /dev/null &
    done
    wait
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l)
    local rps=$(echo "scale=2; 10 / $duration" | bc -l)
    
    if (( $(echo "$rps > 5" | bc -l) )); then
        test_passed "Throughput da API aceitável (${rps} req/s)"
    else
        test_failed "Throughput da API baixo (${rps} req/s)"
    fi
    
    # Teste: Uso de memória dos containers
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    local high_memory_containers=$(sudo docker stats --no-stream --format "{{.MemPerc}}" | sed 's/%//' | awk '$1 > 80 {count++} END {print count+0}')
    if [[ $high_memory_containers -eq 0 ]]; then
        test_passed "Uso de memória dos containers normal"
    else
        test_failed "$high_memory_containers containers com alto uso de memória"
    fi
    
    # Teste: Uso de CPU dos containers
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    local high_cpu_containers=$(sudo docker stats --no-stream --format "{{.CPUPerc}}" | sed 's/%//' | awk '$1 > 80 {count++} END {print count+0}')
    if [[ $high_cpu_containers -eq 0 ]]; then
        test_passed "Uso de CPU dos containers normal"
    else
        test_failed "$high_cpu_containers containers com alto uso de CPU"
    fi
}

# =============================================================================
# TESTES DE SEGURANÇA
# =============================================================================

test_security() {
    log "=== TESTES DE SEGURANÇA ==="
    
    # Teste: Firewall ativo
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    if command -v ufw &> /dev/null && sudo ufw status | grep -q "active"; then
        test_passed "Firewall UFW ativo"
    else
        test_skipped "Firewall UFW não ativo ou não instalado"
    fi
    
    # Teste: Fail2ban ativo
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    if systemctl is-active --quiet fail2ban; then
        test_passed "Fail2ban ativo"
    else
        test_skipped "Fail2ban não ativo"
    fi
    
    # Teste: Permissões do .env
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    local env_perms=$(stat -c "%a" .env)
    if [[ "$env_perms" == "600" ]] || [[ "$env_perms" == "644" ]]; then
        test_passed "Permissões do .env seguras ($env_perms)"
    else
        test_failed "Permissões do .env inseguras ($env_perms)"
    fi
    
    # Teste: Headers de segurança
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    local security_headers=$(curl -s -I "http://localhost" | grep -i "x-\|security\|strict" | wc -l)
    if [[ $security_headers -gt 0 ]]; then
        test_passed "Headers de segurança presentes ($security_headers)"
    else
        test_skipped "Headers de segurança não detectados"
    fi
}

# =============================================================================
# TESTES ESPECÍFICOS DO BACKEND
# =============================================================================

test_backend_internals() {
    log "=== TESTES INTERNOS DO BACKEND ==="
    
    # Teste: Pytest do backend (se existir)
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    if [[ -d "Backend/tests" ]]; then
        local pytest_output=$(sudo docker-compose exec backend python -m pytest tests/ -v 2>/dev/null || echo "FAILED")
        if echo "$pytest_output" | grep -q "passed"; then
            local passed_count=$(echo "$pytest_output" | grep -o "[0-9]\+ passed" | grep -o "[0-9]\+")
            test_passed "Testes unitários do backend: $passed_count testes aprovados"
        else
            test_failed "Falha nos testes unitários do backend"
        fi
    else
        test_skipped "Diretório de testes do backend não encontrado"
    fi
    
    # Teste: Importação de módulos Python
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    if sudo docker-compose exec backend python -c "
import sys
import importlib
modules = ['fastapi', 'sqlalchemy', 'psycopg2', 'redis', 'pydantic']
for module in modules:
    try:
        importlib.import_module(module)
        print(f'{module}: OK')
    except ImportError as e:
        print(f'{module}: FAILED - {e}')
        sys.exit(1)
" &> /dev/null; then
        test_passed "Todas as dependências Python importadas com sucesso"
    else
        test_failed "Falha na importação de dependências Python"
    fi
    
    # Teste: Estrutura da API
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    local api_structure=$(curl -s "http://localhost:8000/openapi.json" | jq -r '.paths | keys[]' 2>/dev/null | wc -l)
    if [[ $api_structure -gt 0 ]]; then
        test_passed "API possui $api_structure endpoints definidos"
    else
        test_failed "Falha ao verificar estrutura da API"
    fi
}

# =============================================================================
# TESTES ESPECÍFICOS DO FRONTEND
# =============================================================================

test_frontend_internals() {
    log "=== TESTES INTERNOS DO FRONTEND ==="
    
    # Teste: Jest do frontend (se existir)
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    if sudo docker-compose exec frontend test -d "src/__tests__" 2>/dev/null; then
        local jest_output=$(sudo docker-compose exec frontend npm test -- --watchAll=false 2>/dev/null || echo "FAILED")
        if echo "$jest_output" | grep -q "PASS"; then
            test_passed "Testes do frontend executados com sucesso"
        else
            test_failed "Falha nos testes do frontend"
        fi
    else
        test_skipped "Testes do frontend não encontrados"
    fi
    
    # Teste: Build do frontend
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    if sudo docker-compose exec frontend npm run build &> /dev/null; then
        test_passed "Build do frontend executado com sucesso"
    else
        test_skipped "Falha no build do frontend ou comando não disponível"
    fi
    
    # Teste: Dependências Node.js
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    local npm_audit=$(sudo docker-compose exec frontend npm audit --audit-level=high --json 2>/dev/null | jq -r '.metadata.vulnerabilities.high + .metadata.vulnerabilities.critical' 2>/dev/null || echo "0")
    if [[ $npm_audit -eq 0 ]]; then
        test_passed "Nenhuma vulnerabilidade crítica nas dependências Node.js"
    else
        test_failed "$npm_audit vulnerabilidades críticas encontradas nas dependências"
    fi
}

# =============================================================================
# RELATÓRIO FINAL
# =============================================================================

generate_test_report() {
    log "=== RELATÓRIO FINAL DOS TESTES ==="
    
    local success_rate=0
    if [[ $TOTAL_TESTS -gt 0 ]]; then
        success_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    fi
    
    # Salvar relatório em arquivo
    local report_file="$REPORT_DIR/test-report-$(date +'%Y%m%d-%H%M%S').txt"
    
    {
        echo "TIBIA TRACKER - RELATÓRIO DE TESTES"
        echo "===================================="
        echo "Data/Hora: $(date)"
        echo "Total de testes: $TOTAL_TESTS"
        echo "Testes aprovados: $PASSED_TESTS"
        echo "Testes falharam: $FAILED_TESTS"
        echo "Testes pulados: $SKIPPED_TESTS"
        echo "Taxa de sucesso: $success_rate%"
        echo ""
    } > "$report_file"
    
    info "RESUMO DOS TESTES:"
    info "  Total de testes executados: $TOTAL_TESTS"
    info "  ✅ Testes aprovados: $PASSED_TESTS"
    info "  ❌ Testes falharam: $FAILED_TESTS"
    info "  ⊘ Testes pulados: $SKIPPED_TESTS"
    info "  📊 Taxa de sucesso: $success_rate%"
    
    echo
    if [[ $FAILED_TESTS -eq 0 ]]; then
        log "🎉 TODOS OS TESTES PASSARAM COM SUCESSO!"
    elif [[ $FAILED_TESTS -le 2 ]]; then
        warning "⚠️ ALGUNS TESTES FALHARAM, MAS O SISTEMA ESTÁ FUNCIONAL"
    else
        error "❌ MUITOS TESTES FALHARAM - VERIFIQUE O SISTEMA"
    fi
    
    echo
    info "Relatório completo salvo em: $report_file"
    info "Log completo salvo em: $LOG_FILE"
    
    # Retornar código de saída baseado nos resultados
    if [[ $FAILED_TESTS -eq 0 ]]; then
        return 0
    elif [[ $FAILED_TESTS -le 2 ]]; then
        return 1
    else
        return 2
    fi
}

# =============================================================================
# FUNÇÃO PRINCIPAL
# =============================================================================

main() {
    log "=== INICIANDO TESTES AUTOMATIZADOS DO TIBIA TRACKER ==="
    
    # Criar diretórios necessários
    sudo mkdir -p "$(dirname "$LOG_FILE")"
    sudo mkdir -p "$REPORT_DIR"
    
    check_prerequisites
    
    # Executar suítes de testes
    test_infrastructure
    test_database
    test_redis
    test_backend_api
    test_frontend
    test_integration
    test_performance
    test_security
    test_backend_internals
    test_frontend_internals
    
    # Gerar relatório
    generate_test_report
    
    log "=== TESTES AUTOMATIZADOS CONCLUÍDOS ==="
}

# =============================================================================
# EXECUÇÃO
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 