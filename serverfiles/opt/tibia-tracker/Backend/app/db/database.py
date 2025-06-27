"""
Configuração do Banco de Dados
==============================

Setup do SQLAlchemy com suporte assíncrono para PostgreSQL.
"""

import logging
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy.orm import declarative_base
from sqlalchemy.pool import NullPool
from contextlib import asynccontextmanager
from typing import AsyncGenerator

from app.core.config import settings

logger = logging.getLogger(__name__)

# Base para os modelos
Base = declarative_base()

# Engine assíncrono
engine = create_async_engine(
    settings.DATABASE_URL,
    echo=settings.DEBUG and settings.is_development,  # Log queries apenas em dev
    poolclass=NullPool if settings.is_testing else None,
    pool_pre_ping=True,
    pool_recycle=3600,  # Reciclar conexões a cada hora
    max_overflow=20,
    pool_size=10
)

# Session factory
AsyncSessionLocal = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autoflush=True,
    autocommit=False
)


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """
    Dependency para obter sessão do banco de dados
    
    Yields:
        AsyncSession: Sessão do banco de dados
    """
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()


@asynccontextmanager
async def get_db_session() -> AsyncGenerator[AsyncSession, None]:
    """
    Context manager para obter sessão do banco de dados
    
    Yields:
        AsyncSession: Sessão do banco de dados
    """
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()


async def create_all_tables():
    """
    Criar todas as tabelas no banco de dados
    """
    try:
        logger.info("🗄️ Criando tabelas do banco de dados...")
        
        # Importar modelos para que sejam registrados
        from app.models.character import Character, CharacterSnapshot
        
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
        
        logger.info("✅ Tabelas criadas/verificadas com sucesso")
        
    except Exception as e:
        logger.error(f"❌ Erro ao criar tabelas: {e}")
        raise


async def drop_all_tables():
    """
    Remover todas as tabelas (usar apenas em testes)
    """
    if not settings.is_testing:
        raise ValueError("Drop tables só é permitido em ambiente de teste")
    
    try:
        logger.warning("🗑️ Removendo todas as tabelas...")
        
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.drop_all)
        
        logger.info("✅ Tabelas removidas com sucesso")
        
    except Exception as e:
        logger.error(f"❌ Erro ao remover tabelas: {e}")
        raise


async def check_database_connection() -> bool:
    """
    Verificar se a conexão com o banco está funcionando
    
    Returns:
        bool: True se conectou com sucesso
    """
    try:
        async with AsyncSessionLocal() as session:
            await session.execute(text("SELECT 1"))
            logger.info("✅ Conexão com banco de dados OK")
            return True
    except Exception as e:
        logger.error(f"❌ Erro na conexão com banco: {e}")
        return False


async def init_database():
    """
    Inicializar banco de dados
    """
    logger.info("🚀 Inicializando banco de dados...")
    
    # Verificar conexão
    if not await check_database_connection():
        raise Exception("Não foi possível conectar ao banco de dados")
    
    # Criar tabelas
    await create_all_tables()
    
    logger.info("✅ Banco de dados inicializado com sucesso")


async def close_database():
    """
    Fechar conexões do banco de dados
    """
    logger.info("🔌 Fechando conexões do banco de dados...")
    await engine.dispose()
    logger.info("✅ Conexões fechadas")


# Importações necessárias para funcionar
from sqlalchemy import text 