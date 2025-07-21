# 🚀 DEPLOY EM PRODUÇÃO - TIBIA TRACKER

## 📋 **VISÃO GERAL**

Este documento descreve o processo completo para fazer deploy do Tibia Tracker em um novo servidor Debian com todas as medidas de segurança implementadas.

## 🔒 **MEDIDAS DE SEGURANÇA IMPLEMENTADAS**

### **✅ Proteção de Rede**
- **Acesso externo ao backend BLOQUEADO** - apenas containers Docker podem acessar
- **Firewall UFW configurado** - apenas portas 22, 80, 443 abertas
- **CORS restrito** - apenas frontend pode acessar API
- **TrustedHost middleware** - apenas hosts confiáveis permitidos

### **✅ Rate Limiting**
- **API**: 10 requests/minuto para endpoints críticos
- **Nginx**: 10 requests/segundo para API, 30 para geral
- **Detecção de atividade suspeita** - bloqueio automático de IPs

### **✅ Validação de Inputs**
- **Sanitização de strings** - remoção de caracteres perigosos
- **Validação de nomes** - apenas letras, números e espaços
- **Validação de servidores** - lista branca de servidores válidos
- **Prevenção de SQL Injection** - uso de ORM com parâmetros

### **✅ Headers de Segurança**
- **Content-Security-Policy** - proteção contra XSS
- **X-Frame-Options** - proteção contra clickjacking
- **X-Content-Type-Options** - proteção contra MIME sniffing
- **Strict-Transport-Security** - forçar HTTPS

## 📦 **PRÉ-REQUISITOS**

### **Servidor Atual (Origem)**
- Docker e Docker Compose instalados
- Acesso SSH ao servidor
- Git configurado

### **Novo Servidor (Destino)**
- Debian 11+ (Bullseye) ou superior
- Acesso root ou sudo
- Conexão à internet
- Mínimo 2GB RAM, 20GB disco

## 🔄 **PROCESSO DE MIGRAÇÃO**

### **1. CRIAR BACKUP COMPLETO**

```bash
# No servidor atual
cd /opt/tibia-tracker

# Executar script de backup
chmod +x Scripts/Manutenção/full-backup-production.sh
./Scripts/Manutenção/full-backup-production.sh
```

**O script irá:**
- ✅ Criar backup completo do PostgreSQL
- ✅ Incluir configurações (.env, docker-compose.yml)
- ✅ Incluir imagens de outfits
- ✅ Incluir logs e estatísticas
- ✅ Gerar arquivo ZIP com metadados
- ✅ Verificar integridade do backup

### **2. TRANSFERIR BACKUP**

```bash
# Transferir arquivo ZIP para novo servidor
scp backups/production/tibia-tracker-backup-*.zip user@novo-servidor:/tmp/

# Ou usar SFTP
sftp user@novo-servidor
put backups/production/tibia-tracker-backup-*.zip /tmp/
```

### **3. CONFIGURAR NOVO SERVIDOR**

```bash
# No novo servidor
sudo su -

# Executar script de restauração
chmod +x Scripts/Deploy/restore-production.sh
./Scripts/Deploy/restore-production.sh /tmp/tibia-tracker-backup-*.zip
```

**O script irá:**
- ✅ Instalar Docker e Docker Compose
- ✅ Configurar PostgreSQL
- ✅ Restaurar backup do banco
- ✅ Configurar firewall UFW
- ✅ Configurar logs e monitoramento
- ✅ Iniciar containers
- ✅ Configurar backup automático

## 🔧 **CONFIGURAÇÕES PÓS-DEPLOY**

### **1. VERIFICAR FUNCIONAMENTO**

```bash
# Verificar status dos containers
cd /opt/tibia-tracker
docker-compose ps

# Verificar logs
docker-compose logs -f

# Testar endpoints
curl http://localhost:8000/health
curl http://localhost:3000
```

### **2. CONFIGURAR DOMÍNIO (OPCIONAL)**

```bash
# Editar Caddyfile
nano Scripts/Deploy/Caddyfile

# Configurar domínio
echo "seudominio.com {
    reverse_proxy frontend:80
    reverse_proxy /api/* backend:8000
}"
```

### **3. CONFIGURAR SSL (OPCIONAL)**

```bash
# O Caddy irá configurar SSL automaticamente
# Apenas certifique-se de que o domínio está apontando para o servidor
```

## 📊 **MONITORAMENTO**

### **Comandos Úteis**

```bash
# Status dos containers
tibia-tracker-restart

# Backup manual
tibia-tracker-backup

# Ver logs em tempo real
docker-compose logs -f backend

# Acessar banco de dados
sudo -u postgres psql -d tibia_tracker

# Monitorar recursos
htop
docker stats
```

### **Logs Importantes**

```bash
# Logs da aplicação
tail -f /var/log/tibia-tracker/app.log

# Logs do Docker
docker-compose logs -f

# Logs do sistema
journalctl -u docker
journalctl -u postgresql
```

## 🔒 **SEGURANÇA ADICIONAL**

### **1. ALTERAR SENHAS PADRÃO**

```bash
# Alterar senha do PostgreSQL
sudo -u postgres psql
ALTER USER tibia_user PASSWORD 'nova-senha-segura';

# Alterar SECRET_KEY no .env
nano /opt/tibia-tracker/.env
```

### **2. CONFIGURAR BACKUP EXTERNO**

```bash
# Configurar backup para servidor externo
# Exemplo com rsync
rsync -avz /opt/tibia-tracker/backups/ user@backup-server:/backups/tibia-tracker/
```

### **3. MONITORAMENTO DE SEGURANÇA**

```bash
# Verificar tentativas de acesso
grep "suspicious" /var/log/tibia-tracker/app.log

# Verificar IPs bloqueados
docker-compose exec backend python -c "from app.core.security import security_middleware; print(security_middleware.blocked_ips)"
```

## 🚨 **TROUBLESHOOTING**

### **Problemas Comuns**

#### **1. Containers não iniciam**
```bash
# Verificar logs
docker-compose logs

# Verificar recursos
docker system df
docker system prune -f
```

#### **2. Banco não conecta**
```bash
# Verificar PostgreSQL
sudo systemctl status postgresql
sudo -u postgres psql -l

# Verificar variáveis de ambiente
cat /opt/tibia-tracker/.env | grep DB_
```

#### **3. API não responde**
```bash
# Verificar se backend está rodando
docker-compose ps backend

# Verificar logs do backend
docker-compose logs backend

# Testar conectividade interna
docker-compose exec frontend curl http://backend:8000/health
```

#### **4. Firewall bloqueando**
```bash
# Verificar regras UFW
ufw status

# Permitir porta específica (se necessário)
ufw allow 8000/tcp
```

## 📝 **MANUTENÇÃO**

### **Atualizações**

```bash
# Atualizar código
cd /opt/tibia-tracker
git pull origin production-adjusts

# Reconstruir containers
docker-compose down
docker-compose up -d --build
```

### **Backup Regular**

```bash
# Backup automático (configurado via cron)
# Executa diariamente às 2:00 AM

# Backup manual
tibia-tracker-backup
```

### **Limpeza**

```bash
# Limpar logs antigos
find /var/log/tibia-tracker -name "*.log" -mtime +30 -delete

# Limpar imagens Docker antigas
docker system prune -f

# Limpar backups antigos (mantém últimos 5)
ls -t /opt/tibia-tracker/backups/production/*.zip | tail -n +6 | xargs rm -f
```

## 📞 **SUPORTE**

### **Informações de Contato**
- **Repositório**: https://github.com/canetex/TibiaTracker
- **Branch de Produção**: `production-adjusts`
- **Documentação**: Este arquivo e README.md

### **Logs de Debug**
```bash
# Ativar logs detalhados
export LOG_LEVEL=DEBUG
docker-compose restart backend

# Ver logs em tempo real
docker-compose logs -f backend
```

---

## 🎯 **CHECKLIST DE DEPLOY**

- [ ] Backup completo criado
- [ ] Arquivo ZIP transferido para novo servidor
- [ ] Script de restauração executado
- [ ] Containers iniciados e funcionando
- [ ] Firewall configurado
- [ ] Logs configurados
- [ ] Backup automático configurado
- [ ] Senhas alteradas
- [ ] Domínio configurado (se aplicável)
- [ ] SSL configurado (se aplicável)
- [ ] Monitoramento ativo
- [ ] Testes realizados
- [ ] Documentação atualizada

**✅ Deploy concluído com sucesso!** 