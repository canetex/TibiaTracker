#!/bin/bash

# =============================================================================
# SCRIPT TEMPORÁRIO - ADIÇÃO EM MASSA DE PERSONAGENS (VERSÃO CORRIGIDA V5)
# =============================================================================
# Este script adiciona todos os personagens dos arquivos san.txt e aura.txt
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
LOG_FILE="/var/log/tibia-tracker/bulk-add.log"

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
    
    # Testar endpoint específico de scrape-and-create com prefixo correto e parâmetros na query string
    log "🔍 Testando endpoint scrape-and-create..."
    if ! test_endpoint "$API_URL/api/v1/characters/scrape-and-create?server=taleon&world=san&character_name=test" "POST"; then
        warning "⚠️ Endpoint scrape-and-create retornou erro, mas pode ser normal para personagem de teste"
        # Não falhar aqui, pois pode ser que o personagem 'test' não exista
    fi
    
    log "✅ Conectividade básica com a API OK"
    return 0
}

# Função para adicionar um personagem
add_character() {
    local name="$1"
    local server="$2"
    local world="$3"
    
    # Remover espaços extras e caracteres especiais do nome
    name=$(echo "$name" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr -d '\r')
    
    # Pular linhas vazias
    if [[ -z "$name" ]]; then
        return 0
    fi
    
    log "🔄 Adicionando: $name ($server/$world)"
    
    # Montar query string com debug
    local encoded_server=$(echo "$server" | jq -sRr @uri)
    local encoded_world=$(echo "$world" | jq -sRr @uri)
    local encoded_name=$(echo "$name" | jq -sRr @uri)
    
    local url="$API_URL/api/v1/characters/scrape-and-create?server=$encoded_server&world=$encoded_world&character_name=$encoded_name"
    
    # Debug: mostrar URL que está sendo enviada
    log "🔍 URL sendo enviada: $url"
    
    # Fazer a requisição para a API usando o prefixo correto e parâmetros na query string
    response=$(curl -s -w "%{http_code}" -o /tmp/response.json \
        -X POST "$url" 2>/dev/null)
    
    http_code="${response: -3}"
    response_body=$(cat /tmp/response.json 2>/dev/null || echo "{}")
    
    # Debug: mostrar resposta completa
    log "🔍 Resposta HTTP: $http_code"
    log "🔍 Corpo da resposta: $response_body"
    
    if [[ "$http_code" == "200" ]] || [[ "$http_code" == "201" ]]; then
        log "✅ $name adicionado com sucesso"
        return 0
    elif [[ "$http_code" == "422" ]]; then
        # Personagem já existe ou erro de scraping
        log "⚠️ $name já existe ou erro de scraping: $response_body"
        return 0  # Não é um erro crítico
    else
        error "❌ Erro ao adicionar $name (HTTP $http_code): $response_body"
        return 1
    fi
}

# Função principal
main() {
    log "=== INICIANDO ADIÇÃO EM MASSA DE PERSONAGENS (VERSÃO CORRIGIDA V5) ==="
    
    # Mostrar informações do sistema
    log "📊 Informações do sistema:"
    log "   - Data/Hora: $(date)"
    log "   - Diretório: $PROJECT_DIR"
    log "   - API URL: $API_URL"
    log "   - Log file: $LOG_FILE"
    
    # Testar conectividade
    if ! test_api_connectivity; then
        error "❌ Falha na conectividade com a API. Verifique se o backend está rodando."
        error "Execute: docker-compose restart backend"
        exit 1
    fi
    
    # Verificar se os arquivos existem
    log "📁 Verificando arquivos de entrada..."
    if [[ ! -f "$PROJECT_DIR/InitialLoad/san.txt" ]]; then
        error "❌ Arquivo san.txt não encontrado em $PROJECT_DIR/InitialLoad/"
        exit 1
    fi
    
    if [[ ! -f "$PROJECT_DIR/InitialLoad/aura.txt" ]]; then
        error "❌ Arquivo aura.txt não encontrado em $PROJECT_DIR/InitialLoad/"
        exit 1
    fi
    
    # Contar linhas nos arquivos
    san_count=$(wc -l < "$PROJECT_DIR/InitialLoad/san.txt")
    aura_count=$(wc -l < "$PROJECT_DIR/InitialLoad/aura.txt")
    
    log "✅ Arquivos encontrados:"
    log "   - san.txt: $san_count linhas"
    log "   - aura.txt: $aura_count linhas"
    
    # Contadores
    total_san=0
    total_aura=0
    success_san=0
    success_aura=0
    errors_san=0
    errors_aura=0
    
    # Processar personagens do SAN
    log "📋 Processando personagens do SAN..."
    while IFS= read -r name; do
        # Pular primeira linha (cabeçalho)
        if [[ $total_san -eq 0 ]]; then
            total_san=$((total_san + 1))
            log "   ⏭️ Pulando cabeçalho do arquivo SAN"
            continue
        fi
        
        total_san=$((total_san + 1))
        
        # Mostrar progresso a cada 10 personagens
        if [[ $((total_san % 10)) -eq 0 ]]; then
            log "📈 Progresso SAN: $total_san/$((san_count - 1)) (${success_san} sucessos, ${errors_san} erros)"
        fi
        
        if add_character "$name" "taleon" "san"; then
            success_san=$((success_san + 1))
        else
            errors_san=$((errors_san + 1))
        fi
        
        # Delay para não sobrecarregar a API
        sleep 2
        
    done < "$PROJECT_DIR/InitialLoad/san.txt"
    
    # Processar personagens do AURA
    log "📋 Processando personagens do AURA..."
    while IFS= read -r name; do
        # Pular primeira linha (cabeçalho)
        if [[ $total_aura -eq 0 ]]; then
            total_aura=$((total_aura + 1))
            log "   ⏭️ Pulando cabeçalho do arquivo AURA"
            continue
        fi
        
        total_aura=$((total_aura + 1))
        
        # Mostrar progresso a cada 10 personagens
        if [[ $((total_aura % 10)) -eq 0 ]]; then
            log "📈 Progresso AURA: $total_aura/$((aura_count - 1)) (${success_aura} sucessos, ${errors_aura} erros)"
        fi
        
        if add_character "$name" "taleon" "aura"; then
            success_aura=$((success_aura + 1))
        else
            errors_aura=$((errors_aura + 1))
        fi
        
        # Delay para não sobrecarregar a API
        sleep 2
        
    done < "$PROJECT_DIR/InitialLoad/aura.txt"
    
    # Resumo final
    log "=== RESUMO FINAL ==="
    log "📊 SAN: $success_san sucessos, $errors_san erros (total processado: $((total_san - 1)))"
    log "📊 AURA: $success_aura sucessos, $errors_aura erros (total processado: $((total_aura - 1)))"
    log "📊 Total de sucessos: $((success_san + success_aura))"
    log "📊 Total de erros: $((errors_san + errors_aura))"
    log "📊 Taxa de sucesso: $(( (success_san + success_aura) * 100 / (total_san + total_aura - 2) ))%"
    log "📄 Log completo salvo em: $LOG_FILE"
    
    # Limpar arquivo temporário
    rm -f /tmp/response.json
    
    log "=== ADIÇÃO EM MASSA CONCLUÍDA ==="
}

# Executar função principal
main "$@" 