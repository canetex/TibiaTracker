#!/bin/bash

# =============================================================================
# SCRIPT PARA ATUALIZAR SERVIDOR VIA WGET DIRETO
# =============================================================================

set -e

# Configurações
SERVER_IP="192.168.1.227"
SERVER_USER="root"
SERVER_PATH="/opt/tibia-tracker"
GITHUB_RAW="https://raw.githubusercontent.com/canetex/TibiaTracker/main"

echo "🚀 Iniciando atualização do servidor via wget..."
echo "📍 Servidor: $SERVER_IP"
echo "📁 Diretório: $SERVER_PATH"

# 1. Fazer backup do diretório atual
echo "💾 Fazendo backup do diretório atual..."
ssh $SERVER_USER@$SERVER_IP "cd $SERVER_PATH && tar -czf backup-$(date +%Y%m%d-%H%M%S).tar.gz . --exclude=backup-*.tar.gz"

# 2. Parar os containers
echo "🛑 Parando containers..."
ssh $SERVER_USER@$SERVER_IP "cd $SERVER_PATH && docker-compose down"

# 3. Fazer backup do banco de dados
echo "🗄️ Fazendo backup do banco de dados..."
ssh $SERVER_USER@$SERVER_IP "cd $SERVER_PATH && docker exec tibia-tracker-postgres pg_dump -U \$DB_USER \$DB_NAME > backup-db-$(date +%Y%m%d-%H%M%S).sql"

# 4. Baixar arquivos específicos atualizados
echo "⬇️ Baixando arquivos atualizados..."

# Backend files
ssh $SERVER_USER@$SERVER_IP "cd $SERVER_PATH && wget -O Backend/app/services/outfit_service.py $GITHUB_RAW/Backend/app/services/outfit_service.py"
ssh $SERVER_USER@$SERVER_IP "cd $SERVER_PATH && wget -O Backend/app/services/scraping/taleon.py $GITHUB_RAW/Backend/app/services/scraping/taleon.py"
ssh $SERVER_USER@$SERVER_IP "cd $SERVER_PATH && wget -O Backend/app/services/character.py $GITHUB_RAW/Backend/app/services/character.py"
ssh $SERVER_USER@$SERVER_IP "cd $SERVER_PATH && wget -O Backend/app/models/character.py $GITHUB_RAW/Backend/app/models/character.py"
ssh $SERVER_USER@$SERVER_IP "cd $SERVER_PATH && wget -O Backend/app/schemas/character.py $GITHUB_RAW/Backend/app/schemas/character.py"
ssh $SERVER_USER@$SERVER_IP "cd $SERVER_PATH && wget -O Backend/app/main.py $GITHUB_RAW/Backend/app/main.py"
ssh $SERVER_USER@$SERVER_IP "cd $SERVER_PATH && wget -O Backend/requirements.txt $GITHUB_RAW/Backend/requirements.txt"
ssh $SERVER_USER@$SERVER_IP "cd $SERVER_PATH && wget -O Backend/Dockerfile $GITHUB_RAW/Backend/Dockerfile"

# Frontend files
ssh $SERVER_USER@$SERVER_IP "cd $SERVER_PATH && wget -O Frontend/src/components/CharacterCard.js $GITHUB_RAW/Frontend/src/components/CharacterCard.js"

# Docker files
ssh $SERVER_USER@$SERVER_IP "cd $SERVER_PATH && wget -O docker-compose.yml $GITHUB_RAW/docker-compose.yml"

# Scripts
ssh $SERVER_USER@$SERVER_IP "cd $SERVER_PATH && wget -O Scripts/Manutenção/apply-migration.sh $GITHUB_RAW/Scripts/Manutenção/apply-migration.sh"
ssh $SERVER_USER@$SERVER_IP "cd $SERVER_PATH && wget -O Scripts/Deploy/update-server-wget.sh $GITHUB_RAW/Scripts/Deploy/update-server-wget.sh"

# SQL migration
ssh $SERVER_USER@$SERVER_IP "cd $SERVER_PATH && wget -O Backend/sql/add_profile_url_to_snapshots.sql $GITHUB_RAW/Backend/sql/add_profile_url_to_snapshots.sql"

# 5. Tornar scripts executáveis
echo "🔧 Tornando scripts executáveis..."
ssh $SERVER_USER@$SERVER_IP "cd $SERVER_PATH && chmod +x Scripts/Manutenção/apply-migration.sh"
ssh $SERVER_USER@$SERVER_IP "cd $SERVER_PATH && chmod +x Scripts/Deploy/update-server-wget.sh"

# 6. Aplicar migração do banco
echo "🔧 Aplicando migração do banco..."
ssh $SERVER_USER@$SERVER_IP "cd $SERVER_PATH && ./Scripts/Manutenção/apply-migration.sh"

# 7. Reconstruir e iniciar containers
echo "🔨 Reconstruindo containers..."
ssh $SERVER_USER@$SERVER_IP "cd $SERVER_PATH && docker-compose up -d --build"

# 8. Verificar status
echo "✅ Verificando status dos containers..."
ssh $SERVER_USER@$SERVER_IP "cd $SERVER_PATH && docker-compose ps"

# 9. Testar API
echo "🧪 Testando API..."
sleep 10
if curl -f "http://$SERVER_IP:8000/health" > /dev/null 2>&1; then
    echo "✅ API está funcionando!"
else
    echo "❌ API não está respondendo. Verificar logs:"
    ssh $SERVER_USER@$SERVER_IP "cd $SERVER_PATH && docker-compose logs backend"
fi

echo "🎉 Atualização concluída!"
echo "📊 Para verificar logs: ssh $SERVER_USER@$SERVER_IP 'cd $SERVER_PATH && docker-compose logs -f'" 