#!/bin/bash

# =============================================================================
# DEPLOY COMPLETO - TIBIA TRACKER - SERVIDOR LOCAL
# =============================================================================
# Script para deploy completo executado diretamente no servidor
# Acesso via IP direto na porta 8080

set -e  # Parar em caso de erro

# =============================================================================
# CONFIGURAÇÕES
# =============================================================================
SERVER_IP="217.196.63.249"
SERVER_PORT="8080"
PROJECT_NAME="tibia-tracker"
GIT_REPO="https://github.com/canetex/TibiaTracker.git"

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
    exit 1
}

# =============================================================================
# FUNÇÕES AUXILIARES
# =============================================================================

install_system_dependencies() {
    log "Instalando dependências do sistema..."
    
    # Atualizar sistema
    apt update && apt upgrade -y
    
    # Instalar dependências básicas
    apt install -y curl wget git unzip software-properties-common apt-transport-https ca-certificates gnupg lsb-release
    
    # Instalar Docker
    if ! command -v docker &> /dev/null; then
        curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        apt update
        apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
        systemctl enable docker
        systemctl start docker
    fi
    
    # Instalar Docker Compose standalone (backup)
    if ! command -v docker-compose &> /dev/null; then
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    fi
    
    # Criar grupo docker se não existir
    if ! getent group docker > /dev/null 2>&1; then
        groupadd docker
    fi
    
    # Adicionar usuário root ao grupo docker
    usermod -aG docker root
    
    # Instalar ferramentas úteis
    apt install -y htop iotop nethogs ufw jq
    
    log "Dependências do sistema instaladas"
}

configure_firewall() {
    log "Configurando firewall..."
    
    # Habilitar UFW
    ufw --force enable
    
    # Permitir SSH
    ufw allow ssh
    
    # Permitir porta da aplicação
    ufw allow $SERVER_PORT
    
    # Permitir portas Docker (se necessário)
    ufw allow 8000
    ufw allow 3000
    
    # Verificar status
    ufw status
    
    log "Firewall configurado"
}

clone_project() {
    log "Clonando projeto..."
    
    # Remover projeto anterior se existir
    rm -rf /opt/$PROJECT_NAME
    
    # Clonar projeto
    cd /opt
    git clone $GIT_REPO $PROJECT_NAME
    cd $PROJECT_NAME
    
    # Verificar se clonou corretamente
    if [ ! -f "docker-compose.yml" ]; then
        error "Projeto não foi clonado corretamente"
    fi
    
    echo "Projeto clonado em /opt/$PROJECT_NAME"
    log "Projeto clonado"
}

configure_environment() {
    log "Configurando variáveis de ambiente..."
    cd /opt/$PROJECT_NAME
    
    # Copiar template de produção
    cp env-production.template .env
    
    # Substituir IP do servidor
    sed -i "s/YOUR_SERVER_IP/$SERVER_IP/g" .env
    
    # Configurar porta da aplicação
    sed -i "s/CADDY_PORT=80/CADDY_PORT=$SERVER_PORT/g" .env
    
    # Gerar chaves secretas
    SECRET_KEY=$(openssl rand -hex 32)
    JWT_SECRET_KEY=$(openssl rand -hex 32)
    DB_PASSWORD=$(openssl rand -base64 32)
    REDIS_PASSWORD=$(openssl rand -base64 32)
    
    # Aplicar chaves no .env
    sed -i "s/your-production-secret-key-change-this/$SECRET_KEY/g" .env
    sed -i "s/your-production-jwt-secret-key/$JWT_SECRET_KEY/g" .env
    sed -i "s/your-secure-production-db-password/$DB_PASSWORD/g" .env
    sed -i "s/your-redis-production-password/$REDIS_PASSWORD/g" .env
    
    # Configurar URLs da API
    sed -i "s|http://YOUR_SERVER_IP:8000|http://$SERVER_IP:8000|g" .env
    sed -i "s|http://YOUR_SERVER_IP|http://$SERVER_IP:$SERVER_PORT|g" .env
    
    echo "Variáveis de ambiente configuradas"
    log "Variáveis de ambiente configuradas"
}

create_custom_caddyfile() {
    log "Criando Caddyfile customizado para porta $SERVER_PORT..."
    cd /opt/$PROJECT_NAME
    
    # Criar Caddyfile customizado
    cat > custom-caddyfile << EOF
{
    admin off
    auto_https off
}

:$SERVER_PORT {
    # Frontend
    handle /* {
        reverse_proxy frontend:80
    }
    
    # API
    handle /api/* {
        reverse_proxy backend:8000
    }
    
    # Health check
    handle /health {
        reverse_proxy backend:8000
    }
    
    # Logs
    log {
        output file /var/log/caddy/access.log
        format json
    }
}
EOF

    # Atualizar docker-compose para usar o Caddyfile customizado
    sed -i 's|./Scripts/Deploy/Caddyfile:/etc/caddy/Caddyfile|custom-caddyfile:/etc/caddy/Caddyfile|g' docker-compose.yml
    
    echo "Caddyfile customizado criado"
    log "Caddyfile customizado criado"
}

build_and_deploy() {
    log "Fazendo build e deploy dos containers..."
    cd /opt/$PROJECT_NAME
    
    # Parar containers existentes
    docker-compose down --remove-orphans || true
    
    # Limpar imagens antigas
    docker system prune -f
    
    # Build e deploy
    docker-compose up -d --build
    
    # Aguardar containers subirem
    sleep 30
    
    # Verificar status
    docker-compose ps
    
    log "Build e deploy concluídos"
}

verify_deployment() {
    log "Verificando deployment..."
    cd /opt/$PROJECT_NAME
    
    # Verificar containers
    echo "=== STATUS DOS CONTAINERS ==="
    docker-compose ps
    
    # Verificar logs
    echo "=== LOGS DOS CONTAINERS ==="
    docker-compose logs --tail=20
    
    # Testar conectividade
    echo "=== TESTES DE CONECTIVIDADE ==="
    
    # Testar backend
    if curl -f http://localhost:8000/health > /dev/null 2>&1; then
        echo "✅ Backend OK"
    else
        echo "❌ Backend FAIL"
    fi
    
    # Testar frontend
    if curl -f http://localhost:3000 > /dev/null 2>&1; then
        echo "✅ Frontend OK"
    else
        echo "❌ Frontend FAIL"
    fi
    
    # Testar proxy
    if curl -f http://localhost:$SERVER_PORT > /dev/null 2>&1; then
        echo "✅ Proxy OK"
    else
        echo "❌ Proxy FAIL"
    fi
    
    log "Verificação concluída"
}

create_management_scripts() {
    log "Criando scripts de gerenciamento..."
    cd /opt/$PROJECT_NAME
    
    # Script de status
    cat > status.sh << 'EOF'
#!/bin/bash
echo "=== TIBIA TRACKER STATUS ==="
docker-compose ps
echo ""
echo "=== LOGS RECENTES ==="
docker-compose logs --tail=10
echo ""
echo "=== TESTES DE CONECTIVIDADE ==="
curl -s http://localhost:8000/health | jq . 2>/dev/null || echo "Backend não responde"
curl -s http://localhost:3000 | head -5
curl -s http://localhost:8080 | head -5
EOF
    chmod +x status.sh
    
    # Script de restart
    cat > restart.sh << 'EOF'
#!/bin/bash
echo "Reiniciando Tibia Tracker..."
docker-compose restart
sleep 10
./status.sh
EOF
    chmod +x restart.sh
    
    # Script de logs
    cat > logs.sh << 'EOF'
#!/bin/bash
docker-compose logs -f
EOF
    chmod +x logs.sh
    
    echo "Scripts de gerenciamento criados"
    log "Scripts de gerenciamento criados"
}

# =============================================================================
# EXECUÇÃO PRINCIPAL
# =============================================================================

main() {
    echo "🚀 DEPLOY COMPLETO - TIBIA TRACKER"
    echo "Servidor: $SERVER_IP"
    echo "Porta: $SERVER_PORT"
    echo "=================================="
    
    # Instalar dependências
    install_system_dependencies
    
    # Configurar firewall
    configure_firewall
    
    # Clonar projeto
    clone_project
    
    # Configurar ambiente
    configure_environment
    
    # Criar Caddyfile customizado
    create_custom_caddyfile
    
    # Build e deploy
    build_and_deploy
    
    # Verificar deployment
    verify_deployment
    
    # Criar scripts de gerenciamento
    create_management_scripts
    
    echo ""
    echo "🎉 DEPLOY CONCLUÍDO COM SUCESSO!"
    echo ""
    echo "📋 INFORMAÇÕES IMPORTANTES:"
    echo "   • URL da aplicação: http://$SERVER_IP:$SERVER_PORT"
    echo "   • API: http://$SERVER_IP:8000"
    echo "   • Documentação API: http://$SERVER_IP:8000/docs"
    echo ""
    echo "🛠️ COMANDOS ÚTEIS:"
    echo "   • Status: cd /opt/$PROJECT_NAME && ./status.sh"
    echo "   • Logs: cd /opt/$PROJECT_NAME && ./logs.sh"
    echo "   • Restart: cd /opt/$PROJECT_NAME && ./restart.sh"
    echo ""
    echo "🔧 TROUBLESHOOTING:"
    echo "   • Verificar containers: cd /opt/$PROJECT_NAME && docker-compose ps"
    echo "   • Ver logs: cd /opt/$PROJECT_NAME && docker-compose logs"
    echo "   • Rebuild: cd /opt/$PROJECT_NAME && docker-compose up -d --build"
}

# Executar se chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 