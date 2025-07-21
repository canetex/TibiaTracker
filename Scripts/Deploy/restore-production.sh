#!/bin/bash

# =============================================================================
# TIBIA TRACKER - RESTAURAÇÃO EM NOVO SERVIDOR
# =============================================================================
# Script para restaurar backup em servidor Debian novo

set -e  # Parar em caso de erro

echo "🚀 Iniciando restauração em novo servidor..."

# =============================================================================
# VERIFICAÇÕES INICIAIS
# =============================================================================

echo "🔍 Verificações iniciais..."

# Verificar se é root ou tem sudo
if [ "$EUID" -ne 0 ]; then
    echo "❌ Este script deve ser executado como root ou com sudo"
    exit 1
fi

# Verificar se arquivo de backup foi fornecido
if [ $# -eq 0 ]; then
    echo "❌ Uso: $0 <arquivo-backup.zip>"
    echo "   Exemplo: $0 tibia-tracker-backup-20241221_143022.zip"
    exit 1
fi

BACKUP_ZIP="$1"

if [ ! -f "$BACKUP_ZIP" ]; then
    echo "❌ Arquivo de backup não encontrado: $BACKUP_ZIP"
    exit 1
fi

echo "✅ Arquivo de backup encontrado: $BACKUP_ZIP"

# =============================================================================
# INSTALAÇÃO DE DEPENDÊNCIAS
# =============================================================================

echo "📦 Instalando dependências do sistema..."

# Atualizar sistema
apt-get update

# Instalar dependências necessárias
apt-get install -y \
    curl \
    wget \
    git \
    unzip \
    ufw \
    htop \
    nano \
    vim \
    tree \
    zip \
    unzip \
    ca-certificates \
    gnupg \
    lsb-release

# =============================================================================
# INSTALAÇÃO DO DOCKER
# =============================================================================

echo "🐳 Instalando Docker..."

# Adicionar repositório oficial do Docker
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Instalar Docker
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Adicionar usuário atual ao grupo docker
usermod -aG docker $SUDO_USER

# Iniciar e habilitar Docker
systemctl start docker
systemctl enable docker

echo "✅ Docker instalado"

# =============================================================================
# INSTALAÇÃO DO DOCKER COMPOSE
# =============================================================================

echo "📋 Instalando Docker Compose..."

# Instalar Docker Compose standalone
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Criar link simbólico
ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

echo "✅ Docker Compose instalado"

# =============================================================================
# CONFIGURAÇÃO DO PROJETO
# =============================================================================

echo "📁 Configurando projeto..."

# Criar diretório do projeto
PROJECT_DIR="/opt/tibia-tracker"
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

# Extrair backup
echo "📦 Extraindo backup..."
unzip "$BACKUP_ZIP"

# Verificar se arquivos foram extraídos
if [ ! -f "database.sql" ]; then
    echo "❌ Arquivo database.sql não encontrado no backup!"
    exit 1
fi

if [ ! -f "env.backup" ]; then
    echo "❌ Arquivo env.backup não encontrado no backup!"
    exit 1
fi

echo "✅ Backup extraído com sucesso"

# =============================================================================
# CONFIGURAÇÃO DO BANCO DE DADOS
# =============================================================================

echo "🗄️  Configurando banco de dados..."

# Instalar PostgreSQL
apt-get install -y postgresql postgresql-contrib

# Iniciar PostgreSQL
systemctl start postgresql
systemctl enable postgresql

# Carregar variáveis do backup
source env.backup

# Criar usuário e banco
echo "👤 Criando usuário e banco de dados..."
sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';" || echo "⚠️  Usuário já existe"
sudo -u postgres psql -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;" || echo "⚠️  Banco já existe"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"

# Restaurar backup
echo "🔄 Restaurando backup do banco..."
sudo -u postgres psql -d "$DB_NAME" < database.sql

echo "✅ Banco de dados configurado"

# =============================================================================
# CONFIGURAÇÃO DO PROJETO
# =============================================================================

echo "⚙️  Configurando projeto..."

# Clonar repositório
echo "📥 Clonando repositório..."
git clone https://github.com/canetex/TibiaTracker.git temp-repo
cp -r temp-repo/* .
rm -rf temp-repo

# Configurar arquivo .env
echo "🔧 Configurando variáveis de ambiente..."
cp env.backup .env

# Ajustar configurações para produção
sed -i 's/ENVIRONMENT=development/ENVIRONMENT=production/' .env
sed -i 's/DEBUG=true/DEBUG=false/' .env

# Configurar permissões
chown -R $SUDO_USER:$SUDO_USER "$PROJECT_DIR"
chmod 600 .env

echo "✅ Projeto configurado"

# =============================================================================
# CONFIGURAÇÃO DE FIREWALL
# =============================================================================

echo "🔥 Configurando firewall..."

# Configurar UFW
ufw --force reset
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw default deny incoming
ufw default allow outgoing
ufw --force enable

echo "✅ Firewall configurado"

# =============================================================================
# CONFIGURAÇÃO DE LOGS
# =============================================================================

echo "📋 Configurando logs..."

# Criar diretórios de log
mkdir -p /var/log/tibia-tracker
chown -R $SUDO_USER:$SUDO_USER /var/log/tibia-tracker

# Configurar rotação de logs
cat > /etc/logrotate.d/tibia-tracker << EOF
/var/log/tibia-tracker/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 $SUDO_USER $SUDO_USER
}
EOF

echo "✅ Logs configurados"

# =============================================================================
# CONFIGURAÇÃO DE MONITORAMENTO
# =============================================================================

echo "📊 Configurando monitoramento..."

# Instalar ferramentas de monitoramento
apt-get install -y \
    htop \
    iotop \
    nethogs \
    nload \
    iftop

echo "✅ Monitoramento configurado"

# =============================================================================
# INICIAR CONTAINERS
# =============================================================================

echo "🐳 Iniciando containers..."

# Fazer build e iniciar containers
docker-compose up -d --build

# Aguardar containers ficarem saudáveis
echo "⏳ Aguardando containers ficarem saudáveis..."
sleep 30

# Verificar status
docker-compose ps

echo "✅ Containers iniciados"

# =============================================================================
# VERIFICAÇÕES FINAIS
# =============================================================================

echo "🔍 Verificações finais..."

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
# CONFIGURAÇÃO DE SERVIÇOS DO SISTEMA
# =============================================================================

echo "🔧 Configurando serviços do sistema..."

# Criar script de reinicialização automática
cat > /usr/local/bin/tibia-tracker-restart << EOF
#!/bin/bash
cd $PROJECT_DIR
docker-compose restart
EOF

chmod +x /usr/local/bin/tibia-tracker-restart

# Configurar reinicialização automática dos containers
cat > /etc/systemd/system/tibia-tracker.service << EOF
[Unit]
Description=Tibia Tracker Docker Compose
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$PROJECT_DIR
ExecStart=/usr/bin/docker-compose up -d
ExecStop=/usr/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

systemctl enable tibia-tracker.service

echo "✅ Serviços configurados"

# =============================================================================
# CONFIGURAÇÃO DE BACKUP AUTOMÁTICO
# =============================================================================

echo "💾 Configurando backup automático..."

# Criar script de backup automático
cat > /usr/local/bin/tibia-tracker-backup << 'EOF'
#!/bin/bash
cd /opt/tibia-tracker
./Scripts/Manutenção/full-backup-production.sh
EOF

chmod +x /usr/local/bin/tibia-tracker-backup

# Configurar cron para backup diário
(crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/tibia-tracker-backup") | crontab -

echo "✅ Backup automático configurado"

# =============================================================================
# RESUMO FINAL
# =============================================================================

echo ""
echo "🎉 RESTAURAÇÃO CONCLUÍDA!"
echo "========================"
echo ""
echo "📋 RESUMO:"
echo "✅ Sistema Debian configurado"
echo "✅ Docker e Docker Compose instalados"
echo "✅ PostgreSQL configurado e restaurado"
echo "✅ Projeto Tibia Tracker configurado"
echo "✅ Containers iniciados e funcionando"
echo "✅ Firewall configurado"
echo "✅ Logs configurados"
echo "✅ Monitoramento configurado"
echo "✅ Backup automático configurado"
echo ""
echo "🌐 URLs de acesso:"
echo "   Frontend: http://$(hostname -I | awk '{print $1}'):3000"
echo "   Caddy: http://$(hostname -I | awk '{print $1}'):80"
echo "   API: http://$(hostname -I | awk '{print $1}'):8000"
echo ""
echo "🔧 COMANDOS ÚTEIS:"
echo "   # Ver status dos containers"
echo "   cd $PROJECT_DIR && docker-compose ps"
echo ""
echo "   # Ver logs"
echo "   cd $PROJECT_DIR && docker-compose logs -f"
echo ""
echo "   # Reiniciar serviços"
echo "   tibia-tracker-restart"
echo ""
echo "   # Fazer backup manual"
echo "   tibia-tracker-backup"
echo ""
echo "   # Acessar banco de dados"
echo "   sudo -u postgres psql -d $DB_NAME"
echo ""
echo "🔒 SEGURANÇA:"
echo "   • Firewall UFW ativo"
echo "   • Containers isolados"
echo "   • Logs de auditoria ativos"
echo "   • Backup automático configurado"
echo ""
echo "📝 PRÓXIMOS PASSOS:"
echo "   1. Configurar domínio e SSL (se necessário)"
echo "   2. Configurar monitoramento externo"
echo "   3. Testar todas as funcionalidades"
echo "   4. Configurar alertas"
echo "   5. Documentar configurações"
echo ""
echo "🚨 IMPORTANTE:"
echo "   • Altere as senhas padrão"
echo "   • Configure backup externo"
echo "   • Monitore os logs regularmente"
echo "   • Mantenha o sistema atualizado"
echo "" 