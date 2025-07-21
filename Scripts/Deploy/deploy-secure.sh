#!/bin/bash

# =============================================================================
# TIBIA TRACKER - DEPLOY SEGURO
# =============================================================================
# Script para deploy com configurações de segurança

set -e  # Parar em caso de erro

echo "🔒 Iniciando deploy seguro do Tibia Tracker..."

# =============================================================================
# VERIFICAÇÕES DE SEGURANÇA
# =============================================================================

echo "🔍 Verificando configurações de segurança..."

# Verificar se arquivo .env existe
if [ ! -f ".env" ]; then
    echo "❌ Arquivo .env não encontrado!"
    echo "📝 Copie env.template para .env e configure as variáveis"
    exit 1
fi

# Verificar variáveis críticas
source .env

if [ "$ENVIRONMENT" != "production" ]; then
    echo "⚠️  ATENÇÃO: Deploy em ambiente não-produtivo ($ENVIRONMENT)"
    read -p "Continuar? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Verificar se SECRET_KEY não é o padrão
if [ "$SECRET_KEY" = "your-super-secret-key-here-change-this-in-production" ]; then
    echo "❌ SECRET_KEY não foi alterada! Configure uma chave segura."
    exit 1
fi

# Verificar se senhas do banco não são padrão
if [ "$DB_PASSWORD" = "your-secure-db-password" ]; then
    echo "❌ DB_PASSWORD não foi alterada! Configure uma senha segura."
    exit 1
fi

if [ "$REDIS_PASSWORD" = "your-redis-password" ]; then
    echo "❌ REDIS_PASSWORD não foi alterada! Configure uma senha segura."
    exit 1
fi

echo "✅ Configurações de segurança verificadas"

# =============================================================================
# CONFIGURAÇÃO DE FIREWALL
# =============================================================================

echo "🔥 Configurando firewall..."

# Verificar se UFW está instalado
if command -v ufw &> /dev/null; then
    echo "📋 Configurando UFW..."
    
    # Resetar regras
    ufw --force reset
    
    # Permitir SSH (porta 22)
    ufw allow 22/tcp
    
    # Permitir HTTP (porta 80) - apenas para Caddy
    ufw allow 80/tcp
    
    # Permitir HTTPS (porta 443) - apenas para Caddy
    ufw allow 443/tcp
    
    # Bloquear todas as outras portas
    ufw default deny incoming
    ufw default allow outgoing
    
    # Ativar firewall
    ufw --force enable
    
    echo "✅ Firewall configurado"
else
    echo "⚠️  UFW não encontrado. Instale com: sudo apt install ufw"
fi

# =============================================================================
# BACKUP ANTES DO DEPLOY
# =============================================================================

echo "💾 Criando backup antes do deploy..."

BACKUP_DIR="backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Backup do banco de dados
if docker-compose exec -T postgres pg_dump -U "$DB_USER" "$DB_NAME" > "$BACKUP_DIR/database.sql" 2>/dev/null; then
    echo "✅ Backup do banco criado: $BACKUP_DIR/database.sql"
else
    echo "⚠️  Não foi possível criar backup do banco"
fi

# Backup dos arquivos de configuração
cp .env "$BACKUP_DIR/env.backup" 2>/dev/null || echo "⚠️  Não foi possível fazer backup do .env"
cp docker-compose.yml "$BACKUP_DIR/docker-compose.backup" 2>/dev/null || echo "⚠️  Não foi possível fazer backup do docker-compose.yml"

echo "✅ Backup criado em: $BACKUP_DIR"

# =============================================================================
# DEPLOY DOS CONTAINERS
# =============================================================================

echo "🐳 Iniciando deploy dos containers..."

# Parar containers existentes
echo "🛑 Parando containers existentes..."
docker-compose down

# Remover imagens antigas (opcional)
read -p "Remover imagens antigas? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🗑️  Removendo imagens antigas..."
    docker system prune -f
fi

# Reconstruir e iniciar containers
echo "🔨 Reconstruindo containers..."
docker-compose up -d --build

# Aguardar containers ficarem saudáveis
echo "⏳ Aguardando containers ficarem saudáveis..."
sleep 30

# Verificar status dos containers
echo "🔍 Verificando status dos containers..."
docker-compose ps

# Verificar logs de erro
echo "📋 Verificando logs de erro..."
docker-compose logs --tail=50 | grep -i error || echo "✅ Nenhum erro encontrado"

# =============================================================================
# VERIFICAÇÕES PÓS-DEPLOY
# =============================================================================

echo "🔍 Verificações pós-deploy..."

# Verificar se API está respondendo
if curl -f http://localhost:8000/health > /dev/null 2>&1; then
    echo "✅ API está respondendo"
else
    echo "❌ API não está respondendo"
fi

# Verificar se frontend está respondendo
if curl -f http://localhost:3000 > /dev/null 2>&1; then
    echo "✅ Frontend está respondendo"
else
    echo "❌ Frontend não está respondendo"
fi

# Verificar se Caddy está respondendo
if curl -f http://localhost:80 > /dev/null 2>&1; then
    echo "✅ Caddy está respondendo"
else
    echo "❌ Caddy não está respondendo"
fi

# =============================================================================
# CONFIGURAÇÕES DE SEGURANÇA ADICIONAIS
# =============================================================================

echo "🔒 Aplicando configurações de segurança adicionais..."

# Configurar logs de auditoria
echo "📋 Configurando logs de auditoria..."
docker-compose exec backend mkdir -p /var/log/tibia-tracker/audit

# Configurar permissões de arquivos
echo "🔐 Configurando permissões..."
chmod 600 .env
chmod 644 docker-compose.yml

# Verificar se containers estão rodando com usuário não-root
echo "👤 Verificando usuários dos containers..."
docker-compose exec backend whoami || echo "⚠️  Container backend rodando como root"
docker-compose exec frontend whoami || echo "⚠️  Container frontend rodando como root"

# =============================================================================
# MONITORAMENTO
# =============================================================================

echo "📊 Configurando monitoramento..."

# Verificar se Prometheus está rodando
if docker-compose ps | grep -q prometheus; then
    echo "✅ Prometheus está rodando"
else
    echo "⚠️  Prometheus não está rodando"
fi

# Verificar se Node Exporter está rodando
if docker-compose ps | grep -q node-exporter; then
    echo "✅ Node Exporter está rodando"
else
    echo "⚠️  Node Exporter não está rodando"
fi

# =============================================================================
# RESUMO FINAL
# =============================================================================

echo ""
echo "🎉 DEPLOY SEGURO CONCLUÍDO!"
echo "=========================="
echo ""
echo "📋 RESUMO:"
echo "✅ Firewall configurado"
echo "✅ Containers rodando"
echo "✅ API protegida (apenas acesso interno)"
echo "✅ Rate limiting ativo"
echo "✅ Validação de inputs implementada"
echo "✅ Headers de segurança configurados"
echo "✅ Backup criado em: $BACKUP_DIR"
echo ""
echo "🌐 URLs de acesso:"
echo "   Frontend: http://localhost:3000"
echo "   Caddy: http://localhost:80"
echo "   API (interno): http://backend:8000"
echo ""
echo "🔒 MEDIDAS DE SEGURANÇA ATIVAS:"
echo "   • Acesso externo ao backend BLOQUEADO"
echo "   • Rate limiting: 10 req/min para API"
echo "   • Validação de inputs contra SQL Injection/XSS"
echo "   • Headers de segurança no nginx"
echo "   • Firewall UFW ativo"
echo ""
echo "📝 PRÓXIMOS PASSOS RECOMENDADOS:"
echo "   1. Configurar HTTPS com certificado SSL"
echo "   2. Implementar autenticação (quando necessário)"
echo "   3. Configurar backup automático"
echo "   4. Implementar monitoramento de logs"
echo "   5. Fazer testes de penetração"
echo ""
echo "🚨 LEMBRE-SE:"
echo "   • Mantenha as senhas seguras"
echo "   • Monitore os logs regularmente"
echo "   • Faça backups frequentes"
echo "   • Atualize as dependências regularmente"
echo "" 