#!/bin/bash

# =============================================================================
# SCRIPT DE DIAGNÓSTICO DA API
# =============================================================================

echo "=== DIAGNÓSTICO DA API TIBIA TRACKER ==="
echo "Data/Hora: $(date)"
echo ""

# Verificar se o container está rodando
echo "1. Status dos containers:"
docker-compose ps
echo ""

# Verificar logs do backend
echo "2. Últimos logs do backend:"
docker-compose logs --tail=20 backend
echo ""

# Testar endpoints básicos
echo "3. Testando endpoints:"

echo "   - Health endpoint:"
curl -s -w "HTTP Code: %{http_code}\n" http://localhost:8000/health/ || echo "❌ Falha"
echo ""

echo "   - Characters stats global:"
curl -s -w "HTTP Code: %{http_code}\n" http://localhost:8000/characters/stats/global || echo "❌ Falha"
echo ""

echo "   - Characters recent:"
curl -s -w "HTTP Code: %{http_code}\n" http://localhost:8000/characters/recent || echo "❌ Falha"
echo ""

echo "   - Scrape and create endpoint (teste):"
curl -s -w "HTTP Code: %{http_code}\n" -X POST "http://localhost:8000/characters/scrape-and-create?server=taleon&world=san&character_name=test" || echo "❌ Falha"
echo ""

# Verificar se a porta está aberta
echo "4. Verificando porta 8000:"
netstat -tlnp | grep :8000 || echo "❌ Porta 8000 não está aberta"
echo ""

# Verificar variáveis de ambiente
echo "5. Verificando arquivo .env:"
if [[ -f ".env" ]]; then
    echo "✅ Arquivo .env existe"
    grep -E "(DB_|API_|DEBUG)" .env | head -5
else
    echo "❌ Arquivo .env não encontrado"
fi
echo ""

echo "=== DIAGNÓSTICO CONCLUÍDO ===" 