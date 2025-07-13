#!/bin/bash

# Script para ativar todos os personagens inativos
# Isso fará com que todos os personagens sejam incluídos nas atualizações automáticas

echo "🔄 Ativando todos os personagens inativos..."
echo "=================================================="

# Verificar se o backend está funcionando
echo "📡 Verificando status do backend..."
if ! curl -s "http://localhost:8000/health" > /dev/null; then
    echo "❌ Backend não está respondendo!"
    exit 1
fi

echo "✅ Backend está funcionando"

# Obter estatísticas atuais
echo "📊 Obtendo estatísticas atuais..."
TOTAL_CHARS=$(curl -s "http://localhost:8000/api/v1/characters?page=1&size=1" | jq -r '.total')
ACTIVE_CHARS=$(curl -s "http://localhost:8000/api/v1/characters?page=1&size=1000" | jq -r '.characters[] | select(.is_active == true) | .id' | wc -l)
INACTIVE_CHARS=$((TOTAL_CHARS - ACTIVE_CHARS))

echo "📈 Estatísticas atuais:"
echo "   📋 Total de personagens: $TOTAL_CHARS"
echo "   ✅ Ativos: $ACTIVE_CHARS"
echo "   ❌ Inativos: $INACTIVE_CHARS"

if [ $INACTIVE_CHARS -eq 0 ]; then
    echo "✅ Todos os personagens já estão ativos!"
    exit 0
fi

# Confirmar antes de prosseguir
echo ""
echo "⚠️  ATENÇÃO: Esta operação irá ativar TODOS os $INACTIVE_CHARS personagens inativos!"
echo "   - Isso fará com que todos sejam incluídos nas atualizações automáticas"
echo "   - O próximo update automático será mais demorado"
echo "   - Considere se realmente precisa de todos os personagens ativos"
echo ""
read -p "🤔 Continuar? (s/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo "❌ Operação cancelada pelo usuário"
    exit 0
fi

# Executar comando SQL para ativar todos os personagens
echo "🚀 Ativando todos os personagens..."
echo "=================================================="

# Usar docker exec para executar comando SQL
ACTIVATED_COUNT=$(docker exec -w /app tibia-tracker-backend psql -h $DB_HOST -U $DB_USER -d $DB_NAME -t -c "UPDATE characters SET is_active = true WHERE is_active = false; SELECT ROW_COUNT();" 2>/dev/null | tr -d ' ')

if [ $? -eq 0 ] && [ ! -z "$ACTIVATED_COUNT" ]; then
    echo "✅ Sucesso! $ACTIVATED_COUNT personagens foram ativados"
    
    # Verificar resultado
    echo ""
    echo "📊 Verificando resultado..."
    NEW_ACTIVE_CHARS=$(curl -s "http://localhost:8000/api/v1/characters?page=1&size=1000" | jq -r '.characters[] | select(.is_active == true) | .id' | wc -l)
    
    echo "📈 Novas estatísticas:"
    echo "   📋 Total de personagens: $TOTAL_CHARS"
    echo "   ✅ Ativos: $NEW_ACTIVE_CHARS"
    echo "   ❌ Inativos: $((TOTAL_CHARS - NEW_ACTIVE_CHARS))"
    
    echo ""
    echo "🎉 Todos os personagens estão agora ativos!"
    echo "⚠️  Próximo update automático incluirá todos os $NEW_ACTIVE_CHARS personagens"
    
else
    echo "❌ Erro ao ativar personagens"
    echo "💡 Tentando método alternativo..."
    
    # Método alternativo usando API
    echo "🔄 Usando método alternativo via API..."
    
    # Obter lista de personagens inativos
    INACTIVE_IDS=$(curl -s "http://localhost:8000/api/v1/characters?page=1&size=1000" | jq -r '.characters[] | select(.is_active == false) | .id')
    
    if [ -z "$INACTIVE_IDS" ]; then
        echo "✅ Nenhum personagem inativo encontrado!"
        exit 0
    fi
    
    ACTIVATED_COUNT=0
    TOTAL_INACTIVE=$(echo "$INACTIVE_IDS" | wc -l)
    
    for char_id in $INACTIVE_IDS; do
        # Ativar personagem via API
        RESPONSE=$(curl -s -X PUT "http://localhost:8000/api/v1/characters/$char_id" \
            -H "Content-Type: application/json" \
            -d '{"is_active": true}')
        
        if echo "$RESPONSE" | jq -e '.is_active' > /dev/null; then
            ACTIVATED_COUNT=$((ACTIVATED_COUNT + 1))
            echo "   ✅ ID $char_id ativado"
        else
            echo "   ❌ ID $char_id - Erro na ativação"
        fi
    done
    
    echo ""
    echo "📊 Resultado: $ACTIVATED_COUNT de $TOTAL_INACTIVE personagens ativados"
fi

echo ""
echo "✅ Script concluído!" 