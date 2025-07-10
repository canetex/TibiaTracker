#!/bin/bash

# Script para remover o campo is_favorited da tabela characters
# Etapa 2 da migração da estrutura do banco de dados

set -e

echo "🔄 Iniciando remoção do campo is_favorited da tabela characters..."

# Executar o SQL de remoção
docker exec -w /app tibia-tracker-backend psql -h tibia-tracker-db -U tibia_tracker -d tibia_tracker -f /app/sql/remove_is_favorited.sql

echo "✅ Campo is_favorited removido com sucesso!"
echo "📊 Verificando estrutura da tabela characters..."

# Verificar a estrutura da tabela
docker exec -w /app tibia-tracker-backend psql -h tibia-tracker-db -U tibia_tracker -d tibia_tracker -c "\d characters"

echo "🎉 Etapa 2 concluída com sucesso!" 