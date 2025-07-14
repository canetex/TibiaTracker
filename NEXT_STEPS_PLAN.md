# 🚀 PLANO DOS PRÓXIMOS PASSOS - TIBIA TRACKER

## 📊 STATUS ATUAL
✅ **Sistema Completo Funcionando**
- Backend: FastAPI com scraping automatizado
- Frontend: React com interface responsiva
- Banco: PostgreSQL com snapshots históricos
- Infraestrutura: Docker + LXC Debian

## 🎯 PRÓXIMOS PASSOS

### FASE 1: MERGE E PREPARAÇÃO (1-2 dias)

#### 1.1 Merge da Branch enhance-MaxGraph para Main
```bash
# Verificar branch atual
git branch -a

# Fazer checkout para main
git checkout main

# Fazer pull das últimas alterações
git pull origin main

# Fazer merge da branch enhance-MaxGraph
git merge enhance-MaxGraph

# Resolver conflitos se houver
# Fazer commit do merge
git push origin main
```

#### 1.2 Criar Nova Branch para Próximas Funcionalidades
```bash
# Criar nova branch
git checkout -b feature/auth-and-improvements

# Verificar criação
git branch
```

### FASE 2: MELHORIAS DE FRONTEND (3-5 dias)

#### 2.1 Persistência de Favoritos (Cookie/Sessão)
**Arquivos a modificar:**
- `Frontend/src/components/CharacterCard.js`
- `Frontend/src/contexts/ThemeContext.js` (ou criar novo contexto)
- `Frontend/src/services/api.js`

**Implementação:**
- Usar `localStorage` para persistência local
- Implementar contexto React para gerenciar favoritos
- Sincronizar com backend (endpoint `/toggle-favorite`)
- Adicionar indicador visual de favoritos salvos

#### 2.2 Revisar Labels Incorretos
**Arquivos a verificar:**
- `Frontend/src/components/CharacterCard.js`
- `Frontend/src/components/CharacterFilters.js`
- `Frontend/src/pages/Home.js`

**Correções:**
- Verificar todos os textos e labels
- Corrigir traduções incorretas
- Padronizar nomenclatura
- Melhorar clareza das informações

#### 2.3 Remover Título Abaixo do Header
**Arquivo a modificar:**
- `Frontend/src/pages/Home.js`

**Ação:**
- Identificar e remover título duplicado
- Ajustar layout se necessário
- Manter apenas o header principal

### FASE 3: AUTENTICAÇÃO OAUTH (5-7 dias)

#### 3.1 Configuração Backend - Google OAuth
**Arquivos a criar/modificar:**
- `Backend/app/api/routes/auth.py` (novo)
- `Backend/app/models/user.py` (novo)
- `Backend/app/schemas/auth.py` (novo)
- `Backend/requirements.txt` (adicionar dependências)

**Implementação:**
```python
# Dependências necessárias
python-jose[cryptography]==3.3.0
python-multipart==0.0.6
authlib==1.2.1
```

**Endpoints a criar:**
- `POST /auth/google/login`
- `POST /auth/google/callback`
- `GET /auth/logout`
- `GET /auth/me`

#### 3.2 Configuração Backend - Discord OAuth
**Arquivos a modificar:**
- `Backend/app/api/routes/auth.py`

**Implementação:**
- Adicionar endpoints Discord
- `POST /auth/discord/login`
- `POST /auth/discord/callback`

#### 3.3 Gestão de Sessão
**Implementação:**
- Usar Redis para armazenar sessões
- JWT tokens para autenticação
- Middleware de autenticação
- Refresh tokens

#### 3.4 Configuração Frontend - Autenticação
**Arquivos a criar/modificar:**
- `Frontend/src/contexts/AuthContext.js` (novo)
- `Frontend/src/components/LoginModal.js` (novo)
- `Frontend/src/services/auth.js` (novo)
- `Frontend/src/App.js`

**Implementação:**
- Contexto de autenticação
- Modal de login com opções Google/Discord
- Proteção de rotas
- Persistência de sessão

### FASE 4: MIGRAÇÃO PARA PRODUÇÃO (3-4 dias)

#### 4.1 Atualizar Variáveis de Ambiente
**Arquivos a modificar:**
- `env-production.template`
- `Backend/app/core/config.py`

**Configurações:**
```bash
# Produção
ENVIRONMENT=production
DEBUG=false
ALLOWED_HOSTS=seu-dominio.com,www.seu-dominio.com
CORS_ORIGINS=https://seu-dominio.com,https://www.seu-dominio.com

# OAuth
GOOGLE_CLIENT_ID=seu-google-client-id
GOOGLE_CLIENT_SECRET=seu-google-client-secret
DISCORD_CLIENT_ID=seu-discord-client-id
DISCORD_CLIENT_SECRET=seu-discord-client-secret

# Segurança
SECRET_KEY=chave-secreta-forte-producao
JWT_ALGORITHM=HS256
JWT_EXPIRATION=3600
```

#### 4.2 Segurança do Backend
**Implementações:**
- Rate limiting
- CORS configurado para produção
- Headers de segurança
- Validação de entrada rigorosa
- Logs de auditoria

#### 4.3 Atualizar DNS e Caminho do Portal
**Configurações:**
- Registrar domínio
- Configurar DNS A record para 192.168.1.227
- Configurar Caddy para SSL automático
- Atualizar configurações de proxy

### FASE 5: TESTES E DEPLOY (2-3 dias)

#### 5.1 Testes Locais
```bash
# Testar autenticação localmente
docker-compose up -d
# Testar login Google/Discord
# Testar persistência de favoritos
# Testar todas as funcionalidades
```

#### 5.2 Deploy em Produção
```bash
# Backup do sistema atual
sudo ./Scripts/Manutenção/backup-database.sh

# Atualizar arquivos no servidor
git pull origin feature/auth-and-improvements

# Rebuild containers
sudo ./Scripts/Manutenção/rebuild-containers.sh

# Verificar funcionamento
sudo ./Scripts/Verificação/health-check.sh
```

#### 5.3 Verificação Final
- Testar autenticação em produção
- Verificar SSL/HTTPS
- Testar todas as funcionalidades
- Verificar logs de erro
- Testar performance

## 📋 CHECKLIST DE IMPLEMENTAÇÃO

### ✅ FASE 1: MERGE E PREPARAÇÃO
- [ ] Merge enhance-MaxGraph → main
- [ ] Criar branch feature/auth-and-improvements
- [ ] Verificar conflitos resolvidos

### ✅ FASE 2: MELHORIAS FRONTEND
- [ ] Implementar persistência de favoritos
- [ ] Revisar e corrigir labels
- [ ] Remover título duplicado
- [ ] Testar funcionalidades

### ✅ FASE 3: AUTENTICAÇÃO
- [ ] Configurar Google OAuth (Backend)
- [ ] Configurar Discord OAuth (Backend)
- [ ] Implementar gestão de sessão
- [ ] Criar componentes de login (Frontend)
- [ ] Integrar autenticação no Frontend
- [ ] Testar fluxo completo

### ✅ FASE 4: PRODUÇÃO
- [ ] Atualizar variáveis de ambiente
- [ ] Implementar segurança adicional
- [ ] Configurar DNS e SSL
- [ ] Testar em ambiente de staging

### ✅ FASE 5: DEPLOY
- [ ] Deploy em produção
- [ ] Verificação completa
- [ ] Monitoramento inicial
- [ ] Documentação final

## 🚨 PONTOS DE ATENÇÃO

### Segurança
- Nunca commitar credenciais OAuth
- Usar variáveis de ambiente para secrets
- Implementar rate limiting
- Validar todas as entradas

### Performance
- Otimizar consultas de banco
- Implementar cache adequado
- Monitorar uso de recursos
- Testar com carga

### Backup
- Fazer backup antes de cada deploy
- Testar processo de restore
- Documentar configurações
- Manter logs de auditoria

## 📞 SUPORTE

Para dúvidas durante implementação:
1. Verificar logs: `docker-compose logs -f`
2. Health check: `sudo ./Scripts/Verificação/health-check.sh`
3. Backup: `sudo ./Scripts/Manutenção/backup-database.sh`
4. Rollback: `git checkout main && git pull`

---

**🎯 Objetivo**: Sistema completo com autenticação e produção
**⏱️ Estimativa**: 2-3 semanas
**📊 Prioridade**: Alta - Funcionalidades críticas para usuários 