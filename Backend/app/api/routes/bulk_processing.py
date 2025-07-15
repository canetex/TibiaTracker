"""
Rotas da API para Processamento em Lotes
========================================

Endpoints para processamento em lotes de personagens, otimizados para volume alto.
Especialmente para o Rubinot e outros servidores com +10.000 personagens.
"""

from fastapi import APIRouter, Depends, HTTPException, Query, BackgroundTasks
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List, Dict, Any, Optional
import logging

from app.db.database import get_db
from app.services.bulk_processor import BulkProcessor, BulkProcessingConfig
from app.services.scraping import is_server_supported, is_world_supported

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/bulk", tags=["bulk-processing"])


@router.post("/process-batch")
async def process_character_batch(
    character_list: List[Dict[str, Any]],
    server: str = Query(..., description="Servidor (ex: rubinot)"),
    world: str = Query(..., description="Mundo (ex: auroria)"),
    batch_size: int = Query(50, ge=1, le=200, description="Tamanho do lote"),
    max_concurrent: int = Query(10, ge=1, le=50, description="Máximo de requests concorrentes"),
    db: AsyncSession = Depends(get_db)
):
    """
    Processar uma lista de personagens em lotes
    
    Otimizado para volume alto como o Rubinot.
    """
    try:
        # Validar servidor e mundo
        if not is_server_supported(server):
            raise HTTPException(
                status_code=400,
                detail=f"Servidor '{server}' não suportado"
            )
        
        if not is_world_supported(server, world):
            raise HTTPException(
                status_code=400,
                detail=f"Mundo '{world}' não suportado pelo servidor '{server}'"
            )
        
        # Validar lista de personagens
        if not character_list:
            raise HTTPException(
                status_code=400,
                detail="Lista de personagens não pode estar vazia"
            )
        
        if len(character_list) > 1000:
            raise HTTPException(
                status_code=400,
                detail="Máximo de 1000 personagens por requisição"
            )
        
        # Configurar processador
        config = BulkProcessingConfig(
            batch_size=batch_size,
            max_concurrent=max_concurrent
        )
        
        processor = BulkProcessor(db, config)
        
        # Processar lotes
        result = await processor.process_characters_batch(
            character_list, server, world
        )
        
        return {
            "success": True,
            "message": "Processamento em lotes concluído",
            "result": {
                "total_processed": result.total_processed,
                "successful": result.successful,
                "failed": result.failed,
                "skipped": result.skipped,
                "processing_time": result.processing_time,
                "error_count": len(result.errors)
            },
            "errors": result.errors[:10]  # Limitar a 10 erros no response
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erro no processamento em lotes: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Erro interno no processamento: {str(e)}"
        )


@router.post("/rubinot/initial-load/{world}")
async def rubinot_initial_load(
    world: str,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db)
):
    """
    Iniciar carga inicial do Rubinot para um mundo específico
    
    Esta operação é executada em background devido ao volume alto.
    """
    try:
        # Validar mundo do Rubinot
        if not is_world_supported("rubinot", world):
            raise HTTPException(
                status_code=400,
                detail=f"Mundo '{world}' não suportado pelo Rubinot"
            )
        
        # TODO: Implementar obtenção da lista de personagens do Rubinot
        # Por enquanto, retornar erro informativo
        
        return {
            "success": False,
            "message": "Carga inicial do Rubinot não implementada ainda",
            "details": {
                "world": world,
                "status": "not_implemented",
                "note": "Necessário implementar obtenção da lista de personagens do Rubinot"
            }
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erro na carga inicial do Rubinot: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Erro interno: {str(e)}"
        )


@router.get("/stats/{server}/{world}")
async def get_bulk_processing_stats(
    server: str,
    world: str,
    db: AsyncSession = Depends(get_db)
):
    """
    Obter estatísticas de processamento para um servidor/mundo
    """
    try:
        # Validar servidor e mundo
        if not is_server_supported(server):
            raise HTTPException(
                status_code=400,
                detail=f"Servidor '{server}' não suportado"
            )
        
        if not is_world_supported(server, world):
            raise HTTPException(
                status_code=400,
                detail=f"Mundo '{world}' não suportado pelo servidor '{server}'"
            )
        
        processor = BulkProcessor(db)
        stats = await processor.get_processing_stats(server, world)
        
        if 'error' in stats:
            raise HTTPException(
                status_code=500,
                detail=f"Erro ao obter estatísticas: {stats['error']}"
            )
        
        return {
            "success": True,
            "stats": stats
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erro ao obter estatísticas: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Erro interno: {str(e)}"
        )


@router.get("/supported-servers")
async def get_bulk_supported_servers():
    """
    Obter servidores suportados para processamento em lotes
    """
    from app.services.scraping import get_supported_servers, get_server_info
    
    servers = get_supported_servers()
    server_details = {}
    
    for server in servers:
        info = get_server_info(server)
        if info:
            server_details[server] = {
                "name": info.get("name", server.title()),
                "supported_worlds": info.get("supported_worlds", []),
                "bulk_processing_supported": True
            }
    
    return {
        "success": True,
        "supported_servers": servers,
        "server_details": server_details,
        "total_servers": len(servers)
    }


@router.get("/config")
async def get_bulk_processing_config():
    """
    Obter configuração padrão para processamento em lotes
    """
    default_config = BulkProcessingConfig()
    
    return {
        "success": True,
        "default_config": {
            "batch_size": default_config.batch_size,
            "max_concurrent": default_config.max_concurrent,
            "delay_between_batches": default_config.delay_between_batches,
            "delay_between_requests": default_config.delay_between_requests,
            "max_retries": default_config.max_retries,
            "retry_delay": default_config.retry_delay
        },
        "recommendations": {
            "rubinot": {
                "batch_size": 100,
                "max_concurrent": 20,
                "delay_between_batches": 1.0,
                "delay_between_requests": 0.5,
                "max_retries": 2,
                "retry_delay": 3.0
            },
            "taleon": {
                "batch_size": 50,
                "max_concurrent": 10,
                "delay_between_batches": 2.0,
                "delay_between_requests": 1.0,
                "max_retries": 3,
                "retry_delay": 5.0
            }
        }
    } 