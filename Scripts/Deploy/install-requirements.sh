#!/bin/bash

# =============================================================================
# TIBIA TRACKER - INSTALAÇÃO DE REQUISITOS
# =============================================================================
# Este script instala todos os requisitos necessários em um LXC Debian limpo
# Autor: Tibia Tracker Team
# Data: $(date +'%Y-%m-%d')
# =============================================================================

set -euo pipefail

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# =============================================================================
# FUNÇÕES AUXILIARES
# =============================================================================

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR $(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING $(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO $(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

# =============================================================================
# VERIFICAÇÕES INICIAIS
# =============================================================================

check_system() {
    log "Verificando sistema..."
    
    # Verificar se é Debian/Ubuntu
    if ! grep -qi "debian\|ubuntu" /etc/os-release; then
        error "Este script é para sistemas Debian/Ubuntu"
    fi
    
    # Verificar se é root
    if [[ $EUID -ne 0 ]]; then
        error "Este script precisa ser executado como root"
    fi
    
    # Verificar conexão com internet
    if ! ping -c 1 google.com &> /dev/null; then
        error "Sem conexão com a internet"
    fi
    
    log "Verificações iniciais concluídas!"
}

# =============================================================================
# ATUALIZAÇÃO DO SISTEMA
# =============================================================================

update_system() {
    log "Atualizando sistema..."
    
    export DEBIAN_FRONTEND=noninteractive
    
    apt-get update
    apt-get upgrade -y
    apt-get autoremove -y
    apt-get autoclean
    
    log "Sistema atualizado!"
}

# =============================================================================
# INSTALAÇÃO DE PACOTES BÁSICOS
# =============================================================================

install_basic_packages() {
    log "Instalando pacotes básicos..."
    
    apt-get install -y \
        curl \
        wget \
        gnupg \
        lsb-release \
        software-properties-common \
        apt-transport-https \
        ca-certificates \
        build-essential \
        git \
        vim \
        nano \
        htop \
        ufw \
        fail2ban \
        logrotate \
        cron \
        rsync \
        zip \
        unzip \
        jq \
        tree \
        net-tools \
        dnsutils
    
    log "Pacotes básicos instalados!"
}

# =============================================================================
# INSTALAÇÃO DO DOCKER
# =============================================================================

install_docker() {
    log "Instalando Docker..."
    
    # Remover versões antigas se existirem
    apt-get remove -y docker docker-engine docker.io containerd runc || true
    
    # Adicionar repositório oficial do Docker
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Atualizar repositórios e instalar Docker
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io
    
    # Habilitar e iniciar Docker
    systemctl enable docker
    systemctl start docker
    
    # Verificar instalação
    docker --version
    
    log "Docker instalado com sucesso!"
}

# =============================================================================
# INSTALAÇÃO DO DOCKER COMPOSE
# =============================================================================

install_docker_compose() {
    log "Instalando Docker Compose..."
    
    # Obter última versão
    DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name)
    
    # Download do Docker Compose
    curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    
    # Dar permissão de execução
    chmod +x /usr/local/bin/docker-compose
    
    # Criar link simbólico
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    
    # Verificar instalação
    docker-compose --version
    
    log "Docker Compose instalado com sucesso!"
}

# =============================================================================
# INSTALAÇÃO DO NODE.JS
# =============================================================================

install_nodejs() {
    log "Instalando Node.js..."
    
    # Adicionar repositório NodeSource para Node.js 18
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    
    # Instalar Node.js
    apt-get install -y nodejs
    
    # Verificar instalação
    node --version
    npm --version
    
    # Atualizar npm para a última versão
    npm install -g npm@latest
    
    log "Node.js instalado com sucesso!"
}

# =============================================================================
# INSTALAÇÃO DO PYTHON
# =============================================================================

install_python() {
    log "Instalando Python e dependências..."
    
    apt-get install -y \
        python3 \
        python3-pip \
        python3-venv \
        python3-dev \
        python3-setuptools \
        python3-wheel
    
    # Atualizar pip
    python3 -m pip install --upgrade pip
    
    # Verificar instalação
    python3 --version
    pip3 --version
    
    log "Python instalado com sucesso!"
}

# =============================================================================
# CONFIGURAÇÃO DE USUÁRIOS E PERMISSÕES
# =============================================================================

setup_users() {
    log "Configurando usuários e permissões..."
    
    # Criar usuário para a aplicação se não existir
    if ! id "tibia-tracker" &>/dev/null; then
        useradd -r -s /bin/false -d /opt/tibia-tracker tibia-tracker
        log "Usuário tibia-tracker criado"
    fi
    
    # Adicionar usuário tibia-tracker ao grupo docker
    usermod -aG docker tibia-tracker
    
    # Criar diretórios necessários
    mkdir -p /opt/tibia-tracker
    mkdir -p /var/log/tibia-tracker
    mkdir -p /opt/backups/tibia-tracker
    
    # Definir permissões
    chown -R tibia-tracker:tibia-tracker /opt/tibia-tracker
    chown -R tibia-tracker:tibia-tracker /var/log/tibia-tracker
    chown -R tibia-tracker:tibia-tracker /opt/backups/tibia-tracker
    
    chmod 755 /opt/tibia-tracker
    chmod 755 /var/log/tibia-tracker
    chmod 755 /opt/backups/tibia-tracker
    
    log "Usuários e permissões configurados!"
}

# =============================================================================
# CONFIGURAÇÃO DE SEGURANÇA BÁSICA
# =============================================================================

setup_security() {
    log "Configurando segurança básica..."
    
    # Configurar UFW (firewall)
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow ssh
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw --force enable
    
    # Configurar fail2ban
    systemctl enable fail2ban
    systemctl start fail2ban
    
    # Configurar logrotate para aplicação
    cat > /etc/logrotate.d/tibia-tracker << 'EOF'
/var/log/tibia-tracker/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 tibia-tracker tibia-tracker
    postrotate
        systemctl reload tibia-tracker || true
    endscript
}
EOF
    
    log "Segurança básica configurada!"
}

# =============================================================================
# CONFIGURAÇÃO DE MONITORAMENTO BÁSICO
# =============================================================================

setup_monitoring() {
    log "Configurando monitoramento básico..."
    
    # Instalar ferramentas de monitoramento
    apt-get install -y \
        sysstat \
        iotop \
        nethogs \
        ncdu
    
    # Habilitar coleta de estatísticas
    sed -i 's/ENABLED="false"/ENABLED="true"/' /etc/default/sysstat
    systemctl enable sysstat
    systemctl start sysstat
    
    log "Monitoramento básico configurado!"
}

# =============================================================================
# LIMPEZA FINAL
# =============================================================================

cleanup() {
    log "Realizando limpeza final..."
    
    apt-get autoremove -y
    apt-get autoclean
    docker system prune -f
    
    log "Limpeza concluída!"
}

# =============================================================================
# FUNÇÃO PRINCIPAL
# =============================================================================

main() {
    log "=== INICIANDO INSTALAÇÃO DE REQUISITOS ==="
    
    check_system
    update_system
    install_basic_packages
    install_docker
    install_docker_compose
    install_nodejs
    install_python
    setup_users
    setup_security
    setup_monitoring
    cleanup
    
    log "=== INSTALAÇÃO CONCLUÍDA COM SUCESSO ==="
    
    info "Requisitos instalados:"
    info "  ✓ Docker $(docker --version | cut -d' ' -f3 | cut -d',' -f1)"
    info "  ✓ Docker Compose $(docker-compose --version | cut -d' ' -f3 | cut -d',' -f1)"
    info "  ✓ Node.js $(node --version)"
    info "  ✓ Python $(python3 --version | cut -d' ' -f2)"
    info "  ✓ Git $(git --version | cut -d' ' -f3)"
    
    warning "IMPORTANTE: Reinicie o sistema antes de executar o deploy!"
    warning "Comando: sudo reboot"
}

# =============================================================================
# EXECUÇÃO
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 