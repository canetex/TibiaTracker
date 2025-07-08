#!/bin/bash

echo "=== TESTE DE ENDPOINTS ESPECÍFICOS ==="
echo ""

# Testar endpoints um por um
echo "1. Testando /health:"
curl -s -w "Status: %{http_code}\n" http://localhost:8000/health/
echo ""

echo "2. Testando /characters/stats/global:"
curl -s -w "Status: %{http_code}\n" http://localhost:8000/characters/stats/global
echo ""

echo "3. Testando /characters/recent:"
curl -s -w "Status: %{http_code}\n" http://localhost:8000/characters/recent
echo ""

echo "4. Testando /characters (GET):"
curl -s -w "Status: %{http_code}\n" http://localhost:8000/characters
echo ""

echo "5. Testando /docs:"
curl -s -w "Status: %{http_code}\n" http://localhost:8000/docs
echo ""

echo "=== FIM DOS TESTES ===" 