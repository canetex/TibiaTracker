#!/bin/bash

# Script para criar a tabela character_favorites
# Etapa 3 da migração da estrutura do banco de dados

set -e

echo "🔄 Criando tabela character_favorites..."

# Executar o SQL de criação
docker exec -i tibia-tracker-postgres psql -U tibia_user -d tibia_tracker < Backend/sql/create_character_favorites.sql

echo "✅ Tabela character_favorites criada com sucesso!"
echo "📊 Verificando estrutura da tabela..."

# Verificar a estrutura da tabela
docker exec -i tibia-tracker-postgres psql -U tibia_user -d tibia_tracker -c "\d character_favorites"

echo "🎉 Etapa 3 concluída com sucesso!" 