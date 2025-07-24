#!/bin/bash
# Script de Teste: Filtro Recovery Active (Bash)
# ==============================================
# 
# Este script testa se o filtro recovery_active está funcionando corretamente
# usando curl (disponível no servidor).

# Configurações
API_BASE="http://localhost:8000"
FRONTEND_BASE="http://localhost"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧪 INICIANDO TESTES DO FILTRO RECOVERY ACTIVE${NC}"
echo "=================================================="

# Função para fazer requisições HTTP
make_request() {
    local url="$1"
    local response=$(curl -s -w "%{http_code}" "$url")
    local status_code="${response: -3}"
    local body="${response%???}"
    
    echo "$status_code|$body"
}

# Teste 1: Verificar se o endpoint filter-ids aceita recovery_active
echo -e "\n${YELLOW}🔍 Testando Backend - Endpoint filter-ids...${NC}"

# Teste sem filtro
echo "Testando sem filtro..."
result=$(make_request "${API_BASE}/api/characters/filter-ids?limit=5")
status=$(echo "$result" | cut -d'|' -f1)
body=$(echo "$result" | cut -d'|' -f2-)

if [ "$status" = "200" ]; then
    count=$(echo "$body" | grep -o '"ids":\[[^]]*\]' | grep -o '\[.*\]' | tr -d '[]' | tr ',' '\n' | wc -l)
    echo -e "${GREEN}✅ Sem filtro: $status - $count IDs${NC}"
else
    echo -e "${RED}❌ Sem filtro: $status${NC}"
fi

# Teste com recovery_active=true
echo "Testando recovery_active=true..."
result=$(make_request "${API_BASE}/api/characters/filter-ids?recovery_active=true&limit=5")
status=$(echo "$result" | cut -d'|' -f1)
body=$(echo "$result" | cut -d'|' -f2-)

if [ "$status" = "200" ]; then
    count=$(echo "$body" | grep -o '"ids":\[[^]]*\]' | grep -o '\[.*\]' | tr -d '[]' | tr ',' '\n' | wc -l)
    echo -e "${GREEN}✅ Recovery ativo: $status - $count IDs${NC}"
    backend_ok=true
else
    echo -e "${RED}❌ Recovery ativo: $status${NC}"
    backend_ok=false
fi

# Teste com recovery_active=false
echo "Testando recovery_active=false..."
result=$(make_request "${API_BASE}/api/characters/filter-ids?recovery_active=false&limit=5")
status=$(echo "$result" | cut -d'|' -f1)
body=$(echo "$result" | cut -d'|' -f2-)

if [ "$status" = "200" ]; then
    count=$(echo "$body" | grep -o '"ids":\[[^]]*\]' | grep -o '\[.*\]' | tr -d '[]' | tr ',' '\n' | wc -l)
    echo -e "${GREEN}✅ Recovery inativo: $status - $count IDs${NC}"
else
    echo -e "${RED}❌ Recovery inativo: $status${NC}"
fi

# Teste 2: Verificar se o frontend está carregando
echo -e "\n${YELLOW}🌐 Testando Frontend...${NC}"
result=$(make_request "$FRONTEND_BASE")
status=$(echo "$result" | cut -d'|' -f1)

if [ "$status" = "200" ]; then
    echo -e "${GREEN}✅ Frontend: $status - Carregado com sucesso${NC}"
    frontend_ok=true
else
    echo -e "${RED}❌ Frontend: $status${NC}"
    frontend_ok=false
fi

# Teste 3: Verificar se o campo recovery_active existe nos dados
echo -e "\n${YELLOW}📊 Testando campo recovery_active nos dados...${NC}"
result=$(make_request "${API_BASE}/api/characters/recent?limit=3")
status=$(echo "$result" | cut -d'|' -f1)
body=$(echo "$result" | cut -d'|' -f2-)

if [ "$status" = "200" ]; then
    if echo "$body" | grep -q "recovery_active"; then
        echo -e "${GREEN}✅ Campo recovery_active presente nos dados${NC}"
        field_ok=true
        
        # Mostrar exemplo de dados
        name=$(echo "$body" | grep -o '"name":"[^"]*"' | head -1 | cut -d'"' -f4)
        recovery=$(echo "$body" | grep -o '"recovery_active":[^,]*' | head -1 | cut -d':' -f2)
        echo "   Exemplo: $name - recovery_active: $recovery"
    else
        echo -e "${RED}❌ Campo recovery_active NÃO encontrado nos dados${NC}"
        field_ok=false
    fi
else
    echo -e "${RED}❌ Erro ao buscar dados: $status${NC}"
    field_ok=false
fi

# Resumo dos testes
echo -e "\n${BLUE}📋 RESUMO DOS TESTES${NC}"
echo "=================================================="
echo -e "Backend (filter-ids): ${backend_ok:+${GREEN}✅ OK${NC}}${backend_ok:-${RED}❌ FALHOU${NC}}"
echo -e "Frontend (carregamento): ${frontend_ok:+${GREEN}✅ OK${NC}}${frontend_ok:-${RED}❌ FALHOU${NC}}"
echo -e "Campo recovery_active: ${field_ok:+${GREEN}✅ OK${NC}}${field_ok:-${RED}❌ FALHOU${NC}}"

if [ "$backend_ok" = true ] && [ "$frontend_ok" = true ] && [ "$field_ok" = true ]; then
    echo -e "\n${GREEN}🎉 TODOS OS TESTES PASSARAM!${NC}"
    echo "O filtro recovery_active deve estar funcionando corretamente."
    echo -e "\n${YELLOW}💡 DICAS:${NC}"
    echo "1. Limpe o cache do navegador (Ctrl+F5)"
    echo "2. Expanda os filtros avançados na interface"
    echo "3. Procure pelo filtro 'Recovery Ativo'"
else
    echo -e "\n${RED}⚠️ ALGUNS TESTES FALHARAM!${NC}"
    echo "Verifique se:"
    echo "1. O backend está rodando na porta 8000"
    echo "2. O frontend está rodando na porta 80"
    echo "3. A migração foi executada corretamente"
fi

echo -e "\n${BLUE}🔍 LOGS ÚTEIS:${NC}"
echo "docker-compose logs backend | tail -20"
echo "docker-compose logs frontend | tail -20" 