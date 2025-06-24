# 🏰 Tibia Tracker

Portal de monitoramento de personagens do Tibia desenvolvido com FastAPI (Backend) e React (Frontend).

## 📋 Características

- ✅ 100% desenvolvido no GitHub
- ✅ Sincronização automática via Git Push
- ✅ Deploy em LXC Debian com containers
- ✅ Estrutura modular com Scripts, Frontend e Backend
- ✅ Scripts completos de automação e manutenção
- ✅ Sistema de verificação e monitoramento
- ✅ Testes automatizados

## 🛠️ Stack Tecnológica

### Backend (API)
- Framework: FastAPI (Python)
- Runtime: Uvicorn (ASGI server)
- Banco de Dados: PostgreSQL + SQLAlchemy (ORM)
- Cache: Redis + FastAPI-Cache2
- Web Scraping: BeautifulSoup4 + Requests + Aiohttp
- Agendamento: APScheduler
- Validação: Pydantic
- Testes: Pytest + Httpx

### Frontend (Interface)
- Framework: React 18 + TypeScript
- UI Library: Material-UI (MUI) v5
- Roteamento: React Router DOM v6
- HTTP Client: Axios
- Gráficos: Chart.js + React-Chartjs-2
- Build Tool: Create React App
- Testes: Jest

### Infraestrutura
- Containerização: Docker + Docker Compose
- Web Server: Caddy (proxy reverso)
- Sistema: Systemd (serviços)
- Monitoramento: Prometheus + Node Exporter
- Firewall: UFW

## 📁 Estrutura do Projeto

```
Tibia Tracker/
├── Scripts/
│   ├── Deploy/                     # Scripts de instalação e deploy
│   │   ├── deploy.sh              # Deploy principal do sistema
│   │   └── install-requirements.sh # Instalação de requisitos LXC
│   ├── Manutenção/                 # Scripts de manutenção do sistema
│   │   ├── refresh-database.sh    # Refresh do banco PostgreSQL
│   │   ├── rebuild-containers.sh  # Rebuild de containers Docker
│   │   └── clear-cache.sh         # Limpeza de caches
│   ├── Verificação/                # Scripts de verificação e monitoramento
│   │   ├── health-check.sh        # Verificação completa de saúde
│   │   └── network-test.sh        # Testes de conectividade
│   ├── Remoção/                    # Scripts de desinstalação
│   │   ├── uninstall.sh           # Desinstalação completa
│   │   └── clean-docker.sh        # Limpeza Docker específica
│   └── Testes/                     # Scripts de testes automatizados
│       ├── run-tests.sh           # Todos os testes automatizados
│       └── api-tests.sh           # Testes específicos da API
├── Frontend/                       # Aplicação React
├── Backend/                        # API FastAPI
│   ├── app/                       # Código da aplicação
│   ├── requirements.txt           # Dependências Python
│   ├── Dockerfile                 # Container do backend
│   └── tests/                     # Testes unitários
├── docker-compose.yml             # Orquestração de containers
├── env.template                   # Template de variáveis
└── LICENSE                        # Licença MIT
```

## 🚀 Instalação e Deploy

### 1. Preparação do Sistema LXC Debian
```bash
# Instalar requisitos (executar como root)
chmod +x Scripts/Deploy/install-requirements.sh
sudo ./Scripts/Deploy/install-requirements.sh

# Reiniciar sistema
sudo reboot
```

### 2. Configuração
```bash
# Copiar template de variáveis
cp env.template .env

# Editar variáveis (OBRIGATÓRIO)
nano .env
```

**Variáveis essenciais para configurar:**
- `SECRET_KEY`: Chave secreta da aplicação
- `DB_PASSWORD`: Senha do PostgreSQL  
- `REDIS_PASSWORD`: Senha do Redis
- `JWT_SECRET_KEY`: Chave para tokens JWT

### 3. Deploy da Aplicação
```bash
# Deploy completo
chmod +x Scripts/Deploy/deploy.sh
sudo ./Scripts/Deploy/deploy.sh
```

## 🔧 Scripts de Manutenção

### 📊 Verificação de Saúde
```bash
# Verificação completa do sistema (35+ testes)
sudo ./Scripts/Verificação/health-check.sh

# Testes de conectividade e rede
sudo ./Scripts/Verificação/network-test.sh
```

### 🔄 Manutenção do Sistema
```bash
# Refresh completo do banco (com backup)
sudo ./Scripts/Manutenção/refresh-database.sh

# Rebuild de containers
sudo ./Scripts/Manutenção/rebuild-containers.sh [all|backend|frontend|clean]

# Limpeza de caches
sudo ./Scripts/Manutenção/clear-cache.sh [all|redis|docker|logs|system|frontend|backend]
```

### 🧪 Testes Automatizados
```bash
# Executar todos os testes
sudo ./Scripts/Testes/run-tests.sh

# Testes específicos da API
sudo ./Scripts/Testes/api-tests.sh
```

### 🗑️ Remoção (Se Necessário)
```bash
# Desinstalação completa do sistema
sudo ./Scripts/Remoção/uninstall.sh

# Limpeza apenas dos recursos Docker
sudo ./Scripts/Remoção/clean-docker.sh [all|stop|containers|images|volumes|networks]
```

## 📊 Funcionalidades dos Scripts

### ✅ Health Check (`health-check.sh`)
- Verificação de sistema operacional e recursos
- Status de containers e health checks
- Conectividade PostgreSQL e Redis
- Testes de endpoints da API
- Verificação de segurança (firewall, permissões)
- Análise de performance
- Relatório completo com taxa de sucesso

### 🔄 Rebuild Containers (`rebuild-containers.sh`)
- Rebuild completo ou seletivo de containers
- Limpeza de recursos Docker órfãos
- Verificação pós-rebuild
- Análise de logs de erro
- Teste de endpoints após rebuild

### 🧹 Clear Cache (`clear-cache.sh`)
- Limpeza do cache Redis
- Limpeza de cache Docker (build, images, containers)
- Limpeza de logs da aplicação
- Limpeza de cache do sistema
- Relatório de espaço liberado

### 🌐 Network Test (`network-test.sh`)
- Conectividade externa (internet, DNS, HTTPS)
- Teste de portas locais
- Comunicação entre containers
- Testes de latência e performance
- Verificação do proxy reverso

## 📊 Funcionalidades Planejadas

### 🎯 Core Features
- [x] Estrutura base do projeto
- [x] Sistema de configuração
- [x] Containerização completa
- [x] Scripts de automação completos
- [ ] Web scraping Taleon (San, Aura, Gaia)
- [ ] Endpoint POST /characters
- [ ] Histórico de snapshots
- [ ] Agendamento automático (00:01 diário)
- [ ] Interface React responsiva
- [ ] Gráficos de evolução
- [ ] Sistema de favoritos

### 🔐 Autenticação
- [ ] Login Google OAuth
- [ ] Login Discord OAuth
- [ ] Gestão de sessões com Redis

### 📊 Monitoramento
- [x] Verificação de saúde automatizada
- [x] Testes de conectividade
- [ ] Métricas Prometheus
- [ ] Alertas automáticos
- [ ] Dashboard de monitoramento

## 🔍 Monitoramento e Logs

### Logs do Sistema
```bash
# Logs gerais da aplicação
tail -f /var/log/tibia-tracker/*.log

# Logs específicos dos scripts
tail -f /var/log/tibia-tracker/health-check.log
tail -f /var/log/tibia-tracker/rebuild-containers.log

# Logs dos containers
docker-compose logs -f
docker-compose logs backend
```

### Verificação de Status
```bash
# Status dos containers
docker-compose ps

# Status dos serviços
sudo systemctl status tibia-tracker

# Verificação de saúde rápida
sudo ./Scripts/Verificação/health-check.sh
```

## 🛡️ Segurança

- Firewall UFW configurado
- Fail2ban para proteção contra ataques
- Containers isolados em rede própria
- Variáveis de ambiente protegidas
- Backups automáticos antes de operações críticas
- Verificação de permissões de arquivos

## 🔄 Atualizações

```bash
# Atualização via Git
./git-pull.sh

# Rebuild após atualização
sudo ./Scripts/Manutenção/rebuild-containers.sh

# Verificação pós-atualização
sudo ./Scripts/Verificação/health-check.sh
```

## 📞 Suporte e Resolução de Problemas

### Comandos de Diagnóstico
```bash
# Verificação completa
sudo ./Scripts/Verificação/health-check.sh

# Teste de rede
sudo ./Scripts/Verificação/network-test.sh

# Status dos containers
docker-compose ps

# Logs em tempo real
docker-compose logs -f
```

### Problemas Comuns
1. **Containers não iniciam**: Verificar `.env` e executar health check
2. **Falha na conectividade**: Executar network test
3. **Problemas de performance**: Executar clear cache
4. **Erros após atualização**: Executar rebuild containers

## 📄 Licença

MIT License - Veja o arquivo [LICENSE](LICENSE) para detalhes.

---

**🎯 Status Atual**: Infraestrutura completa com scripts de automação finalizados
**📍 Próximo Passo**: Implementação do endpoint de personagens e web scraping 