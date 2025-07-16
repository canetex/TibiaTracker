#!/bin/bash

# =============================================================================
# SCRIPT PARA TESTAR SUBDOMÍNIOS DO RUBINOT
# =============================================================================
# Testa diferentes subdomínios e URLs possíveis do servidor Rubinot
# para encontrar uma alternativa que não esteja bloqueada pelo Cloudflare

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para log
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

success() {
    log "${GREEN}✅ $1${NC}"
}

error() {
    log "${RED}❌ $1${NC}"
}

warning() {
    log "${YELLOW}⚠️  $1${NC}"
}

info() {
    log "${BLUE}ℹ️  $1${NC}"
}

# Lista de subdomínios para testar
SUBDOMAINS=(
    "www"
    "api"
    "characters"
    "game"
    "server"
    "online"
    "tibia"
    "ots"
    "auroria"
    "belaria"
    "elysian"
    "bellum"
    "harmonian"
    "vesperia"
    "spectrum"
    "kalarian"
    "lunarian"
    "solarian"
)

# Lista de URLs alternativas para testar
ALTERNATIVE_URLS=(
    "https://rubinot.com.br"
    "https://www.rubinot.com.br"
    "https://rubinot.com"
    "https://www.rubinot.com"
    "https://rubinot.net"
    "https://www.rubinot.net"
    "https://rubinot.org"
    "https://www.rubinot.org"
    "https://rubinot.online"
    "https://www.rubinot.online"
)

# Lista de endpoints para testar
ENDPOINTS=(
    "/"
    "/characters"
    "/character"
    "/player"
    "/players"
    "/api/characters"
    "/api/player"
    "/?subtopic=characters"
    "/?subtopic=player"
    "/?subtopic=characters&name=test"
)

info "🔍 Iniciando teste de subdomínios e URLs do Rubinot..."

# Testar URLs alternativas
info "📋 Testando URLs alternativas..."
for url in "${ALTERNATIVE_URLS[@]}"; do
    log "Testando: $url"
    if curl -s -I "$url" | head -1 | grep -q "200\|301\|302"; then
        success "✅ $url - ACESSÍVEL"
        echo "   Headers:"
        curl -s -I "$url" | head -10 | sed 's/^/   /'
        echo ""
    else
        error "❌ $url - NÃO ACESSÍVEL"
    fi
done

echo ""

# Testar subdomínios
info "📋 Testando subdomínios..."
for subdomain in "${SUBDOMAINS[@]}"; do
    url="https://$subdomain.rubinot.com.br"
    log "Testando: $url"
    if curl -s -I "$url" | head -1 | grep -q "200\|301\|302"; then
        success "✅ $url - ACESSÍVEL"
        echo "   Headers:"
        curl -s -I "$url" | head -10 | sed 's/^/   /'
        echo ""
    else
        error "❌ $url - NÃO ACESSÍVEL"
    fi
done

echo ""

# Testar endpoints específicos
info "📋 Testando endpoints específicos..."
for url in "${ALTERNATIVE_URLS[@]}"; do
    for endpoint in "${ENDPOINTS[@]}"; do
        full_url="$url$endpoint"
        log "Testando: $full_url"
        if curl -s -I "$full_url" | head -1 | grep -q "200\|301\|302"; then
            success "✅ $full_url - ACESSÍVEL"
        else
            error "❌ $full_url - NÃO ACESSÍVEL"
        fi
    done
done

echo ""

# Testar com diferentes User-Agents
info "📋 Testando com diferentes User-Agents..."
USER_AGENTS=(
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/121.0"
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
)

for ua in "${USER_AGENTS[@]}"; do
    log "Testando com User-Agent: $ua"
    if curl -s -I -H "User-Agent: $ua" "https://rubinot.com.br" | head -1 | grep -q "200\|301\|302"; then
        success "✅ Acessível com User-Agent específico"
    else
        error "❌ Não acessível com User-Agent específico"
    fi
done

echo ""

# Verificar se há APIs públicas
info "📋 Verificando APIs públicas..."
API_ENDPOINTS=(
    "https://rubinot.com.br/api/characters"
    "https://rubinot.com.br/api/players"
    "https://rubinot.com.br/api/v1/characters"
    "https://rubinot.com.br/api/v1/players"
    "https://api.rubinot.com.br/characters"
    "https://api.rubinot.com.br/players"
)

for api_url in "${API_ENDPOINTS[@]}"; do
    log "Testando API: $api_url"
    if curl -s -I "$api_url" | head -1 | grep -q "200\|301\|302"; then
        success "✅ $api_url - API ENCONTRADA!"
        echo "   Response:"
        curl -s "$api_url" | head -5 | sed 's/^/   /'
        echo ""
    else
        error "❌ $api_url - API não encontrada"
    fi
done

echo ""

info "🎯 Resumo dos testes:"
info "   - Se alguma URL retornou 200/301/302, pode ser uma alternativa viável"
info "   - Se nenhuma URL funcionou, o site pode estar temporariamente indisponível"
info "   - Se todas retornaram 403, o Cloudflare está bloqueando todas as requisições"
info ""
info "💡 Próximos passos:"
info "   1. Se encontrou URL alternativa, atualizar o scraper"
info "   2. Se encontrou API, implementar integração"
info "   3. Se nada funcionou, considerar automação com browser" 