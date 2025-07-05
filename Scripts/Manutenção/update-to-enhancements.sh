#!/bin/bash

# =============================================================================
# TIBIA TRACKER - SCRIPT DE ATUALIZAÇÃO PARA ENHANCEMENTS
# =============================================================================
# Script para atualizar aplicação LXC da branch main para feature/enhancements

set -e  # Parar em caso de erro

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para log colorido
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Verificar se estamos no diretório correto
if [ ! -f "docker-compose.yml" ]; then
    error "Execute este script no diretório raiz do projeto (onde está o docker-compose.yml)"
    exit 1
fi

# Carregar variáveis de ambiente
if [ -f ".env" ]; then
    log "Carregando variáveis de ambiente do arquivo .env"
    export $(grep -v '^#' .env | xargs)
else
    error "Arquivo .env não encontrado!"
    exit 1
fi

# URL base do GitHub
GITHUB_BASE="https://raw.githubusercontent.com/canetex/TibiaTracker/feature/enhancements"

log "🚀 Iniciando atualização para feature/enhancements..."

# 1. Backup do banco atual
log "📦 Fazendo backup do banco atual..."
if [ -f "Scripts/Manutenção/backup-database.sh" ]; then
    chmod +x Scripts/Manutenção/backup-database.sh
    ./Scripts/Manutenção/backup-database.sh
else
    warn "Script de backup não encontrado, pulando..."
fi

# 2. Criar diretórios se não existirem
log "📁 Criando diretórios necessários..."
mkdir -p Backend/app/services
mkdir -p Scripts/Manutenção

# 3. Download dos arquivos Backend
log "⬇️ Baixando arquivos do Backend..."

# Modelo do banco
wget -q -O Backend/app/models/character.py "${GITHUB_BASE}/Backend/app/models/character.py"
log "  ✅ character.py"

# Serviço de outfits
wget -q -O Backend/app/services/outfit_manager.py "${GITHUB_BASE}/Backend/app/services/outfit_manager.py"
log "  ✅ outfit_manager.py"

# Script SQL
wget -q -O Backend/sql/init.sql "${GITHUB_BASE}/Backend/sql/init.sql"
log "  ✅ init.sql"

# 4. Download dos arquivos Frontend
log "⬇️ Baixando arquivos do Frontend..."

# Componente de filtros
wget -q -O Frontend/src/components/CharacterFilters.js "${GITHUB_BASE}/Frontend/src/components/CharacterFilters.js"
log "  ✅ CharacterFilters.js"

# Página principal
wget -q -O Frontend/src/pages/Home.js "${GITHUB_BASE}/Frontend/src/pages/Home.js"
log "  ✅ Home.js"

# Componente de busca
wget -q -O Frontend/src/components/CharacterSearch.js "${GITHUB_BASE}/Frontend/src/components/CharacterSearch.js"
log "  ✅ CharacterSearch.js"

# Card de personagem
wget -q -O Frontend/src/components/CharacterCard.js "${GITHUB_BASE}/Frontend/src/components/CharacterCard.js"
log "  ✅ CharacterCard.js"

# 5. Download dos scripts
log "⬇️ Baixando scripts de manutenção..."

# Script de backup
wget -q -O Scripts/Manutenção/backup-database.sh "${GITHUB_BASE}/Scripts/Manutenção/backup-database.sh"
log "  ✅ backup-database.sh"

# Script de migração
wget -q -O Scripts/Manutenção/migrate-outfit-images.py "${GITHUB_BASE}/Scripts/Manutenção/migrate-outfit-images.py"
log "  ✅ migrate-outfit-images.py"

# Script de execução
wget -q -O Scripts/Manutenção/run-outfit-migration.sh "${GITHUB_BASE}/Scripts/Manutenção/run-outfit-migration.sh"
log "  ✅ run-outfit-migration.sh"

# Script de teste
wget -q -O Scripts/Manutenção/test-outfit-organization.py "${GITHUB_BASE}/Scripts/Manutenção/test-outfit-organization.py"
log "  ✅ test-outfit-organization.py"

# 6. Tornar scripts executáveis
log "🔧 Configurando permissões..."
chmod +x Scripts/Manutenção/*.sh
chmod +x Scripts/Manutenção/*.py
log "  ✅ Permissões configuradas"

# 7. Parar containers
log "🛑 Parando containers..."
docker-compose down

# 8. Reconstruir backend
log "🔨 Reconstruindo backend..."
docker-compose build backend

# 9. Iniciar containers
log "🚀 Iniciando containers..."
docker-compose up -d

# 10. Aguardar inicialização
log "⏳ Aguardando inicialização dos serviços..."
sleep 30

# 11. Verificar status
log "🔍 Verificando status dos serviços..."

if docker-compose ps | grep -q "Up"; then
    log "  ✅ Containers estão rodando"
else
    error "❌ Containers não estão rodando!"
    docker-compose logs backend
    exit 1
fi

# 12. Testar API
log "🧪 Testando API..."
if curl -f http://localhost:8000/health > /dev/null 2>&1; then
    log "  ✅ API está respondendo"
else
    error "❌ API não está respondendo!"
    docker-compose logs backend
    exit 1
fi

# 13. Perguntar sobre migração
echo ""
warn "⚠️  ATENÇÃO: Deseja executar a migração do banco de dados agora?"
echo "   Isso irá:"
echo "   1. Adicionar novas colunas ao banco"
echo "   2. Baixar imagens de outfit"
echo "   3. Atualizar registros com caminhos locais"
echo ""

read -p "Executar migração agora? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    log "🔄 Executando migração..."
    ./Scripts/Manutenção/run-outfit-migration.sh
else
    log "⏭️ Migração pulada. Execute manualmente quando desejar:"
    log "   ./Scripts/Manutenção/run-outfit-migration.sh"
fi

# 14. Testar organização (opcional)
echo ""
read -p "Testar organização de outfits? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    log "🧪 Testando organização de outfits..."
    python Scripts/Manutenção/test-outfit-organization.py
fi

# 15. Finalização
echo ""
log "🎉 Atualização concluída com sucesso!"
log "📋 Resumo das mudanças:"
log "   ✅ Sistema de filtros avançados no frontend"
log "   ✅ Hyperlink correto para Taleon"
log "   ✅ Sistema de armazenamento local de imagens"
log "   ✅ Scripts de backup e migração"
log "   ✅ Organização por variação de outfit"
echo ""
log "🌐 Acesse sua aplicação:"
log "   Frontend: http://localhost:3000"
log "   API: http://localhost:8000"
echo ""
log "📚 Comandos úteis:"
log "   - Ver logs: docker-compose logs -f"
log "   - Backup: ./Scripts/Manutenção/backup-database.sh"
log "   - Migração: ./Scripts/Manutenção/run-outfit-migration.sh"
log "   - Teste: python Scripts/Manutenção/test-outfit-organization.py" 