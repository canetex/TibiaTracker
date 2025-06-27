"""
Configuração de Logging
=======================

Setup centralizado de logging para a aplicação.
"""

import logging
import logging.config
import os
from pathlib import Path
from typing import Dict, Any

from app.core.config import settings


def setup_logging() -> None:
    """
    Configurar sistema de logging da aplicação
    """
    
    # Criar diretório de logs se não existir
    log_file_path = Path(settings.LOG_FILE)
    log_file_path.parent.mkdir(parents=True, exist_ok=True)
    
    # Configuração do logging
    logging_config: Dict[str, Any] = {
        "version": 1,
        "disable_existing_loggers": False,
        "formatters": {
            "standard": {
                "format": settings.LOG_FORMAT,
                "datefmt": "%Y-%m-%d %H:%M:%S"
            },
            "detailed": {
                "format": "%(asctime)s - %(name)s - %(levelname)s - %(module)s - %(funcName)s:%(lineno)d - %(message)s",
                "datefmt": "%Y-%m-%d %H:%M:%S"
            },
            "json": {
                "()": "pythonjsonlogger.jsonlogger.JsonFormatter",
                "format": "%(asctime)s %(name)s %(levelname)s %(module)s %(funcName)s %(lineno)d %(message)s"
            }
        },
        "handlers": {
            "console": {
                "class": "logging.StreamHandler",
                "level": "DEBUG" if settings.DEBUG else "INFO",
                "formatter": "standard",
                "stream": "ext://sys.stdout"
            },
            "file": {
                "class": "logging.handlers.RotatingFileHandler",
                "level": settings.LOG_LEVEL,
                "formatter": "detailed",
                "filename": settings.LOG_FILE,
                "maxBytes": 10485760,  # 10MB
                "backupCount": 5,
                "encoding": "utf8"
            },
            "error_file": {
                "class": "logging.handlers.RotatingFileHandler",
                "level": "ERROR",
                "formatter": "detailed",
                "filename": str(log_file_path.parent / "error.log"),
                "maxBytes": 10485760,  # 10MB
                "backupCount": 5,
                "encoding": "utf8"
            }
        },
        "loggers": {
            # Logger da aplicação
            "app": {
                "level": settings.LOG_LEVEL,
                "handlers": ["console", "file", "error_file"],
                "propagate": False
            },
            # Logger do FastAPI
            "fastapi": {
                "level": "INFO",
                "handlers": ["console", "file"],
                "propagate": False
            },
            # Logger do Uvicorn
            "uvicorn": {
                "level": "INFO",
                "handlers": ["console", "file"],
                "propagate": False
            },
            "uvicorn.access": {
                "level": "INFO",
                "handlers": ["console", "file"],
                "propagate": False
            },
            # Logger do SQLAlchemy
            "sqlalchemy.engine": {
                "level": "WARNING",
                "handlers": ["console", "file"],
                "propagate": False
            },
            "sqlalchemy.pool": {
                "level": "WARNING",
                "handlers": ["console", "file"],
                "propagate": False
            },
            # Logger do APScheduler
            "apscheduler": {
                "level": "INFO",
                "handlers": ["console", "file"],
                "propagate": False
            },
            # Logger do aiohttp (para scraping)
            "aiohttp": {
                "level": "WARNING",
                "handlers": ["console", "file"],
                "propagate": False
            },
            # Logger do requests
            "requests": {
                "level": "WARNING",
                "handlers": ["console", "file"],
                "propagate": False
            },
            # Logger do urllib3
            "urllib3": {
                "level": "WARNING",
                "handlers": ["console", "file"],
                "propagate": False
            }
        },
        "root": {
            "level": settings.LOG_LEVEL,
            "handlers": ["console", "file"]
        }
    }
    
    # Aplicar configuração
    logging.config.dictConfig(logging_config)
    
    # Logger específico para a aplicação
    logger = logging.getLogger("app")
    
    if settings.is_development:
        logger.info("🔧 Logging configurado para DESENVOLVIMENTO")
    elif settings.is_production:
        logger.info("🚀 Logging configurado para PRODUÇÃO")
    else:
        logger.info(f"🔄 Logging configurado para {settings.ENVIRONMENT}")
    
    logger.info(f"📝 Logs sendo salvos em: {settings.LOG_FILE}")
    logger.info(f"📊 Nível de log: {settings.LOG_LEVEL}")


def get_logger(name: str) -> logging.Logger:
    """
    Obter logger para um módulo específico
    
    Args:
        name: Nome do logger (geralmente __name__)
        
    Returns:
        Logger configurado
    """
    return logging.getLogger(f"app.{name}")


# Configurar logging de terceiros para produção
def configure_third_party_logging():
    """Configurar logging de bibliotecas terceiras"""
    
    if settings.is_production:
        # Reduzir verbosidade em produção
        logging.getLogger("urllib3.connectionpool").setLevel(logging.WARNING)
        logging.getLogger("asyncio").setLevel(logging.WARNING)
        logging.getLogger("multipart").setLevel(logging.WARNING)
        
    # SQLAlchemy query logging apenas em desenvolvimento
    if settings.is_development and settings.DEBUG:
        logging.getLogger("sqlalchemy.engine").setLevel(logging.INFO)
    else:
        logging.getLogger("sqlalchemy.engine").setLevel(logging.WARNING) 