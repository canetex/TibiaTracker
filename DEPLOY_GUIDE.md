# 🚀 GUIA RÁPIDO DE DEPLOY - TIBIA TRACKER

## ✅ PRÉ-REQUISITOS

### 1. Servidor LXC/VM Debian 12
```bash
# Instalar requisitos básicos
sudo ./Scripts/Deploy/install-requirements.sh
sudo reboot
```

### 2. Código do Projeto
```bash
# Baixar código
git clone https://github.com/seu-usuario/TibiaTracker.git
cd TibiaTracker

# OU download direto
wget https://github.com/seu-usuario/TibiaTracker/archive/refs/heads/main.zip
unzip main.zip && cd TibiaTracker-main
```

## 🔧 CONFIGURAÇÃO (NOVO - SIMPLIFICADO)

### Para Servidor/Produção (Recomendado)
```bash
# Copiar template corrigido
cp env-production.template .env

# Substituir IP do servidor (exemplo: 192.168.1.227)
sed -i 's/YOUR_SERVER_IP/192.168.1.227/g' .env

# Verificar se aplicou corretamente
grep "192.168.1.227" .env
```

### Para Desenvolvimento Local
```bash
# Copiar template local
cp env.template .env
```

## 🚀 DEPLOY

### Deploy Completo
```bash
# Executar deploy automatizado
sudo ./Scripts/Deploy/deploy.sh
```

## ✅ VERIFICAÇÃO

### Teste de Funcionamento
```bash
# Verificar containers
sudo docker-compose ps

# Health check completo
sudo ./Scripts/Verificação/health-check.sh

# Testar endpoints
curl http://SEU_IP:8000/health     # Backend
curl http://SEU_IP:3000            # Frontend
curl http://SEU_IP:9090            # Prometheus
```

### URLs de Acesso
- **Frontend**: `http://SEU_IP:3000`
- **Backend API**: `http://SEU_IP:8000`
- **API Docs**: `http://SEU_IP:8000/docs`
- **Prometheus**: `http://SEU_IP:9090`

## 🛠️ MANUTENÇÃO

### Comandos Úteis
```bash
# Health check completo
sudo ./Scripts/Verificação/health-check.sh

# Rebuild containers
sudo ./Scripts/Manutenção/rebuild-containers.sh

# Limpeza de cache
sudo ./Scripts/Manutenção/clear-cache.sh

# Refresh banco
sudo ./Scripts/Manutenção/refresh-database.sh

# Logs da aplicação
sudo docker-compose logs -f
```

## 🎯 O QUE FOI CORRIGIDO

### ✅ Problemas Resolvidos Automaticamente
- ❌ "Invalid host header" - **CORRIGIDO**
- ❌ Erro parsing Pydantic CORS - **CORRIGIDO**
- ❌ Hosts incorretos banco/redis - **CORRIGIDO**
- ❌ Driver PostgreSQL incompatível - **CORRIGIDO**
- ❌ Quebras de linha Windows - **PREVENIDO**

### ✅ Templates Prontos
- ✅ `ENVIRONMENT=development` (permite acesso externo)
- ✅ `ALLOWED_HOSTS` com IPs Docker (172.18.0.1-6)
- ✅ Configurações corretas banco/redis
- ✅ Formato CORS compatível

## 🚨 TROUBLESHOOTING

### Problema: Containers não sobem
```bash
# Ver logs de erro
sudo docker-compose logs

# Rebuild forçado
sudo ./Scripts/Manutenção/rebuild-containers.sh clean
```

### Problema: API não responde
```bash
# Verificar backend
sudo docker-compose logs backend

# Health check
sudo ./Scripts/Verificação/health-check.sh
```

### Problema: Frontend não carrega
```bash
# Verificar frontend
sudo docker-compose logs frontend

# Verificar nginx
sudo docker-compose exec frontend nginx -t
```

## 📞 SUPORTE

### Informações do Sistema
```bash
# Status completo
sudo ./Scripts/Verificação/health-check.sh

# Teste de rede
sudo ./Scripts/Verificação/network-test.sh

# Logs específicos
tail -f /var/log/tibia-tracker/*.log
```

### Logs Importantes
- **Aplicação**: `/var/log/tibia-tracker/`
- **Deploy**: `/var/log/tibia-tracker/deploy.log`
- **Health Check**: `/var/log/tibia-tracker/health-check.log`

---

## 🎉 RESULTADO ESPERADO

Após seguir este guia, você deve ter:

- ✅ **Todos os containers rodando**
- ✅ **Frontend acessível via browser**
- ✅ **API respondendo corretamente**
- ✅ **Prometheus coletando métricas**
- ✅ **Banco PostgreSQL funcionando**
- ✅ **Cache Redis operacional**

**Status esperado**: 🎉 **APLICAÇÃO 100% FUNCIONAL**

---

*📝 Baseado no deploy real realizado em 2025-06-27 no servidor 192.168.1.227* 