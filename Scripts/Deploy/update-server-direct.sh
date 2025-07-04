#!/bin/bash

# =============================================================================
# SCRIPT PARA ATUALIZAR SERVIDOR EXECUTANDO DIRETAMENTE
# =============================================================================

set -e

# Configurações
SERVER_PATH="/opt/tibia-tracker"
GITHUB_RAW="https://raw.githubusercontent.com/canetex/TibiaTracker/main"

echo "🚀 Iniciando atualização do servidor..."
echo "📁 Diretório: $SERVER_PATH"

# 1. Fazer backup do diretório atual
echo "💾 Fazendo backup do diretório atual..."
cd $SERVER_PATH
tar -czf backup-$(date +%Y%m%d-%H%M%S).tar.gz . --exclude=backup-*.tar.gz

# 2. Parar os containers
echo "🛑 Parando containers..."
docker-compose down

# 3. Fazer backup do banco de dados
echo "🗄️ Fazendo backup do banco de dados..."
docker exec tibia-tracker-postgres pg_dump -U $DB_USER $DB_NAME > backup-db-$(date +%Y%m%d-%H%M%S).sql

# 4. Baixar arquivos específicos atualizados
echo "⬇️ Baixando arquivos atualizados..."

# Backend files
wget -O Backend/app/services/outfit_service.py $GITHUB_RAW/Backend/app/services/outfit_service.py
wget -O Backend/app/services/scraping/taleon.py $GITHUB_RAW/Backend/app/services/scraping/taleon.py
wget -O Backend/app/services/character.py $GITHUB_RAW/Backend/app/services/character.py
wget -O Backend/app/models/character.py $GITHUB_RAW/Backend/app/models/character.py
wget -O Backend/app/schemas/character.py $GITHUB_RAW/Backend/app/schemas/character.py
wget -O Backend/app/main.py $GITHUB_RAW/Backend/app/main.py
wget -O Backend/requirements.txt $GITHUB_RAW/Backend/requirements.txt
wget -O Backend/Dockerfile $GITHUB_RAW/Backend/Dockerfile

# Frontend files
wget -O Frontend/src/components/CharacterCard.js $GITHUB_RAW/Frontend/src/components/CharacterCard.js

# Docker files
wget -O docker-compose.yml $GITHUB_RAW/docker-compose.yml

# Scripts
wget -O Scripts/Manutenção/apply-migration.sh $GITHUB_RAW/Scripts/Manutenção/apply-migration.sh
wget -O Scripts/Deploy/update-server-direct.sh $GITHUB_RAW/Scripts/Deploy/update-server-direct.sh

# SQL migration
wget -O Backend/sql/add_profile_url_to_snapshots.sql $GITHUB_RAW/Backend/sql/add_profile_url_to_snapshots.sql

# 5. Tornar scripts executáveis
echo "🔧 Tornando scripts executáveis..."
chmod +x Scripts/Manutenção/apply-migration.sh
chmod +x Scripts/Deploy/update-server-direct.sh

# 6. Aplicar migração do banco
echo "🔧 Aplicando migração do banco..."
./Scripts/Manutenção/apply-migration.sh

# 7. Reconstruir e iniciar containers
echo "🔨 Reconstruindo containers..."
docker-compose up -d --build

# 8. Verificar status
echo "✅ Verificando status dos containers..."
docker-compose ps

# 9. Testar API
echo "🧪 Testando API..."
sleep 10
if curl -f "http://localhost:8000/health" > /dev/null 2>&1; then
    echo "✅ API está funcionando!"
else
    echo "❌ API não está respondendo. Verificar logs:"
    docker-compose logs backend
fi

echo "🎉 Atualização concluída!"
echo "📊 Para verificar logs: docker-compose logs -f" 