"""
Tibia Tracker - API Principal
============================

API REST para monitoramento de personagens do Tibia.
Desenvolvido com FastAPI, PostgreSQL e Redis.
"""

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from contextlib import asynccontextmanager
import logging
import uvicorn

from app.core.config import settings
from app.core.logging import setup_logging
from app.db.database import engine, create_all_tables
from app.api.routes import characters, health
from app.services.scheduler import start_scheduler, stop_scheduler

# Adicionar imports para métricas
from datetime import datetime
import psutil


# Configurar logging
setup_logging()
logger = logging.getLogger(__name__)

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Gerenciar ciclo de vida da aplicação"""
    logger.info("🚀 Iniciando Tibia Tracker API...")
    
    # Criar tabelas do banco de dados
    await create_all_tables()
    logger.info("✅ Tabelas do banco criadas/verificadas")
    
    # Iniciar scheduler para scraping automático
    start_scheduler()
    logger.info("✅ Scheduler iniciado")
    
    yield
    
    # Cleanup ao parar aplicação
    logger.info("🛑 Parando Tibia Tracker API...")
    stop_scheduler()
    logger.info("✅ Scheduler parado")


# Criar instância do FastAPI
app = FastAPI(
    title="Tibia Tracker API",
    description="""
    **API REST para monitoramento de personagens do Tibia** 🏰
    
    ## Funcionalidades Principais
    
    * **Adicionar Personagens**: Adicione personagens de diferentes servidores
    * **Web Scraping**: Coleta automática de dados dos sites oficiais
    * **Histórico**: Mantenha histórico completo de evolução
    * **Gráficos**: Dados organizados para visualização
    * **Agendamento**: Atualizações automáticas diárias
    
    ## Servidores Suportados
    
    * **Taleon**: San, Aura, Gaia
    * Mais servidores em desenvolvimento...
    
    ---
    
    Desenvolvido com ❤️ pela equipe Tibia Tracker
    """,
    version="1.0.0",
    docs_url="/docs" if settings.ENVIRONMENT == "development" else None,
    redoc_url="/redoc" if settings.ENVIRONMENT == "development" else None,
    lifespan=lifespan
)

# Configurar CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["*"],
)

# Middleware de hosts confiáveis
if settings.ENVIRONMENT == "production":
    app.add_middleware(
        TrustedHostMiddleware,
        allowed_hosts=settings.ALLOWED_HOSTS
    )

# Incluir rotas
app.include_router(health.router, prefix="/health", tags=["Health"])
app.include_router(characters.router, prefix="/api/v1", tags=["Characters"])


@app.get("/", tags=["Root"])
async def root():
    """Endpoint raiz com informações da API"""
    return {
        "message": "🏰 Tibia Tracker API",
        "version": "1.0.0",
        "environment": settings.ENVIRONMENT,
        "docs": "/docs" if settings.ENVIRONMENT == "development" else "Disabled in production",
        "status": "✅ Online",
        "supported_servers": {
            "taleon": {
                "worlds": ["san", "aura", "gaia"],
                "status": "active"
            }
        }
    }


@app.get("/info", tags=["Root"])
async def info():
    """Informações detalhadas da API"""
    return {
        "api": {
            "name": "Tibia Tracker",
            "version": "1.0.0",
            "environment": settings.ENVIRONMENT,
            "debug": settings.DEBUG
        },
        "features": [
            "Character monitoring",
            "Automatic scraping",
            "Historical data",
            "Daily updates",
            "RESTful API"
        ],
        "endpoints": {
            "characters": "/api/v1/characters",
            "health": "/health",
            "docs": "/docs"
        }
    }


@app.get("/metrics", tags=["Metrics"])
async def metrics():
    """Endpoint de métricas para Prometheus"""
    try:
        # Métricas básicas da aplicação
        metrics_data = []
        
        # Informações do sistema
        cpu_percent = psutil.cpu_percent()
        memory = psutil.virtual_memory()
        disk = psutil.disk_usage('/')
        
        # Métricas no formato Prometheus
        metrics_data.append(f"# HELP tibia_tracker_cpu_usage_percent CPU usage percentage")
        metrics_data.append(f"# TYPE tibia_tracker_cpu_usage_percent gauge")
        metrics_data.append(f"tibia_tracker_cpu_usage_percent {cpu_percent}")
        
        metrics_data.append(f"# HELP tibia_tracker_memory_usage_percent Memory usage percentage")
        metrics_data.append(f"# TYPE tibia_tracker_memory_usage_percent gauge")
        metrics_data.append(f"tibia_tracker_memory_usage_percent {memory.percent}")
        
        metrics_data.append(f"# HELP tibia_tracker_disk_usage_percent Disk usage percentage")
        metrics_data.append(f"# TYPE tibia_tracker_disk_usage_percent gauge")
        metrics_data.append(f"tibia_tracker_disk_usage_percent {disk.percent}")
        
        metrics_data.append(f"# HELP tibia_tracker_uptime_seconds Application uptime in seconds")
        metrics_data.append(f"# TYPE tibia_tracker_uptime_seconds counter")
        metrics_data.append(f"tibia_tracker_uptime_seconds {int(datetime.now().timestamp())}")
        
        # Retornar métricas em formato texto plano
        return "\n".join(metrics_data)
        
    except Exception as e:
        # Em caso de erro, retornar métricas básicas
        return f"# Error generating metrics: {str(e)}\ntibia_tracker_error 1"


# Executar aplicação diretamente (desenvolvimento)
if __name__ == "__main__":
    uvicorn.run(
        "app.main:app",
        host=settings.API_HOST,
        port=settings.API_PORT,
        reload=settings.API_RELOAD,
        workers=1 if settings.API_RELOAD else settings.API_WORKERS,
        log_level=settings.LOG_LEVEL.lower()
    ) 