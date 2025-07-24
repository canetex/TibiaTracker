#!/bin/bash
# Script para forçar atualização do frontend e limpar cache

echo "🔄 Forçando atualização do frontend..."

# 1. Parar o container do frontend
echo "📦 Parando container do frontend..."
docker-compose stop frontend

# 2. Remover o container para forçar recriação
echo "🗑️ Removendo container do frontend..."
docker-compose rm -f frontend

# 3. Reconstruir a imagem do frontend
echo "🔨 Reconstruindo imagem do frontend..."
docker-compose build --no-cache frontend

# 4. Iniciar o container novamente
echo "🚀 Iniciando container do frontend..."
docker-compose up -d frontend

# 5. Aguardar o container estar pronto
echo "⏳ Aguardando container estar pronto..."
sleep 10

# 6. Verificar se está rodando
echo "✅ Verificando status..."
docker-compose ps frontend

echo ""
echo "🎉 Frontend atualizado com sucesso!"
echo ""
echo "💡 INSTRUÇÕES PARA O USUÁRIO:"
echo "1. Abra o navegador em modo incógnito/privado"
echo "2. Acesse a aplicação"
echo "3. Pressione Ctrl+F5 para forçar recarregamento"
echo "4. Expanda os filtros avançados (ícone de expandir)"
echo "5. Procure pelo filtro 'Recovery Ativo'"
echo ""
echo "🔍 Se ainda não aparecer, execute:"
echo "   docker-compose logs frontend" 