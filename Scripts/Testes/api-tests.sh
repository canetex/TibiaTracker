#!/bin/bash

# =============================================================================
# TIBIA TRACKER - TESTES ESPECÍFICOS DA API
# =============================================================================
# Este script testa especificamente os endpoints da API
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
LOG_FILE="/var/log/tibia-tracker/api-tests.log"
BASE_URL="http://localhost:8000"

# Contadores
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# =============================================================================
# FUNÇÕES AUXILIARES
# =============================================================================

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

test_passed() {
    echo -e "${GREEN}[✓]${NC} $1" | tee -a "$LOG_FILE"
    PASSED_TESTS=$((PASSED_TESTS + 1))
}

test_failed() {
    echo -e "${RED}[✗]${NC} $1" | tee -a "$LOG_FILE"
    FAILED_TESTS=$((FAILED_TESTS + 1))
}

run_test() {
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    local test_name="$1"
    local url="$2"
    local expected_status="$3"
    local method="${4:-GET}"
    
    log "Testando: $test_name"
    
    local actual_status
    if [[ "$method" == "GET" ]]; then
        actual_status=$(curl -s -o /dev/null -w "%{http_code}" "$url")
    else
        actual_status=$(curl -s -o /dev/null -w "%{http_code}" -X "$method" "$url")
    fi
    
    if echo "$expected_status" | grep -q "$actual_status"; then
        test_passed "$test_name (status: $actual_status)"
    else
        test_failed "$test_name (esperado: $expected_status, obtido: $actual_status)"
    fi
}

# =============================================================================
# TESTES DOS ENDPOINTS
# =============================================================================

test_endpoints() {
    log "=== TESTANDO ENDPOINTS DA API ==="
    
    # Endpoints básicos
    run_test "Health Check" "$BASE_URL/health" "200"
    run_test "Documentação Swagger" "$BASE_URL/docs" "200"
    run_test "Schema OpenAPI" "$BASE_URL/openapi.json" "200"
    run_test "Redirecionamento Root" "$BASE_URL/" "200,307,404"
    
    # Endpoints de personagens
    run_test "Listar Personagens" "$BASE_URL/characters" "200,404"
    run_test "Buscar Personagem (GET)" "$BASE_URL/characters?name=test" "200,404"
    
    # Teste POST (criar personagem) - sem dados
    run_test "Criar Personagem (sem dados)" "$BASE_URL/characters" "422,400" "POST"
}

# =============================================================================
# TESTES DE PERFORMANCE
# =============================================================================

test_performance() {
    log "=== TESTANDO PERFORMANCE DA API ==="
    
    # Teste de latência
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    local response_time=$(curl -o /dev/null -s -w "%{time_total}" "$BASE_URL/health")
    if (( $(echo "$response_time < 2.0" | bc -l) )); then
        test_passed "Latência aceitável: ${response_time}s"
    else
        test_failed "Latência alta: ${response_time}s"
    fi
    
    # Teste de throughput simples
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    local start_time=$(date +%s.%N)
    for i in {1..5}; do
        curl -f -s "$BASE_URL/health" > /dev/null &
    done
    wait
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l)
    local rps=$(echo "scale=2; 5 / $duration" | bc -l)
    
    if (( $(echo "$rps > 3" | bc -l) )); then
        test_passed "Throughput aceitável: ${rps} req/s"
    else
        test_failed "Throughput baixo: ${rps} req/s"
    fi
}

# =============================================================================
# RELATÓRIO
# =============================================================================

generate_report() {
    log "=== RELATÓRIO DOS TESTES DA API ==="
    
    local success_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    
    log "Total de testes: $TOTAL_TESTS"
    log "Aprovados: $PASSED_TESTS"
    log "Falharam: $FAILED_TESTS"
    log "Taxa de sucesso: $success_rate%"
    
    if [[ $FAILED_TESTS -eq 0 ]]; then
        log "🎉 TODOS OS TESTES DA API PASSARAM!"
    else
        log "⚠️ $FAILED_TESTS TESTES FALHARAM"
    fi
}

# =============================================================================
# FUNÇÃO PRINCIPAL
# =============================================================================

main() {
    log "=== INICIANDO TESTES DA API ==="
    
    sudo mkdir -p "$(dirname "$LOG_FILE")"
    
    test_endpoints
    test_performance
    generate_report
    
    log "=== TESTES DA API CONCLUÍDOS ==="
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 