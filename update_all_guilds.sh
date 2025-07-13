#!/bin/bash

# Script para atualizar guilds de todos os personagens
# Autor: Tibia Tracker
# Data: 2025-07-11

echo "🔄 Iniciando atualização de guilds para todos os personagens..."

# Obter todos os personagens
echo "📋 Obtendo lista de personagens..."
CHARACTERS_JSON=$(curl -s "http://localhost:8000/api/v1/characters?limit=1000")

# Extrair IDs dos personagens
CHARACTER_IDS=$(echo "$CHARACTERS_JSON" | jq -r '.characters[].id')

# Contadores
TOTAL=0
UPDATED=0
ERRORS=0

echo "🚀 Iniciando atualização de ${#CHARACTER_IDS[@]} personagens..."

# Loop através de cada personagem
for ID in $CHARACTER_IDS; do
    TOTAL=$((TOTAL + 1))
    
    echo -n "[$TOTAL] Atualizando personagem ID $ID... "
    
    # Fazer refresh do personagem
    RESPONSE=$(curl -s -X POST "http://localhost:8000/api/v1/characters/$ID/refresh")
    
    # Verificar se foi bem-sucedido
    if echo "$RESPONSE" | jq -e '.success' > /dev/null; then
        GUILD=$(echo "$RESPONSE" | jq -r '.guild // "null"')
        LEVEL=$(echo "$RESPONSE" | jq -r '.level // "N/A"')
        DURATION=$(echo "$RESPONSE" | jq -r '.scraping_duration_ms // "N/A"')
        
        echo "✅ OK - Guild: $GUILD, Level: $LEVEL, Duração: ${DURATION}ms"
        UPDATED=$((UPDATED + 1))
    else
        ERROR_MSG=$(echo "$RESPONSE" | jq -r '.detail // "Erro desconhecido"')
        echo "❌ ERRO: $ERROR_MSG"
        ERRORS=$((ERRORS + 1))
    fi
    
    # Pequena pausa para não sobrecarregar o servidor
    sleep 1
done

echo ""
echo "🎉 Atualização concluída!"
echo "📊 Estatísticas:"
echo "   Total de personagens: $TOTAL"
echo "   Atualizados com sucesso: $UPDATED"
echo "   Erros: $ERRORS"
echo "   Taxa de sucesso: $((UPDATED * 100 / TOTAL))%" 