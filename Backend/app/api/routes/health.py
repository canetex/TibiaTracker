"""
Rotas de Health Check
====================

Endpoints para verificação de saúde da aplicação e dependências.
"""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text
import redis.asyncio as redis
import logging
from datetime import datetime
from typing import Dict, Any

from app.db.database import get_db
from app.core.config import settings

logger = logging.getLogger(__name__)

router = APIRouter()


@router.get("")
async def health_check():
    """
    Health check básico da API
    """
    return {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "version": "1.0.0",
        "environment": settings.ENVIRONMENT
    }


@router.get("/")
async def health_check_alias():
    """
    Health check básico da API (alias com barra para compatibilidade)
    """
    return {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "version": "1.0.0",
        "environment": settings.ENVIRONMENT
    }


@router.get("/detailed")
async def detailed_health_check(db: AsyncSession = Depends(get_db)):
    """
    Health check detalhado com verificação de dependências
    """
    health_status = {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "version": "1.0.0",
        "environment": settings.ENVIRONMENT,
        "checks": {}
    }
    
    # Verificar banco de dados
    try:
        result = await db.execute(text("SELECT 1"))
        result.scalar()
        health_status["checks"]["database"] = {
            "status": "healthy",
            "message": "Conexão com PostgreSQL OK"
        }
    except Exception as e:
        logger.error(f"Erro na verificação do banco: {e}")
        health_status["checks"]["database"] = {
            "status": "unhealthy",
            "message": f"Erro na conexão: {str(e)}"
        }
        health_status["status"] = "unhealthy"
    
    # Verificar Redis
    try:
        redis_client = redis.from_url(settings.REDIS_URL)
        await redis_client.ping()
        await redis_client.close()
        health_status["checks"]["redis"] = {
            "status": "healthy",
            "message": "Conexão com Redis OK"
        }
    except Exception as e:
        logger.error(f"Erro na verificação do Redis: {e}")
        health_status["checks"]["redis"] = {
            "status": "unhealthy",
            "message": f"Erro na conexão: {str(e)}"
        }
        health_status["status"] = "unhealthy"
    
    return health_status


@router.get("/readiness")
async def readiness_check(db: AsyncSession = Depends(get_db)):
    """
    Verificação de readiness - se a aplicação está pronta para receber requests
    """
    try:
        # Verificar banco de dados
        await db.execute(text("SELECT 1"))
        
        # Verificar Redis
        redis_client = redis.from_url(settings.REDIS_URL)
        await redis_client.ping()
        await redis_client.close()
        
        return {
            "status": "ready",
            "timestamp": datetime.now().isoformat()
        }
        
    except Exception as e:
        logger.error(f"Readiness check falhou: {e}")
        raise HTTPException(
            status_code=503,
            detail={
                "status": "not ready",
                "message": str(e),
                "timestamp": datetime.now().isoformat()
            }
        )


@router.get("/liveness")
async def liveness_check():
    """
    Verificação de liveness - se a aplicação está funcionando
    """
    return {
        "status": "alive",
        "timestamp": datetime.now().isoformat(),
        "uptime": "OK"
    } 