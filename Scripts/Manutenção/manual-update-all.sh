#!/bin/bash

# Script para atualização manual de todos os personagens
# Executa de forma controlada para evitar sobrecarga

echo "🔄 Iniciando atualização manual de todos os personagens..."
echo "=================================================="

# Verificar se o backend está funcionando
echo "📡 Verificando status do backend..."
if ! curl -s "http://localhost:8000/health" > /dev/null; then
    echo "❌ Backend não está respondendo!"
    exit 1
fi

echo "✅ Backend está funcionando"

# Obter lista de personagens ativos
echo "📋 Obtendo lista de personagens ativos..."
CHARACTERS=$(curl -s "http://localhost:8000/api/v1/characters?page=1&size=1000" | jq -r '.characters[] | select(.is_active == true) | .id')

if [ -z "$CHARACTERS" ]; then
    echo "❌ Nenhum personagem ativo encontrado!"
    exit 1
fi

# Contar personagens
CHAR_COUNT=$(echo "$CHARACTERS" | wc -l)
echo "📊 Encontrados $CHAR_COUNT personagens ativos"

# Confirmar antes de prosseguir
echo ""
echo "⚠️  ATENÇÃO: Esta operação irá atualizar TODOS os $CHAR_COUNT personagens!"
echo "   - Isso pode levar alguns minutos"
echo "   - Cada personagem será atualizado individualmente"
echo "   - Será feito um delay entre cada update para evitar sobrecarga"
echo ""
read -p "🤔 Continuar? (s/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo "❌ Operação cancelada pelo usuário"
    exit 0
fi

# Iniciar atualização
echo "🚀 Iniciando atualização..."
echo "=================================================="

SUCCESS_COUNT=0
ERROR_COUNT=0
TOTAL_COUNT=0

for char_id in $CHARACTERS; do
    TOTAL_COUNT=$((TOTAL_COUNT + 1))
    
    echo "[$TOTAL_COUNT/$CHAR_COUNT] 🔄 Atualizando personagem ID: $char_id"
    
    # Fazer refresh do personagem
    RESPONSE=$(curl -s -X POST "http://localhost:8000/api/v1/characters/$char_id/refresh")
    
    if echo "$RESPONSE" | jq -e '.success' > /dev/null; then
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        NAME=$(echo "$RESPONSE" | jq -r '.message' | sed 's/Dados de '\''//' | sed 's/'\'' atualizados com sucesso!//')
        SNAPSHOTS=$(echo "$RESPONSE" | jq -r '.snapshots_created // 0')
        UPDATED=$(echo "$RESPONSE" | jq -r '.snapshots_updated // 0')
        echo "   ✅ $NAME - Snapshots: +$SNAPSHOTS, Atualizados: $UPDATED"
    else
        ERROR_COUNT=$((ERROR_COUNT + 1))
        ERROR_MSG=$(echo "$RESPONSE" | jq -r '.detail // .message // "Erro desconhecido"')
        echo "   ❌ ID $char_id - $ERROR_MSG"
    fi
    
    # Delay entre requests para não sobrecarregar
    if [ $TOTAL_COUNT -lt $CHAR_COUNT ]; then
        echo "   ⏳ Aguardando 2 segundos..."
        sleep 2
    fi
done

echo ""
echo "=================================================="
echo "🎉 ATUALIZAÇÃO CONCLUÍDA!"
echo "📊 Resumo:"
echo "   ✅ Sucessos: $SUCCESS_COUNT"
echo "   ❌ Erros: $ERROR_COUNT"
echo "   📋 Total: $TOTAL_COUNT"
echo ""

if [ $ERROR_COUNT -gt 0 ]; then
    echo "⚠️  Alguns personagens tiveram erros. Verifique os logs:"
    echo "   docker logs tibia-tracker-backend --tail 50"
fi

echo "✅ Script concluído!" 