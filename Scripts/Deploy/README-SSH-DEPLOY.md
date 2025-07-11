# 🚀 DEPLOY COMPLETO - TIBIA TRACKER - SERVIDOR SSH

## 📋 Visão Geral

Este guia descreve como fazer o deploy completo da aplicação Tibia Tracker no servidor SSH `217.196.63.249` com acesso via IP direto na porta `8080`.

## 🎯 Objetivo

- Deploy automatizado via SSH
- Acesso via IP direto na porta 8080
- Configuração completa de todos os serviços
- Scripts de gerenciamento automáticos

## 🏗️ Arquitetura

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Cliente Web   │───▶│   Caddy Proxy   │───▶│   Frontend      │
│                 │    │   Porta 8080    │    │   Porta 3000    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                              │
                              ▼
                       ┌─────────────────┐    ┌─────────────────┐
                       │   Backend API   │───▶│   PostgreSQL    │
                       │   Porta 8000    │    │   Porta 5432    │
                       └─────────────────┘    └─────────────────┘
                              │
                              ▼
                       ┌─────────────────┐
                       │   Redis Cache   │
                       │   Porta 6379    │
                       └─────────────────┘
```

## 📦 Componentes

- **Frontend**: React + Nginx (porta 3000)
- **Backend**: FastAPI (porta 8000)
- **Database**: PostgreSQL (porta 5432)
- **Cache**: Redis (porta 6379)
- **Proxy**: Caddy (porta 8080)
- **Monitoramento**: Prometheus (porta 9090)

## 🚀 Deploy Automatizado

### Pré-requisitos

1. **Acesso SSH configurado**
   ```bash
   # Testar conexão
   ssh root@217.196.63.249
   ```

2. **Chave SSH configurada** (recomendado)
   ```bash
   # Gerar chave SSH (se necessário)
   ssh-keygen -t rsa -b 4096
   
   # Copiar para servidor
   ssh-copy-id root@217.196.63.249
   ```

### Executar Deploy

```bash
# 1. Tornar script executável
chmod +x Scripts/Deploy/deploy-complete-ssh.sh

# 2. Executar deploy completo
./Scripts/Deploy/deploy-complete-ssh.sh
```

### O que o script faz

1. ✅ **Verifica conexão SSH**
2. ✅ **Instala dependências do sistema**
   - Docker e Docker Compose
   - Ferramentas de sistema
3. ✅ **Configura firewall**
   - Porta 8080 (aplicação)
   - Porta 22 (SSH)
   - Portas Docker internas
4. ✅ **Clona o projeto**
   - Remove versão anterior
   - Clona do repositório
5. ✅ **Configura ambiente**
   - Copia template de produção
   - Substitui IP do servidor
   - Gera chaves secretas
6. ✅ **Cria Caddyfile customizado**
   - Configura proxy na porta 8080
   - Roteia frontend e API
7. ✅ **Build e deploy**
   - Para containers existentes
   - Build das imagens
   - Deploy dos serviços
8. ✅ **Verifica deployment**
   - Status dos containers
   - Testes de conectividade
9. ✅ **Cria scripts de gerenciamento**
   - `status.sh` - Status da aplicação
   - `logs.sh` - Visualizar logs
   - `restart.sh` - Reiniciar serviços

## 🔍 Verificação Pós-Deploy

```bash
# Executar verificação completa
chmod +x Scripts/Deploy/verify-deployment.sh
./Scripts/Deploy/verify-deployment.sh
```

### Verificações realizadas

- ✅ **Conexão SSH**
- ✅ **Status dos containers**
- ✅ **Conectividade dos serviços**
- ✅ **Banco de dados**
- ✅ **Logs da aplicação**
- ✅ **Performance do sistema**
- ✅ **Conectividade de rede**

## 🌐 URLs de Acesso

Após o deploy bem-sucedido:

- **🎯 Aplicação Principal**: `http://217.196.63.249:8080`
- **🔧 API Backend**: `http://217.196.63.249:8000`
- **📚 Documentação API**: `http://217.196.63.249:8000/docs`
- **📊 Prometheus**: `http://217.196.63.249:9090`

## 🛠️ Gerenciamento

### Comandos Úteis

```bash
# Status da aplicação
ssh root@217.196.63.249 'cd /opt/tibia-tracker && ./status.sh'

# Visualizar logs
ssh root@217.196.63.249 'cd /opt/tibia-tracker && ./logs.sh'

# Reiniciar serviços
ssh root@217.196.63.249 'cd /opt/tibia-tracker && ./restart.sh'

# Ver containers
ssh root@217.196.63.249 'cd /opt/tibia-tracker && docker-compose ps'

# Ver logs específicos
ssh root@217.196.63.249 'cd /opt/tibia-tracker && docker-compose logs backend'
```

### Troubleshooting

```bash
# Rebuild completo
ssh root@217.196.63.249 'cd /opt/tibia-tracker && docker-compose down && docker-compose up -d --build'

# Ver logs de erro
ssh root@217.196.63.249 'cd /opt/tibia-tracker && docker-compose logs | grep -i error'

# Verificar recursos
ssh root@217.196.63.249 'htop'

# Verificar portas
ssh root@217.196.63.249 'netstat -tlnp | grep -E ":(22|8080|8000|3000)"'
```

## 🔧 Configurações Específicas

### Firewall (UFW)

O script configura automaticamente:

```bash
# Portas permitidas
- 22 (SSH)
- 8080 (Aplicação principal)
- 8000 (API - interno)
- 3000 (Frontend - interno)
```

### Variáveis de Ambiente

O script gera automaticamente:

```bash
# Chaves secretas
SECRET_KEY=<gerado automaticamente>
JWT_SECRET_KEY=<gerado automaticamente>
DB_PASSWORD=<gerado automaticamente>
REDIS_PASSWORD=<gerado automaticamente>

# URLs configuradas
REACT_APP_API_URL="http://217.196.63.249:8000"
BASE_URL="http://217.196.63.249:8080"
```

### Caddyfile Customizado

```caddyfile
{
    admin off
    auto_https off
}

:8080 {
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
}
```

## 📊 Monitoramento

### Prometheus

- **URL**: `http://217.196.63.249:9090`
- **Métricas coletadas**:
  - Performance dos containers
  - Uso de recursos do sistema
  - Métricas da aplicação

### Logs

- **Localização**: `/opt/tibia-tracker/`
- **Comando**: `docker-compose logs -f`
- **Logs específicos**: `docker-compose logs [serviço]`

## 🔒 Segurança

### Configurações aplicadas

- ✅ **Firewall habilitado** (UFW)
- ✅ **Chaves secretas geradas** automaticamente
- ✅ **HTTPS desabilitado** (acesso via IP)
- ✅ **Admin Caddy desabilitado**
- ✅ **Containers isolados** em rede Docker

### Recomendações adicionais

```bash
# Alterar senha root
ssh root@217.196.63.249 'passwd'

# Configurar fail2ban (opcional)
ssh root@217.196.63.249 'apt install -y fail2ban'

# Configurar backup automático (recomendado)
# Criar script de backup do banco de dados
```

## 🚨 Troubleshooting Avançado

### Problema: Containers não sobem

```bash
# Verificar logs detalhados
ssh root@217.196.63.249 'cd /opt/tibia-tracker && docker-compose logs'

# Verificar recursos do sistema
ssh root@217.196.63.249 'free -h && df -h'

# Rebuild forçado
ssh root@217.196.63.249 'cd /opt/tibia-tracker && docker-compose down && docker system prune -f && docker-compose up -d --build'
```

### Problema: API não responde

```bash
# Verificar backend
ssh root@217.196.63.249 'cd /opt/tibia-tracker && docker-compose logs backend'

# Testar conectividade interna
ssh root@217.196.63.249 'curl -f http://localhost:8000/health'

# Verificar banco de dados
ssh root@217.196.63.249 'cd /opt/tibia-tracker && docker-compose exec postgres pg_isready -U tibia_user'
```

### Problema: Frontend não carrega

```bash
# Verificar frontend
ssh root@217.196.63.249 'cd /opt/tibia-tracker && docker-compose logs frontend'

# Testar conectividade interna
ssh root@217.196.63.249 'curl -f http://localhost:3000'

# Verificar nginx
ssh root@217.196.63.249 'cd /opt/tibia-tracker && docker-compose exec frontend nginx -t'
```

## 📞 Suporte

### Informações do Sistema

```bash
# Status completo
ssh root@217.196.63.249 'cd /opt/tibia-tracker && ./status.sh'

# Informações do sistema
ssh root@217.196.63.249 'uname -a && cat /etc/os-release'

# Versões dos componentes
ssh root@217.196.63.249 'docker --version && docker-compose --version'
```

### Logs Importantes

- **Aplicação**: `/opt/tibia-tracker/` (via `docker-compose logs`)
- **Sistema**: `/var/log/`
- **Docker**: `docker system logs`

---

## 🎉 Resultado Esperado

Após seguir este guia, você terá:

- ✅ **Aplicação acessível via**: `http://217.196.63.249:8080`
- ✅ **Todos os containers rodando**
- ✅ **API funcionando corretamente**
- ✅ **Banco de dados operacional**
- ✅ **Cache Redis funcionando**
- ✅ **Monitoramento ativo**
- ✅ **Scripts de gerenciamento disponíveis**

**Status**: 🎉 **APLICAÇÃO 100% FUNCIONAL**

---

*📝 Deploy automatizado para servidor SSH - Tibia Tracker* 