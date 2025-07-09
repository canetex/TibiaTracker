#!/bin/bash

# =====================================================
# SCRIPT PARA EXECUTAR ETAPA 1 DA MIGRAÇÃO
# Adicionar campo exp_date na tabela character_snapshots
# =====================================================

set -e  # Parar em caso de erro

echo "====================================================="
echo "ETAPA 1: ADICIONAR CAMPO EXP_DATE"
echo "====================================================="
echo ""

# Verificar se estamos no diretório correto
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ Erro: Execute este script na raiz do projeto"
    exit 1
fi

# Verificar se o Docker está rodando
if ! docker info > /dev/null 2>&1; then
    echo "❌ Erro: Docker não está rodando"
    exit 1
fi

# Verificar se os containers estão rodando
if ! docker ps | grep -q "tibia-tracker-backend"; then
    echo "❌ Erro: Container tibia-tracker-backend não está rodando"
    echo "Execute: docker-compose up -d"
    exit 1
fi

echo "✅ Verificações iniciais OK"
echo ""

# Backup do banco antes da migração
echo "📦 Criando backup do banco de dados..."
docker exec tibia-tracker-backend pg_dump -U postgres -d tibia_tracker > backup_before_step1_$(date +%Y%m%d_%H%M%S).sql

if [ $? -eq 0 ]; then
    echo "✅ Backup criado com sucesso"
else
    echo "❌ Erro ao criar backup"
    exit 1
fi

echo ""

# Executar script de migração
echo "🔄 Executando script de migração..."
docker exec -i tibia-tracker-backend psql -U postgres -d tibia_tracker < Scripts/Manutenção/step1-add-exp-date.sql

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ ETAPA 1 CONCLUÍDA COM SUCESSO!"
    echo ""
    echo "📊 Verificações realizadas:"
    echo "   - Campo exp_date adicionado"
    echo "   - Dados migrados de scraped_at para exp_date"
    echo "   - Backup criado: character_snapshots_backup_step1"
    echo ""
    echo "🔄 Próximo passo: Testar funcionalidade do sistema"
    echo ""
else
    echo ""
    echo "❌ ERRO NA MIGRAÇÃO!"
    echo ""
    echo "🔧 Para reverter:"
    echo "   docker exec tibia-tracker-backend psql -U postgres -d tibia_tracker -c 'DROP TABLE IF EXISTS character_snapshots; ALTER TABLE character_snapshots_backup_step1 RENAME TO character_snapshots;'"
    echo ""
    exit 1
fi

echo "====================================================="
echo "ETAPA 1 FINALIZADA"
echo "=====================================================" 