#!/bin/bash

# =============================================================================
# SCRIPT DE APLICAÇÃO DAS OTIMIZAÇÕES DO RUBINOT
# =============================================================================
# Este script aplica as otimizações necessárias para processar o volume alto
# de personagens do Rubinot (+10.000 personagens)

set -e  # Para o script se qualquer comando falhar

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para log com timestamp
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Função para log de sucesso
success() {
    log "${GREEN}✅ $1${NC}"
}

# Função para log de erro
error() {
    log "${RED}❌ $1${NC}"
}

# Função para log de aviso
warning() {
    log "${YELLOW}⚠️  $1${NC}"
}

# Função para log de informação
info() {
    log "${BLUE}ℹ️  $1${NC}"
}

# Verificar se estamos no diretório correto
if [ ! -f "docker-compose.yml" ]; then
    error "Este script deve ser executado no diretório raiz do projeto (onde está o docker-compose.yml)"
    exit 1
fi

# Verificar se o container do PostgreSQL está rodando
if ! docker ps | grep -q tibia-tracker-postgres; then
    error "Container do PostgreSQL não está rodando. Inicie os containers primeiro com: docker-compose up -d"
    exit 1
fi

info "🚀 Iniciando aplicação das otimizações do Rubinot..."

# =============================================================================
# 1. BACKUP DO BANCO
# =============================================================================
info "📦 Criando backup do banco antes das alterações..."
BACKUP_FILE="backup_pre_rubinot_$(date +%Y%m%d_%H%M%S).sql"

if docker exec tibia-tracker-postgres pg_dump -U tibia_user -d tibia_tracker > "$BACKUP_FILE" 2>/dev/null; then
    success "Backup criado: $BACKUP_FILE"
else
    warning "Não foi possível criar o backup. Continuando mesmo assim..."
fi

# =============================================================================
# 2. APLICAR OTIMIZAÇÕES DO BANCO
# =============================================================================
info "🔧 Aplicando otimizações do banco de dados..."

# Verificar se o arquivo SQL existe
if [ ! -f "add_outfit_fields.sql" ]; then
    error "Arquivo add_outfit_fields.sql não encontrado!"
    exit 1
fi

# Aplicar as otimizações
if docker exec -i tibia-tracker-postgres psql -U tibia_user -d tibia_tracker < add_outfit_fields.sql; then
    success "Otimizações do banco aplicadas com sucesso!"
else
    error "Falha ao aplicar otimizações do banco!"
    exit 1
fi

# =============================================================================
# 3. REINICIAR CONTAINERS
# =============================================================================
info "🔄 Reiniciando containers para aplicar as mudanças..."

if docker-compose restart backend; then
    success "Container do backend reiniciado!"
else
    error "Falha ao reiniciar o container do backend!"
    exit 1
fi

# Aguardar o backend ficar pronto
info "⏳ Aguardando o backend ficar pronto..."
sleep 10

# Verificar se o backend está respondendo
if curl -f http://localhost:8000/health > /dev/null 2>&1; then
    success "Backend está respondendo corretamente!"
else
    warning "Backend pode não estar totalmente pronto ainda. Aguarde alguns segundos."
fi

# =============================================================================
# 4. VERIFICAR ARQUIVO CSV
# =============================================================================
info "📋 Verificando arquivo CSV do Rubinot..."

if [ -f "Scripts/InitialLoad/Rubinot.csv" ]; then
    CSV_LINES=$(wc -l < "Scripts/InitialLoad/Rubinot.csv")
    success "Arquivo CSV encontrado com $CSV_LINES linhas"
else
    error "Arquivo Scripts/InitialLoad/Rubinot.csv não encontrado!"
    info "Execute: wget -O Scripts/InitialLoad/Rubinot.csv https://raw.githubusercontent.com/canetex/TibiaTracker/feature/rubinot-scraper/Scripts/InitialLoad/Rubinot.csv"
    exit 1
fi

# =============================================================================
# 5. EXECUTAR BULK ADD
# =============================================================================
info "🚀 Executando bulk add dos personagens do Rubinot..."

if [ -f "Scripts/Manutenção/bulk-add-rubinot.sh" ]; then
    if chmod +x "Scripts/Manutenção/bulk-add-rubinot.sh" && ./Scripts/Manutenção/bulk-add-rubinot.sh; then
        success "Bulk add executado com sucesso!"
    else
        error "Falha ao executar o bulk add!"
        exit 1
    fi
else
    error "Script bulk-add-rubinot.sh não encontrado!"
    info "Execute: wget -O Scripts/Manutenção/bulk-add-rubinot.sh https://raw.githubusercontent.com/canetex/TibiaTracker/feature/rubinot-scraper/Scripts/Manutenção/bulk-add-rubinot.sh"
    exit 1
fi

# =============================================================================
# CONCLUSÃO
# =============================================================================
success "🎉 Todas as otimizações do Rubinot foram aplicadas com sucesso!"
info "📊 O sistema está pronto para processar o volume alto de personagens do Rubinot"
info "🔍 Você pode monitorar o progresso nos logs do backend"
info "📈 Acesse o frontend para ver os personagens sendo carregados"

echo ""
info "📝 Próximos passos:"
echo "   1. Monitore os logs: docker logs -f tibia-tracker-backend"
echo "   2. Verifique o progresso no frontend: http://localhost:3000"
echo "   3. Acompanhe as estatísticas na API: http://localhost:8000/health" 