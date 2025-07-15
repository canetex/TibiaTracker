#!/bin/bash

# =============================================================================
# SCRIPT PARA ADIÇÃO EM MASSA DE PERSONAGENS DO RUBINOT
# =============================================================================
# Este script adiciona todos os personagens do arquivo Rubinot.csv
# IMPORTANTE: Execute apenas uma vez para evitar duplicatas
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
API_URL="http://localhost:8000"
LOG_FILE="/var/log/tibia-tracker/bulk-add-rubinot.log"
CSV_FILE="$PROJECT_DIR/Scripts/InitialLoad/Rubinot.csv"

# Funções de log
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

# Função para testar endpoint específico com detalhes
test_endpoint() {
    local endpoint="$1"
    local method="${2:-GET}"
    local data="${3:-}"
    
    log "🔍 Testando endpoint: $method $endpoint"
    
    if [[ -n "$data" ]]; then
        response=$(curl -s -w "%{http_code}" -o /tmp/response.json \
            -X "$method" "$endpoint" \
            -H "Content-Type: application/x-www-form-urlencoded" \
            -d "$data" 2>/dev/null)
    else
        response=$(curl -s -w "%{http_code}" -o /tmp/response.json \
            -X "$method" "$endpoint" 2>/dev/null)
    fi
    
    http_code="${response: -3}"
    response_body=$(cat /tmp/response.json 2>/dev/null || echo "{}")
    
    if [[ "$http_code" == "200" ]] || [[ "$http_code" == "201" ]]; then
        log "✅ $method $endpoint - OK (HTTP $http_code)"
        return 0
    else
        error "❌ $method $endpoint - FALHOU (HTTP $http_code): $response_body"
        return 1
    fi
}

# Função para testar conectividade com a API
test_api_connectivity() {
    log "🔍 Testando conectividade com a API..."
    
    # Testar endpoint de health
    if ! test_endpoint "$API_URL/health/"; then
        error "❌ API não está respondendo em $API_URL/health/"
        return 1
    fi
    
    # Testar endpoint de personagens com prefixo correto
    if ! test_endpoint "$API_URL/api/v1/characters/stats/global"; then
        error "❌ Endpoint de personagens não está respondendo"
        return 1
    fi
    
    # Testar endpoint específico de scrape-with-history para Rubinot
    log "🔍 Testando endpoint scrape-with-history para Rubinot..."
    if ! test_endpoint "$API_URL/api/v1/characters/scrape-with-history?server=rubinot&world=auroria&character_name=test" "POST"; then
        warning "⚠️ Endpoint scrape-with-history retornou erro, mas pode ser normal para personagem de teste"
        # Não falhar aqui, pois pode ser que o personagem 'test' não exista
    fi
    
    log "✅ Conectividade básica com a API OK"
    return 0
}

# Função para adicionar um personagem do Rubinot
add_rubinot_character() {
    local world="$1"
    local name="$2"
    
    # Remover espaços extras e caracteres especiais do nome
    name=$(echo "$name" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr -d '\r')
    world=$(echo "$world" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr -d '\r')
    
    # Pular linhas vazias
    if [[ -z "$name" ]] || [[ -z "$world" ]]; then
        return 0
    fi
    
    log "🔄 Adicionando: $name ($world)"
    
    # Montar query string para Rubinot
    local url="$API_URL/api/v1/characters/scrape-with-history?server=$(printf '%s' "rubinot" | jq -sRr @uri)&world=$(printf '%s' "$world" | jq -sRr @uri)&character_name=$(printf '%s' "$name" | jq -sRr @uri)"
    
    # Fazer a requisição para a API
    response=$(curl -s -w "%{http_code}" -o /tmp/response.json \
        -X POST "$url" 2>/dev/null)
    
    http_code="${response: -3}"
    response_body=$(cat /tmp/response.json 2>/dev/null || echo "{}")
    
    if [[ "$http_code" == "200" ]] || [[ "$http_code" == "201" ]]; then
        log "✅ $name ($world) adicionado com sucesso"
        return 0
    elif [[ "$http_code" == "422" ]]; then
        # Personagem já existe ou erro de scraping
        log "⚠️ $name ($world) já existe ou erro de scraping: $response_body"
        return 0  # Não é um erro crítico
    else
        error "❌ Erro ao adicionar $name ($world) (HTTP $http_code): $response_body"
        return 1
    fi
}

# Função para processar o arquivo CSV
process_csv() {
    local csv_file="$1"
    
    # Verificar se o arquivo existe
    if [[ ! -f "$csv_file" ]]; then
        error "❌ Arquivo CSV não encontrado: $csv_file"
        exit 1
    fi
    
    # Contar linhas no arquivo (excluindo cabeçalho)
    local total_lines=$(wc -l < "$csv_file")
    local data_lines=$((total_lines - 1))
    
    log "📊 Arquivo CSV encontrado: $csv_file"
    log "📊 Total de linhas: $total_lines (dados: $data_lines)"
    
    # Contadores por mundo
    declare -A world_counts
    declare -A world_success
    declare -A world_errors
    
    # Inicializar contadores para todos os mundos do Rubinot
    local worlds=("Auroria" "Belaria" "Elysian" "Bellum" "Harmonian" "Vesperia" "Spectrum" "Kalarian" "Lunarian" "Solarian")
    for world in "${worlds[@]}"; do
        world_counts["$world"]=0
        world_success["$world"]=0
        world_errors["$world"]=0
    done
    
    # Contadores gerais
    local total_processed=0
    local total_success=0
    local total_errors=0
    
    # Processar cada linha do CSV (pular cabeçalho)
    log "📋 Processando personagens do Rubinot..."
    
    # Usar tail para pular a primeira linha (cabeçalho)
    tail -n +2 "$csv_file" | while IFS=';' read -r world name rest; do
        total_processed=$((total_processed + 1))
        world_counts["$world"]=$((world_counts["$world"] + 1))
        
        # Mostrar progresso a cada 50 personagens
        if [[ $((total_processed % 50)) -eq 0 ]]; then
            log "📈 Progresso: $total_processed/$data_lines personagens processados"
        fi
        
        # Mostrar progresso por mundo a cada 100 personagens
        if [[ $((total_processed % 100)) -eq 0 ]]; then
            log "📊 Progresso por mundo:"
            for w in "${worlds[@]}"; do
                if [[ ${world_counts["$w"]} -gt 0 ]]; then
                    log "   - $w: ${world_counts["$w"]} processados"
                fi
            done
        fi
        
        if add_rubinot_character "$world" "$name"; then
            world_success["$world"]=$((world_success["$world"] + 1))
            total_success=$((total_success + 1))
        else
            world_errors["$world"]=$((world_errors["$world"] + 1))
            total_errors=$((total_errors + 1))
        fi
        
        # Delay para não sobrecarregar a API (delay menor para Rubinot)
        sleep 1
        
    done
    
    # Resumo final por mundo
    log "=== RESUMO FINAL POR MUNDO ==="
    for world in "${worlds[@]}"; do
        if [[ ${world_counts["$world"]} -gt 0 ]]; then
            local success_rate=0
            if [[ ${world_counts["$world"]} -gt 0 ]]; then
                success_rate=$(( (${world_success["$world"]} * 100) / ${world_counts["$world"]} ))
            fi
            log "📊 $world: ${world_success["$world"]} sucessos, ${world_errors["$world"]} erros (${world_counts["$world"]} total, ${success_rate}% sucesso)"
        fi
    done
    
    # Resumo geral
    log "=== RESUMO GERAL ==="
    log "📊 Total processado: $total_processed"
    log "📊 Total de sucessos: $total_success"
    log "📊 Total de erros: $total_errors"
    if [[ $total_processed -gt 0 ]]; then
        local overall_success_rate=$(( (total_success * 100) / total_processed ))
        log "📊 Taxa de sucesso geral: ${overall_success_rate}%"
    fi
}

# Função principal
main() {
    log "=== INICIANDO ADIÇÃO EM MASSA DE PERSONAGENS DO RUBINOT ==="
    
    # Mostrar informações do sistema
    log "📊 Informações do sistema:"
    log "   - Data/Hora: $(date)"
    log "   - Diretório: $PROJECT_DIR"
    log "   - API URL: $API_URL"
    log "   - Log file: $LOG_FILE"
    log "   - CSV file: $CSV_FILE"
    
    # Testar conectividade
    if ! test_api_connectivity; then
        error "❌ Falha na conectividade com a API. Verifique se o backend está rodando."
        error "Execute: docker-compose restart backend"
        exit 1
    fi
    
    # Verificar se o arquivo CSV existe
    if [[ ! -f "$CSV_FILE" ]]; then
        error "❌ Arquivo CSV não encontrado: $CSV_FILE"
        error "Certifique-se de que o arquivo Rubinot.csv está em Scripts/InitialLoad/"
        exit 1
    fi
    
    # Criar diretório de log se não existir
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Processar o arquivo CSV
    process_csv "$CSV_FILE"
    
    # Limpar arquivo temporário
    rm -f /tmp/response.json
    
    log "=== ADIÇÃO EM MASSA DO RUBINOT CONCLUÍDA ==="
    log "📄 Log completo salvo em: $LOG_FILE"
}

# Executar função principal
main "$@" 