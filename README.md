# Tibia Tracker

Portal de monitoramento de personagens do Tibia desenvolvido com FastAPI (Backend) e React (Frontend).

## 📋 Características

- ✅ 100% desenvolvido no GitHub
- ✅ Sincronização automática via Git Push
- ✅ Deploy em LXC Debian com containers
- ✅ Estrutura modular com Scripts, Frontend e Backend

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
│   ├── Deploy/         # Scripts de instalação e deploy
│   ├── Manutenção/     # Scripts de manutenção e rebuild
│   ├── Verificação/    # Scripts de verificação
│   ├── Remoção/        # Scripts de desinstalação
│   └── Testes/         # Scripts de testes automatizados
├── Frontend/           # Aplicação React
└── Backend/            # API FastAPI
```

## 🚀 Deploy

1. Execute o script de deploy: `./Scripts/Deploy/deploy.sh`
2. Configure as variáveis de ambiente
3. Execute `docker-compose up -d --build`

## 📊 Funcionalidades

- Web Scraping de dados de personagens do Taleon
- Dashboard com gráficos de evolução
- Sistema de favoritos
- Atualização automática diária
- Interface responsiva Material Design
- Autenticação Google e Discord

## 🔧 Configuração

1. Copie `.env.template` para `.env`
2. Configure as variáveis necessárias
3. Execute os scripts de deploy

## 📄 Licença

MIT License 