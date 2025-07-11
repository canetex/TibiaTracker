#!/bin/bash

# =============================================================================
# VERIFICAÇÃO PÓS-DEPLOY - TIBIA TRACKER
# =============================================================================
# Script para verificar se o deploy foi bem-sucedido

SERVER_IP="217.196.63.249"
SERVER_PORT="8080"
PROJECT_NAME="tibia-tracker"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

fail() {
    echo -e "${RED}❌ $1${NC}"
}

# =============================================================================
# VERIFICAÇÕES
# =============================================================================

check_ssh_connection() {
    log "Verificando conexão SSH..."
    if ssh -o ConnectTimeout=5 -o BatchMode=yes root@$SERVER_IP "echo 'OK'" 2>/dev/null; then
        success "Conexão SSH OK"
        return 0
    else
        fail "Conexão SSH falhou"
        return 1
    fi
}

check_containers() {
    log "Verificando containers..."
    ssh root@$SERVER_IP << 'EOF'
        cd /opt/tibia-tracker
        
        echo "=== STATUS DOS CONTAINERS ==="
        docker-compose ps
        
        echo ""
        echo "=== CONTAINERS RODANDO ==="
        RUNNING=$(docker-compose ps -q | wc -l)
        TOTAL=$(docker-compose ps | grep -c "Up")
        
        if [ "$RUNNING" -eq "$TOTAL" ] && [ "$TOTAL" -gt 0 ]; then
            echo "✅ Todos os containers estão rodando ($TOTAL/$TOTAL)"
        else
            echo "❌ Problema com containers ($RUNNING/$TOTAL)"
        fi
EOF
}

check_services() {
    log "Verificando serviços..."
    
    # Testar backend
    if curl -f -s "http://$SERVER_IP:8000/health" > /dev/null; then
        success "Backend API (porta 8000) OK"
    else
        fail "Backend API (porta 8000) FAIL"
    fi
    
    # Testar frontend
    if curl -f -s "http://$SERVER_IP:3000" > /dev/null; then
        success "Frontend (porta 3000) OK"
    else
        fail "Frontend (porta 3000) FAIL"
    fi
    
    # Testar proxy principal
    if curl -f -s "http://$SERVER_IP:$SERVER_PORT" > /dev/null; then
        success "Proxy principal (porta $SERVER_PORT) OK"
    else
        fail "Proxy principal (porta $SERVER_PORT) FAIL"
    fi
    
    # Testar API via proxy
    if curl -f -s "http://$SERVER_IP:$SERVER_PORT/api/v1/characters/search?name=test" > /dev/null; then
        success "API via proxy OK"
    else
        fail "API via proxy FAIL"
    fi
}

check_database() {
    log "Verificando banco de dados..."
    ssh root@$SERVER_IP << 'EOF'
        cd /opt/tibia-tracker
        
        # Verificar se PostgreSQL está rodando
        if docker-compose exec -T postgres pg_isready -U tibia_user -d tibia_tracker > /dev/null 2>&1; then
            echo "✅ PostgreSQL OK"
        else
            echo "❌ PostgreSQL FAIL"
        fi
        
        # Verificar se Redis está rodando
        if docker-compose exec -T redis redis-cli ping > /dev/null 2>&1; then
            echo "✅ Redis OK"
        else
            echo "❌ Redis FAIL"
        fi
EOF
}

check_logs() {
    log "Verificando logs..."
    ssh root@$SERVER_IP << 'EOF'
        cd /opt/tibia-tracker
        
        echo "=== LOGS RECENTES (últimas 10 linhas) ==="
        docker-compose logs --tail=10
        
        echo ""
        echo "=== ERROS RECENTES ==="
        docker-compose logs --tail=50 | grep -i error | tail -5 || echo "Nenhum erro encontrado"
EOF
}

check_performance() {
    log "Verificando performance..."
    ssh root@$SERVER_IP << 'EOF'
        echo "=== USO DE RECURSOS ==="
        echo "CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)%"
        echo "RAM: $(free -m | awk 'NR==2{printf "%.1f%%", $3*100/$2}')"
        echo "Disco: $(df -h / | awk 'NR==2{print $5}')"
        
        echo ""
        echo "=== CONTAINERS (CPU/MEM) ==="
        docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"
EOF
}

check_network() {
    log "Verificando conectividade de rede..."
    
    # Testar conectividade externa
    if ssh root@$SERVER_IP "ping -c 1 8.8.8.8 > /dev/null 2>&1"; then
        success "Conectividade externa OK"
    else
        fail "Conectividade externa FAIL"
    fi
    
    # Testar DNS
    if ssh root@$SERVER_IP "nslookup google.com > /dev/null 2>&1"; then
        success "DNS OK"
    else
        fail "DNS FAIL"
    fi
    
    # Verificar portas abertas
    ssh root@$SERVER_IP << EOF
        echo "=== PORTAS ABERTAS ==="
        netstat -tlnp | grep -E ':(22|$SERVER_PORT|8000|3000|5432|6379|9090)' || echo "Nenhuma porta relevante encontrada"
EOF
}

generate_report() {
    log "Gerando relatório de verificação..."
    
    echo ""
    echo "📊 RELATÓRIO DE VERIFICAÇÃO - TIBIA TRACKER"
    echo "=========================================="
    echo "Data: $(date)"
    echo "Servidor: $SERVER_IP"
    echo "Porta: $SERVER_PORT"
    echo ""
    
    # URLs de acesso
    echo "🌐 URLs de Acesso:"
    echo "   • Aplicação: http://$SERVER_IP:$SERVER_PORT"
    echo "   • API: http://$SERVER_IP:8000"
    echo "   • API Docs: http://$SERVER_IP:8000/docs"
    echo "   • Prometheus: http://$SERVER_IP:9090"
    echo ""
    
    # Comandos úteis
    echo "🛠️ Comandos Úteis:"
    echo "   • Status: ssh root@$SERVER_IP 'cd /opt/$PROJECT_NAME && ./status.sh'"
    echo "   • Logs: ssh root@$SERVER_IP 'cd /opt/$PROJECT_NAME && ./logs.sh'"
    echo "   • Restart: ssh root@$SERVER_IP 'cd /opt/$PROJECT_NAME && ./restart.sh'"
    echo ""
    
    # Troubleshooting
    echo "🔧 Troubleshooting:"
    echo "   • Ver containers: ssh root@$SERVER_IP 'cd /opt/$PROJECT_NAME && docker-compose ps'"
    echo "   • Ver logs: ssh root@$SERVER_IP 'cd /opt/$PROJECT_NAME && docker-compose logs'"
    echo "   • Rebuild: ssh root@$SERVER_IP 'cd /opt/$PROJECT_NAME && docker-compose up -d --build'"
    echo ""
}

# =============================================================================
# EXECUÇÃO PRINCIPAL
# =============================================================================

main() {
    echo "🔍 VERIFICAÇÃO PÓS-DEPLOY - TIBIA TRACKER"
    echo "Servidor: $SERVER_IP"
    echo "Porta: $SERVER_PORT"
    echo "=========================================="
    
    # Verificar conexão SSH
    if ! check_ssh_connection; then
        error "Não foi possível conectar ao servidor. Abortando verificação."
        exit 1
    fi
    
    # Executar verificações
    check_containers
    echo ""
    
    check_services
    echo ""
    
    check_database
    echo ""
    
    check_logs
    echo ""
    
    check_performance
    echo ""
    
    check_network
    echo ""
    
    # Gerar relatório
    generate_report
    
    echo "🎉 Verificação concluída!"
    echo ""
    echo "💡 Dica: Se algum serviço não estiver funcionando, execute:"
    echo "   ssh root@$SERVER_IP 'cd /opt/$PROJECT_NAME && docker-compose logs'"
}

# Executar se chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 