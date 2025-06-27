# 🔧 Correções Aplicadas para Deploy em Produção

## Resumo

Este documento lista todas as correções aplicadas nos arquivos locais para garantir que futuros deploys não enfrentem os mesmos problemas encontrados durante o deploy inicial.

## 📋 Correções Aplicadas

### 1. **env.template**
- ✅ Adicionadas aspas duplas em variáveis com caracteres especiais
- ✅ Corrigido `DB_HOST` de `localhost` para `postgres` (nome do container)
- ✅ Corrigido `REDIS_HOST` de `localhost` para `redis` (nome do container)  
- ✅ Atualizada `DATABASE_URL` para usar `postgresql+asyncpg://` (driver assíncrono)

### 2. **docker-compose.yml**
- ✅ Removida versão obsoleta `version: '3.8'`
- ✅ Adicionadas variáveis de ambiente do banco no backend:
  - `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`

### 3. **Backend/requirements.txt**
- ✅ Substituído `psycopg2-binary==2.9.9` por `asyncpg==0.29.0`

### 4. **Backend/app/services/scheduler.py**
- ✅ Corrigido `day_of_week='sunday'` para `day_of_week='sun'`

### 5. **Frontend/nginx.conf**
- ✅ Reescrito completamente com estrutura correta
- ✅ Removidos blocos `location` mal posicionados
- ✅ Adicionado proxy para API e configurações de cache

### 6. **Scripts/Deploy/prometheus.yml**
- ✅ Arquivo criado com configuração de monitoramento
- ✅ Jobs configurados para todos os serviços

### 7. **Scripts/Deploy/Caddyfile**
- ✅ Arquivo criado com configuração de proxy reverso
- ✅ Headers de segurança configurados
- ✅ SSL automático configurado

### 8. **Scripts de Log**
- ✅ Função `log()` corrigida em todos os scripts para criar diretórios automaticamente
- ✅ Previne erros por diretórios de log inexistentes

### 9. **Backend/sql/init.sql**
- ✅ Arquivo criado para inicialização do PostgreSQL
- ✅ Extensões e configurações básicas

## 🚀 Resultado

Com essas correções aplicadas, futuros deploys devem executar sem os seguintes problemas:

1. ❌ Erro de sintaxe shell no arquivo `.env`
2. ❌ Variáveis de ambiente não encontradas no backend  
3. ❌ Driver PostgreSQL incompatível com SQLAlchemy async
4. ❌ Conexões recusadas por hosts incorretos
5. ❌ Scheduler falhando por nome de dia inválido
6. ❌ Frontend falhando por nginx.conf malformado
7. ❌ Scripts falhando por diretórios de log inexistentes
8. ❌ Arquivos de configuração faltantes

## 📝 Notas para Deploy

1. **Arquivo .env**: Sempre criar baseado no `env.template` corrigido
2. **Hosts**: Usar nomes de containers (`postgres`, `redis`) em ambiente Docker
3. **Driver DB**: Sempre usar `asyncpg` para PostgreSQL assíncrono
4. **Scheduler**: Usar abreviações de dias da semana (`sun`, `mon`, etc.)
5. **nginx.conf**: Usar a versão simples e testada

## ✅ Teste de Validação

Após aplicar essas correções, todos os containers devem inicializar corretamente:

```bash
# Teste básico de funcionamento
curl http://localhost:8000/health/  # Backend
curl http://localhost:3000          # Frontend
curl http://localhost:9090          # Prometheus
```

## 🚨 Correções Aplicadas Durante Deploy Real

### Problemas Encontrados em Tempo Real (2025-06-27)

#### 1. **Arquivo .env - Quebras de Linha Windows**
```bash
# Problema: Caracteres de carriage return (\r) do Windows
.env: line 5: $'\r': command not found

# Solução aplicada:
sed -i 's/\r$//' .env
```

#### 2. **Backend Error: Invalid host header**
```bash
# Problema: TrustedHostMiddleware bloqueando acesso via IP externo
HTTP/1.1 400 Bad Request
Invalid host header

# Tentativas realizadas:
# 1. Adicionar ALLOWED_HOSTS ao .env
# 2. Adicionar variáveis ao docker-compose.yml
# 3. Corrigir formato das variáveis (aspas simples/duplas)

# Solução final:
# - Remover variáveis problemáticas do docker-compose.yml
# - Mudar ENVIRONMENT=development (desabilita TrustedHostMiddleware)
```

#### 3. **Erro de Parsing Pydantic Settings**
```bash
# Problema: Erro ao fazer parsing de ALLOWED_ORIGINS
pydantic_settings.sources.SettingsError: error parsing value for field "ALLOWED_ORIGINS"

# Solução aplicada:
# 1. Comentar variáveis no .env
sed -i 's/^ALLOWED_ORIGINS/#ALLOWED_ORIGINS/' .env
sed -i 's/^ALLOWED_HOSTS/#ALLOWED_HOSTS/' .env

# 2. Remover do docker-compose.yml
sed -i '/ALLOWED_HOSTS=${ALLOWED_HOSTS}/d' docker-compose.yml
sed -i '/ALLOWED_ORIGINS=${ALLOWED_ORIGINS}/d' docker-compose.yml
sed -i '/CORS_ALLOW_CREDENTIALS=${CORS_ALLOW_CREDENTIALS}/d' docker-compose.yml
```

#### 4. **npm Version Conflict**
```bash
# Problema durante install-requirements.sh:
npm notice To update, run: npm install -g npm@11.4.2

# Solução aplicada: Fixed no install-requirements.sh
# Usar versão compatível com Node.js 18
npm install -g npm@10.8.2
```

### ✅ Estado Final Funcionando
- **Frontend**: `http://192.168.1.227:3000` ✅
- **Backend**: `http://192.168.1.227:8000` ✅  
- **API Docs**: `http://192.168.1.227:8000/docs` ✅
- **Prometheus**: `http://192.168.1.227:9090` ✅
- **Ambiente**: `development` (permite acesso externo)

### 🔧 Correções Pendentes para Produção
1. **Configurar CORS corretamente** para ambiente production
2. **Implementar ALLOWED_HOSTS** sem conflitos de parsing
3. **Voltar para ENVIRONMENT=production** com configuração adequada
4. **Configurar domínio** para evitar usar IPs diretos

## 📅 Histórico de Correções

### v1.0.0-deploy-fixes (Correções Preventivas)
- **Data**: 2025-06-27  
- **Status**: ✅ Aplicadas nos arquivos locais

### v1.0.1-deploy-real (Correções Durante Deploy)
- **Data**: 2025-06-27
- **Status**: 🎉 Deploy realizado com sucesso no servidor LXC 192.168.1.227
- **Ambiente**: Debian 12 Bookworm + Docker 28.3.0 