#!/bin/bash

echo "=== TESTE DE ENDPOINTS COM PREFIXO CORRETO /api/v1 ==="
echo ""

# Testar endpoints com o prefixo correto
echo "1. Testando /health:"
curl -s -w "Status: %{http_code}\n" http://localhost:8000/health/
echo ""

echo "2. Testando /api/v1/characters/stats/global:"
curl -s -w "Status: %{http_code}\n" http://localhost:8000/api/v1/characters/stats/global
echo ""

echo "3. Testando /api/v1/characters/recent:"
curl -s -w "Status: %{http_code}\n" http://localhost:8000/api/v1/characters/recent
echo ""

echo "4. Testando /api/v1/characters (GET):"
curl -s -w "Status: %{http_code}\n" http://localhost:8000/api/v1/characters
echo ""

echo "5. Testando /api/v1/characters/scrape-and-create (POST):"
curl -s -w "Status: %{http_code}\n" -X POST "http://localhost:8000/api/v1/characters/scrape-and-create?server=taleon&world=san&character_name=test"
echo ""

echo "6. Testando /docs:"
curl -s -w "Status: %{http_code}\n" http://localhost:8000/docs
echo ""

echo "=== FIM DOS TESTES ===" 