#!/bin/bash
# Script para debugar rotas da API
# =================================

echo "🔍 DEBUGANDO ROTAS DA API"
echo "=========================="

# 1. Verificar se o backend está respondendo
echo -e "\n📡 Testando conectividade com backend..."
curl -s "http://localhost/api/health" || echo "❌ Health check falhou"

# 2. Testar diferentes endpoints
echo -e "\n🧪 Testando endpoints da API..."

endpoints=(
    "/api/health"
    "/api/characters"
    "/api/characters/"
    "/api/characters/recent"
    "/api/characters/filter-ids"
    "/api/v1/characters/recent"
    "/api/v1/characters/filter-ids"
)

for endpoint in "${endpoints[@]}"; do
    echo -n "Testando $endpoint: "
    response=$(curl -s -w "%{http_code}" "http://localhost$endpoint")
    status="${response: -3}"
    body="${response%???}"
    
    if [ "$status" = "200" ]; then
        echo -e "✅ $status"
        echo "   Resposta: ${body:0:100}..."
    elif [ "$status" = "404" ]; then
        echo -e "❌ $status (Not Found)"
    else
        echo -e "⚠️ $status"
        echo "   Resposta: ${body:0:100}..."
    fi
done

# 3. Verificar logs do backend
echo -e "\n📋 Logs do Backend (últimas 20 linhas):"
docker-compose logs backend | tail -20

# 4. Verificar logs do nginx
echo -e "\n📋 Logs do Nginx (últimas 10 linhas):"
docker-compose logs frontend | tail -10

# 5. Testar conectividade interna
echo -e "\n🔗 Testando conectividade interna..."
docker exec tibia-tracker-frontend curl -s "http://backend:8000/health" && echo "✅ Backend acessível internamente" || echo "❌ Backend não acessível internamente"

# 6. Verificar configuração do nginx
echo -e "\n⚙️ Verificando configuração do nginx..."
docker exec tibia-tracker-frontend nginx -t && echo "✅ Configuração do nginx válida" || echo "❌ Configuração do nginx inválida"

# 7. Verificar se o backend está rodando
echo -e "\n🐳 Status dos containers:"
docker-compose ps backend frontend

echo -e "\n🎯 PRÓXIMOS PASSOS:"
echo "1. Verificar se as rotas estão corretas no backend"
echo "2. Verificar se o prefixo da API está correto"
echo "3. Verificar logs de erro do backend" 