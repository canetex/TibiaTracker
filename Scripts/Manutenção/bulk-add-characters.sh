#!/bin/bash

# =============================================================================
# SCRIPT TEMPORÁRIO - ADIÇÃO EM MASSA DE PERSONAGENS
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
    
    log "Adicionando: $name ($server/$world)"
    
    # Fazer a requisição para a API
    response=$(curl -s -w "%{http_code}" -o /tmp/response.json \
        -X POST "$API_URL/characters/scrape-and-create" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "server=$server&world=$world&character_name=$name" 2>/dev/null)
    
    http_code="${response: -3}"
    response_body=$(cat /tmp/response.json 2>/dev/null || echo "{}")
    
    if [[ "$http_code" == "200" ]] || [[ "$http_code" == "201" ]]; then
        log "✅ $name adicionado com sucesso"
        return 0
    else
        error "❌ Erro ao adicionar $name (HTTP $http_code): $response_body"
        return 1
    fi
}

# Função principal
main() {
    log "=== INICIANDO ADIÇÃO EM MASSA DE PERSONAGENS ==="
    
    # Verificar se a API está respondendo
    if ! curl -s -f "$API_URL/health/" > /dev/null 2>&1; then
        error "❌ API não está respondendo em $API_URL"
        exit 1
    fi
    
    log "✅ API está respondendo"
    
    # Verificar se os arquivos existem
    if [[ ! -f "$PROJECT_DIR/InitialLoad/san.txt" ]]; then
        error "❌ Arquivo san.txt não encontrado em $PROJECT_DIR/InitialLoad/"
        exit 1
    fi
    
    if [[ ! -f "$PROJECT_DIR/InitialLoad/aura.txt" ]]; then
        error "❌ Arquivo aura.txt não encontrado em $PROJECT_DIR/InitialLoad/"
        exit 1
    fi
    
    log "✅ Arquivos encontrados"
    
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
            continue
        fi
        
        total_san=$((total_san + 1))
        
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
            continue
        fi
        
        total_aura=$((total_aura + 1))
        
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
    log "SAN: $success_san sucessos, $errors_san erros (total: $((total_san - 1)))"
    log "AURA: $success_aura sucessos, $errors_aura erros (total: $((total_aura - 1)))"
    log "Total de sucessos: $((success_san + success_aura))"
    log "Total de erros: $((errors_san + errors_aura))"
    log "Log completo salvo em: $LOG_FILE"
    
    # Limpar arquivo temporário
    rm -f /tmp/response.json
    
    log "=== ADIÇÃO EM MASSA CONCLUÍDA ==="
}

# Executar função principal
main "$@" 