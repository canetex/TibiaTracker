#!/bin/bash

# Script de debug para testar o problema de encoding no bulk-add

API_URL="http://localhost:8000"

# Função para testar um personagem específico
test_character() {
    local name="$1"
    local server="$2"
    local world="$3"
    
    echo "=== Testando: $name ($server/$world) ==="
    
    # Mostrar encoding dos parâmetros
    echo "Nome (raw): '$name'"
    echo "Nome (hex): $(echo -n "$name" | xxd -p)"
    echo "Servidor (raw): '$server'"
    echo "Servidor (hex): $(echo -n "$server" | xxd -p)"
    echo "World (raw): '$world'"
    echo "World (hex): $(echo -n "$world" | xxd -p)"
    
    # URL encode manual
    encoded_name=$(echo "$name" | jq -sRr @uri)
    encoded_server=$(echo "$server" | jq -sRr @uri)
    encoded_world=$(echo "$world" | jq -sRr @uri)
    
    echo "Nome (encoded): '$encoded_name'"
    echo "Servidor (encoded): '$encoded_server'"
    echo "World (encoded): '$encoded_world'"
    
    # Construir URL
    url="$API_URL/api/v1/characters/scrape-and-create?server=$encoded_server&world=$encoded_world&character_name=$encoded_name"
    echo "URL: $url"
    
    # Fazer requisição
    echo "Fazendo requisição..."
    response=$(curl -s -w "%{http_code}" -o /tmp/debug_response.json -X POST "$url" 2>/dev/null)
    
    http_code="${response: -3}"
    response_body=$(cat /tmp/debug_response.json 2>/dev/null || echo "{}")
    
    echo "HTTP Code: $http_code"
    echo "Response: $response_body"
    echo ""
}

# Testar com diferentes variações
echo "=== TESTE DE DEBUG BULK-ADD ==="
echo ""

# Teste 1: Personagem simples
test_character "TestChar" "taleon" "san"

# Teste 2: Personagem com espaços
test_character "Abnerzin Ii" "taleon" "san"

# Teste 3: Verificar se há caracteres especiais
echo "=== Verificando arquivo san.txt ==="
head -5 Scripts/InitialLoad/san.txt | while IFS= read -r line; do
    echo "Linha: '$line'"
    echo "Hex: $(echo -n "$line" | xxd -p)"
    echo "---"
done

echo "=== FIM DO DEBUG ===" 