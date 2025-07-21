#!/bin/bash

# =============================================================================
# TIBIA TRACKER - BACKUP COMPLETO PARA PRODUÇÃO
# =============================================================================
# Script para criar backup completo da base de dados e gerar ZIP

set -e  # Parar em caso de erro

echo "💾 Iniciando backup completo para produção..."

# =============================================================================
# CONFIGURAÇÕES
# =============================================================================

# Carregar variáveis de ambiente
if [ -f ".env" ]; then
    source .env
else
    echo "❌ Arquivo .env não encontrado!"
    exit 1
fi

# Configurações de backup
BACKUP_DIR="backups/production"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="tibia-tracker-backup-${TIMESTAMP}"
BACKUP_PATH="${BACKUP_DIR}/${BACKUP_NAME}"

# Criar diretório de backup
mkdir -p "$BACKUP_PATH"

echo "📁 Diretório de backup: $BACKUP_PATH"

# =============================================================================
# VERIFICAÇÕES PRÉ-BACKUP
# =============================================================================

echo "🔍 Verificações pré-backup..."

# Verificar se containers estão rodando
if ! docker-compose ps | grep -q "Up"; then
    echo "❌ Containers não estão rodando!"
    echo "🚀 Iniciando containers..."
    docker-compose up -d
    sleep 10
fi

# Verificar se PostgreSQL está saudável
if ! docker-compose exec -T postgres pg_isready -U "$DB_USER" -d "$DB_NAME" > /dev/null 2>&1; then
    echo "❌ PostgreSQL não está respondendo!"
    exit 1
fi

echo "✅ Verificações concluídas"

# =============================================================================
# BACKUP DO BANCO DE DADOS
# =============================================================================

echo "🗄️  Criando backup do banco de dados..."

# Backup completo do PostgreSQL
DB_BACKUP_FILE="${BACKUP_PATH}/database.sql"
echo "📄 Backup do banco: $DB_BACKUP_FILE"

if docker-compose exec -T postgres pg_dump -U "$DB_USER" "$DB_NAME" --verbose --clean --if-exists --create > "$DB_BACKUP_FILE" 2>/dev/null; then
    echo "✅ Backup do banco criado com sucesso"
    
    # Verificar tamanho do arquivo
    DB_SIZE=$(du -h "$DB_BACKUP_FILE" | cut -f1)
    echo "📊 Tamanho do backup: $DB_SIZE"
else
    echo "❌ Erro ao criar backup do banco!"
    exit 1
fi

# =============================================================================
# BACKUP DE CONFIGURAÇÕES
# =============================================================================

echo "⚙️  Criando backup de configurações..."

# Backup do arquivo .env
if [ -f ".env" ]; then
    cp .env "${BACKUP_PATH}/env.backup"
    echo "✅ Backup do .env criado"
fi

# Backup do docker-compose.yml
if [ -f "docker-compose.yml" ]; then
    cp docker-compose.yml "${BACKUP_PATH}/docker-compose.backup"
    echo "✅ Backup do docker-compose.yml criado"
fi

# Backup das configurações do Caddy
if [ -f "Scripts/Deploy/Caddyfile" ]; then
    cp Scripts/Deploy/Caddyfile "${BACKUP_PATH}/caddyfile.backup"
    echo "✅ Backup do Caddyfile criado"
fi

# =============================================================================
# BACKUP DE DADOS ADICIONAIS
# =============================================================================

echo "📁 Criando backup de dados adicionais..."

# Backup das imagens de outfits
OUTFITS_DIR="${BACKUP_PATH}/outfits"
mkdir -p "$OUTFITS_DIR"

if docker-compose exec -T backend ls /app/outfits > /dev/null 2>&1; then
    echo "📸 Copiando imagens de outfits..."
    docker cp tibia-tracker-backend:/app/outfits/. "$OUTFITS_DIR/" 2>/dev/null || echo "⚠️  Nenhuma imagem de outfit encontrada"
    echo "✅ Backup das imagens de outfits criado"
fi

# Backup dos logs
LOGS_DIR="${BACKUP_PATH}/logs"
mkdir -p "$LOGS_DIR"

echo "📋 Copiando logs..."
docker-compose logs --no-color > "${LOGS_DIR}/docker-logs.txt" 2>/dev/null || echo "⚠️  Não foi possível copiar logs do Docker"
docker-compose exec -T backend cat /var/log/tibia-tracker/app.log > "${LOGS_DIR}/backend-app.log" 2>/dev/null || echo "⚠️  Não foi possível copiar logs do backend"

# =============================================================================
# BACKUP DE ESTATÍSTICAS
# =============================================================================

echo "📊 Criando backup de estatísticas..."

# Estatísticas do banco
STATS_FILE="${BACKUP_PATH}/database-stats.txt"
echo "📈 Gerando estatísticas do banco..."

docker-compose exec -T postgres psql -U "$DB_USER" -d "$DB_NAME" -c "
SELECT 
    'CHARACTERS' as table_name,
    COUNT(*) as total_records
FROM characters
UNION ALL
SELECT 
    'CHARACTER_SNAPSHOTS' as table_name,
    COUNT(*) as total_records
FROM character_snapshots
UNION ALL
SELECT 
    'CHARACTER_FAVORITES' as table_name,
    COUNT(*) as total_records
FROM character_favorites;
" > "$STATS_FILE" 2>/dev/null || echo "⚠️  Não foi possível gerar estatísticas"

# =============================================================================
# BACKUP DE METADADOS
# =============================================================================

echo "📝 Criando backup de metadados..."

# Informações do sistema
METADATA_FILE="${BACKUP_PATH}/backup-metadata.txt"
cat > "$METADATA_FILE" << EOF
TIBIA TRACKER - BACKUP DE PRODUÇÃO
==================================

Data/Hora do Backup: $(date)
Versão do Sistema: $(git describe --tags --always 2>/dev/null || echo "Desconhecida")
Branch: $(git branch --show-current 2>/dev/null || echo "Desconhecida")
Commit: $(git rev-parse HEAD 2>/dev/null || echo "Desconhecido")

CONFIGURAÇÕES:
- DB_NAME: $DB_NAME
- DB_USER: $DB_USER
- ENVIRONMENT: $ENVIRONMENT
- API_PORT: $API_PORT

CONTAINERS:
$(docker-compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}")

SISTEMA:
- Hostname: $(hostname)
- Kernel: $(uname -r)
- Docker Version: $(docker --version)
- Docker Compose Version: $(docker-compose --version)

ARQUIVOS INCLUÍDOS:
- database.sql (Backup completo do PostgreSQL)
- env.backup (Variáveis de ambiente)
- docker-compose.backup (Configuração dos containers)
- caddyfile.backup (Configuração do proxy reverso)
- outfits/ (Imagens de outfits dos personagens)
- logs/ (Logs do sistema)
- database-stats.txt (Estatísticas do banco)

INSTRUÇÕES DE RESTAURAÇÃO:
1. Extrair o arquivo ZIP
2. Configurar o novo servidor com Docker e Docker Compose
3. Copiar os arquivos de configuração
4. Restaurar o banco: psql -U usuario -d banco < database.sql
5. Iniciar os containers: docker-compose up -d

EOF

echo "✅ Metadados criados"

# =============================================================================
# VERIFICAÇÃO DE INTEGRIDADE
# =============================================================================

echo "🔍 Verificando integridade do backup..."

# Verificar se arquivo de banco existe e não está vazio
if [ ! -s "$DB_BACKUP_FILE" ]; then
    echo "❌ Arquivo de backup do banco está vazio ou não existe!"
    exit 1
fi

# Verificar se arquivo de banco contém dados
if ! grep -q "CREATE TABLE" "$DB_BACKUP_FILE"; then
    echo "❌ Arquivo de backup não contém estrutura de tabelas!"
    exit 1
fi

echo "✅ Integridade do backup verificada"

# =============================================================================
# CRIAÇÃO DO ARQUIVO ZIP
# =============================================================================

echo "📦 Criando arquivo ZIP..."

ZIP_FILE="${BACKUP_DIR}/${BACKUP_NAME}.zip"

# Criar ZIP com todos os arquivos
cd "$BACKUP_PATH"
zip -r "../${BACKUP_NAME}.zip" . > /dev/null
cd - > /dev/null

# Verificar se ZIP foi criado
if [ -f "$ZIP_FILE" ]; then
    ZIP_SIZE=$(du -h "$ZIP_FILE" | cut -f1)
    echo "✅ Arquivo ZIP criado: $ZIP_FILE"
    echo "📊 Tamanho do ZIP: $ZIP_SIZE"
else
    echo "❌ Erro ao criar arquivo ZIP!"
    exit 1
fi

# =============================================================================
# LIMPEZA E FINALIZAÇÃO
# =============================================================================

echo "🧹 Limpando arquivos temporários..."

# Remover diretório temporário
rm -rf "$BACKUP_PATH"

# Manter apenas os últimos 5 backups
echo "🗑️  Removendo backups antigos (mantendo os últimos 5)..."
cd "$BACKUP_DIR"
ls -t *.zip | tail -n +6 | xargs -r rm -f
cd - > /dev/null

# =============================================================================
# RESUMO FINAL
# =============================================================================

echo ""
echo "🎉 BACKUP COMPLETO CONCLUÍDO!"
echo "============================="
echo ""
echo "📋 RESUMO:"
echo "✅ Backup do banco de dados: $DB_SIZE"
echo "✅ Arquivo ZIP criado: $ZIP_FILE"
echo "✅ Tamanho do ZIP: $ZIP_SIZE"
echo "✅ Configurações incluídas"
echo "✅ Imagens de outfits incluídas"
echo "✅ Logs incluídos"
echo "✅ Metadados incluídos"
echo ""
echo "📁 LOCALIZAÇÃO:"
echo "   $ZIP_FILE"
echo ""
echo "🚀 PRÓXIMOS PASSOS PARA DEPLOY:"
echo "   1. Transferir $ZIP_FILE para o novo servidor"
echo "   2. Extrair o arquivo ZIP"
echo "   3. Configurar o novo servidor"
echo "   4. Restaurar o banco de dados"
echo "   5. Iniciar os containers"
echo ""
echo "📝 COMANDOS PARA RESTAURAÇÃO:"
echo "   # Extrair ZIP"
echo "   unzip $BACKUP_NAME.zip"
echo ""
echo "   # Restaurar banco"
echo "   psql -U \$DB_USER -d \$DB_NAME < database.sql"
echo ""
echo "   # Iniciar containers"
echo "   docker-compose up -d"
echo ""
echo "🔒 SEGURANÇA:"
echo "   • Mantenha o arquivo ZIP seguro"
echo "   • Use transferência segura (SCP/SFTP)"
echo "   • Verifique a integridade após transferência"
echo ""

# Retornar caminho do arquivo ZIP para uso em scripts
echo "$ZIP_FILE" 