#!/bin/bash

# Script para atualizar TODOS os personagens usando paginação
# Este script pega todos os personagens em lotes de 50

echo "🔄 Iniciando atualização manual de TODOS os personagens..."
echo "=================================================="

# Verificar se o backend está funcionando
echo "📡 Verificando status do backend..."
if ! curl -s "http://localhost:8000/health" > /dev/null; then
    echo "❌ Backend não está respondendo!"
    exit 1
fi

echo "✅ Backend está funcionando"

# Obter total de personagens
echo "📊 Obtendo total de personagens..."
TOTAL_CHARS=$(curl -s "http://localhost:8000/api/v1/characters?page=1&size=1" | jq -r '.total')
PAGE_SIZE=50
TOTAL_PAGES=$(( (TOTAL_CHARS + PAGE_SIZE - 1) / PAGE_SIZE ))

echo "📈 Estatísticas:"
echo "   📋 Total de personagens: $TOTAL_CHARS"
echo "   📄 Tamanho da página: $PAGE_SIZE"
echo "   📑 Total de páginas: $TOTAL_PAGES"

echo ""
echo "⚠️  ATENÇÃO: Esta operação irá atualizar TODOS os $TOTAL_CHARS personagens!"
echo "   - Isso pode levar várias horas"
echo "   - Cada personagem será atualizado individualmente"
echo "   - Será feito um delay entre cada update para evitar sobrecarga"
echo ""

read -p "🤔 Continuar? (s/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo "❌ Operação cancelada"
    exit 0
fi

echo "🚀 Iniciando atualização..."
echo "=================================================="

TOTAL_UPDATED=0
TOTAL_SNAPSHOTS_CREATED=0
TOTAL_SNAPSHOTS_UPDATED=0

# Loop através de todas as páginas
for PAGE in $(seq 1 $TOTAL_PAGES); do
    echo "📄 Processando página $PAGE de $TOTAL_PAGES..."
    
    # Obter personagens da página atual
    CHARACTERS=$(curl -s "http://localhost:8000/api/v1/characters?page=$PAGE&size=$PAGE_SIZE" | jq -r '.characters[] | .id')
    
    if [ -z "$CHARACTERS" ]; then
        echo "⚠️  Nenhum personagem encontrado na página $PAGE"
        continue
    fi
    
    # Contar personagens nesta página
    CHARS_IN_PAGE=$(echo "$CHARACTERS" | wc -l)
    echo "   📋 Encontrados $CHARS_IN_PAGE personagens na página $PAGE"
    
    # Loop através dos personagens desta página
    CHAR_COUNT=0
    for CHAR_ID in $CHARACTERS; do
        CHAR_COUNT=$((CHAR_COUNT + 1))
        TOTAL_UPDATED=$((TOTAL_UPDATED + 1))
        
        echo "[$TOTAL_UPDATED/$TOTAL_CHARS] 🔄 Atualizando personagem ID: $CHAR_ID"
        
        # Fazer refresh do personagem
        RESPONSE=$(curl -s -X POST "http://localhost:8000/api/v1/characters/$CHAR_ID/refresh")
        
        if echo "$RESPONSE" | jq -e '.success' > /dev/null; then
            NAME=$(echo "$RESPONSE" | jq -r '.message' | sed 's/.*'\''\([^'\'']*\)'\''.*/\1/')
            SNAPSHOTS_CREATED=$(echo "$RESPONSE" | jq -r '.snapshots_created // 0')
            SNAPSHOTS_UPDATED=$(echo "$RESPONSE" | jq -r '.snapshots_updated // 0')
            
            TOTAL_SNAPSHOTS_CREATED=$((TOTAL_SNAPSHOTS_CREATED + SNAPSHOTS_CREATED))
            TOTAL_SNAPSHOTS_UPDATED=$((TOTAL_SNAPSHOTS_UPDATED + SNAPSHOTS_UPDATED))
            
            echo "   ✅ $NAME - Snapshots: +$SNAPSHOTS_CREATED, Atualizados: $SNAPSHOTS_UPDATED"
        else
            ERROR=$(echo "$RESPONSE" | jq -r '.detail // .message // "Erro desconhecido"')
            echo "   ❌ Erro: $ERROR"
        fi
        
        # Aguardar entre personagens para evitar sobrecarga
        if [ $CHAR_COUNT -lt $CHARS_IN_PAGE ]; then
            echo "   ⏳ Aguardando 2 segundos..."
            sleep 2
        fi
    done
    
    # Aguardar entre páginas
    if [ $PAGE -lt $TOTAL_PAGES ]; then
        echo "   ⏳ Aguardando 5 segundos entre páginas..."
        sleep 5
    fi
done

echo ""
echo "🎉 Atualização concluída!"
echo "=================================================="
echo "📊 Resumo final:"
echo "   📋 Total de personagens atualizados: $TOTAL_UPDATED"
echo "   ➕ Snapshots criados: $TOTAL_SNAPSHOTS_CREATED"
echo "   🔄 Snapshots atualizados: $TOTAL_SNAPSHOTS_UPDATED"
echo "   ⏰ Timestamp: $(date)"
echo ""
echo "✅ Script concluído!" 