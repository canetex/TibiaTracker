#!/bin/bash

# =============================================================================
# SCRIPT PARA APLICAR MIGRAÇÃO DO BANCO DE DADOS
# =============================================================================

set -e

echo "🔧 Aplicando migração do banco de dados..."

# Verificar se o container está rodando
if ! docker ps | grep -q tibia-tracker-postgres; then
    echo "❌ Container do PostgreSQL não está rodando!"
    echo "Execute: docker-compose up -d postgres"
    exit 1
fi

# Aplicar migração
echo "📝 Aplicando migração: add_profile_url_to_snapshots.sql"
docker exec -i tibia-tracker-postgres psql -U $DB_USER -d $DB_NAME < Backend/sql/add_profile_url_to_snapshots.sql

echo "✅ Migração aplicada com sucesso!"
echo "🔄 Reiniciando backend para aplicar mudanças..."

# Reiniciar backend
docker-compose restart backend

echo "✅ Migração concluída!"
echo "📊 Verificar logs: docker-compose logs backend" 