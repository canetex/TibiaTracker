"""
Rotas da API para gerenciamento de personagens
==============================================

Endpoints REST para CRUD de personagens e funcionalidades relacionadas.
"""

from fastapi import APIRouter, Depends, HTTPException, Query, BackgroundTasks
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, desc
from typing import List, Optional
import logging
from datetime import datetime, timedelta

from app.db.database import get_db
from app.models.character import Character, CharacterSnapshot
from app.schemas.character import (
    CharacterCreate, CharacterResponse, CharacterListResponse,
    CharacterSearchRequest, CharacterUpdate, CharacterStatsResponse,
    ErrorResponse, SuccessResponse, CharacterFavoriteRequest,
    validate_character_name, validate_server_world_combination
)
from app.services.scraping import scrape_character_data
from app.services.character import CharacterService

logger = logging.getLogger(__name__)

router = APIRouter()


@router.post("/", response_model=CharacterResponse, status_code=201)
async def create_character(
    character_data: CharacterCreate,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db)
):
    """
    Adicionar um novo personagem
    
    Faz o scraping inicial e agenda atualizações automáticas.
    """
    try:
        # Validar dados de entrada
        validate_character_name(character_data.name)
        validate_server_world_combination(character_data.server, character_data.world)
        
        # Verificar se personagem já existe
        service = CharacterService(db)
        existing_char = await service.get_character_by_name_server_world(
            character_data.name, character_data.server, character_data.world
        )
        
        if existing_char:
            logger.info(f"Personagem {character_data.name} já existe, retornando dados existentes")
            return await service.get_character_with_stats(existing_char.id)
        
        # Fazer scraping inicial
        logger.info(f"Iniciando scraping para novo personagem: {character_data.name}")
        scrape_result = await scrape_character_data(
            character_data.server, character_data.world, character_data.name
        )
        
        if not scrape_result.success:
            logger.error(f"Falha no scraping: {scrape_result.error_message}")
            raise HTTPException(
                status_code=422,
                detail={
                    "message": "Não foi possível obter dados do personagem",
                    "error": scrape_result.error_message,
                    "retry_after": scrape_result.retry_after.isoformat() if scrape_result.retry_after else None
                }
            )
        
        # Criar personagem no banco
        character = await service.create_character_with_snapshot(character_data, scrape_result.data)
        
        # Agendar próxima atualização
        background_tasks.add_task(service.schedule_next_update, character.id)
        
        logger.info(f"Personagem {character.name} criado com sucesso (ID: {character.id})")
        
        return await service.get_character_with_stats(character.id)
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erro ao criar personagem: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Erro interno do servidor")


@router.get("/", response_model=CharacterListResponse)
async def list_characters(
    page: int = Query(1, ge=1, description="Número da página"),
    size: int = Query(20, ge=1, le=100, description="Itens por página"),
    favorited_only: bool = Query(False, description="Apenas personagens favoritados"),
    server: Optional[str] = Query(None, description="Filtrar por servidor"),
    world: Optional[str] = Query(None, description="Filtrar por mundo"),
    db: AsyncSession = Depends(get_db)
):
    """
    Listar personagens com paginação e filtros
    """
    try:
        service = CharacterService(db)
        
        result = await service.list_characters(
            page=page,
            size=size,
            favorited_only=favorited_only,
            server=server,
            world=world
        )
        
        return result
        
    except Exception as e:
        logger.error(f"Erro ao listar personagens: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Erro interno do servidor")


@router.get("/recent", response_model=List[CharacterResponse])
async def get_recent_characters(
    limit: int = Query(10, ge=1, le=50, description="Número de personagens recentes"),
    db: AsyncSession = Depends(get_db)
):
    """
    Obter personagens adicionados recentemente
    
    Usado para exibir no dashboard inicial.
    """
    try:
        service = CharacterService(db)
        characters = await service.get_recent_characters(limit)
        
        return characters
        
    except Exception as e:
        logger.error(f"Erro ao obter personagens recentes: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Erro interno do servidor")


@router.get("/search", response_model=CharacterResponse)
async def search_character(
    name: str = Query(..., description="Nome do personagem"),
    server: str = Query(..., description="Servidor"),
    world: str = Query(..., description="Mundo"),
    db: AsyncSession = Depends(get_db)
):
    """
    Buscar um personagem específico
    
    Se não existir no banco, fará scraping e adicionará automaticamente.
    """
    try:
        # Validar entrada
        clean_name = validate_character_name(name)
        validate_server_world_combination(server, world)
        
        service = CharacterService(db)
        
        # Verificar se existe no banco
        character = await service.get_character_by_name_server_world(clean_name, server, world)
        
        if character:
            logger.info(f"Personagem {clean_name} encontrado no banco")
            return await service.get_character_with_stats(character.id)
        
        # Se não existe, fazer scraping e criar
        logger.info(f"Personagem {clean_name} não encontrado, fazendo scraping")
        
        scrape_result = await scrape_character_data(server, world, clean_name)
        
        if not scrape_result.success:
            raise HTTPException(
                status_code=404,
                detail={
                    "message": "Personagem não encontrado",
                    "error": scrape_result.error_message,
                    "retry_after": scrape_result.retry_after.isoformat() if scrape_result.retry_after else None
                }
            )
        
        # Criar automaticamente
        character_data = CharacterCreate(name=clean_name, server=server, world=world)
        character = await service.create_character_with_snapshot(character_data, scrape_result.data)
        
        logger.info(f"Personagem {clean_name} criado automaticamente via busca")
        
        return await service.get_character_with_stats(character.id)
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erro na busca de personagem: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Erro interno do servidor")


@router.get("/{character_id}", response_model=CharacterResponse)
async def get_character(
    character_id: int,
    db: AsyncSession = Depends(get_db)
):
    """
    Obter detalhes de um personagem específico
    """
    try:
        service = CharacterService(db)
        character = await service.get_character_with_stats(character_id)
        
        if not character:
            raise HTTPException(status_code=404, detail="Personagem não encontrado")
        
        return character
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erro ao obter personagem {character_id}: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Erro interno do servidor")


@router.put("/{character_id}", response_model=CharacterResponse)
async def update_character(
    character_id: int,
    character_data: CharacterUpdate,
    db: AsyncSession = Depends(get_db)
):
    """
    Atualizar configurações de um personagem
    """
    try:
        service = CharacterService(db)
        character = await service.update_character(character_id, character_data)
        
        if not character:
            raise HTTPException(status_code=404, detail="Personagem não encontrado")
        
        return await service.get_character_with_stats(character.id)
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erro ao atualizar personagem {character_id}: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Erro interno do servidor")


@router.post("/{character_id}/favorite", response_model=SuccessResponse)
async def toggle_favorite(
    character_id: int,
    favorite_data: CharacterFavoriteRequest,
    db: AsyncSession = Depends(get_db)
):
    """
    Favoritar/desfavoritar um personagem
    """
    try:
        service = CharacterService(db)
        success = await service.set_favorite(character_id, favorite_data.is_favorited)
        
        if not success:
            raise HTTPException(status_code=404, detail="Personagem não encontrado")
        
        action = "favoritado" if favorite_data.is_favorited else "desfavoritado"
        return SuccessResponse(message=f"Personagem {action} com sucesso")
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erro ao favoritar personagem {character_id}: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Erro interno do servidor")


@router.post("/{character_id}/refresh", response_model=CharacterResponse)
async def refresh_character(
    character_id: int,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db)
):
    """
    Atualizar dados do personagem manualmente
    """
    try:
        service = CharacterService(db)
        character = await service.get_character(character_id)
        
        if not character:
            raise HTTPException(status_code=404, detail="Personagem não encontrado")
        
        # Fazer scraping
        scrape_result = await scrape_character_data(character.server, character.world, character.name)
        
        if not scrape_result.success:
            raise HTTPException(
                status_code=422,
                detail={
                    "message": "Não foi possível atualizar dados do personagem",
                    "error": scrape_result.error_message
                }
            )
        
        # Criar novo snapshot
        await service.create_snapshot(character.id, scrape_result.data, "manual")
        
        # Agendar próxima atualização automática
        background_tasks.add_task(service.schedule_next_update, character.id)
        
        logger.info(f"Personagem {character.name} atualizado manualmente")
        
        return await service.get_character_with_stats(character.id)
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erro ao atualizar personagem {character_id}: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Erro interno do servidor")


@router.get("/{character_id}/stats", response_model=CharacterStatsResponse)
async def get_character_stats(
    character_id: int,
    days: int = Query(30, ge=1, le=365, description="Período em dias para estatísticas"),
    db: AsyncSession = Depends(get_db)
):
    """
    Obter estatísticas detalhadas de um personagem
    """
    try:
        service = CharacterService(db)
        stats = await service.get_character_statistics(character_id, days)
        
        if not stats:
            raise HTTPException(status_code=404, detail="Personagem não encontrado")
        
        return stats
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erro ao obter estatísticas do personagem {character_id}: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Erro interno do servidor")


@router.delete("/{character_id}", response_model=SuccessResponse)
async def delete_character(
    character_id: int,
    db: AsyncSession = Depends(get_db)
):
    """
    Remover um personagem e todos seus dados
    """
    try:
        service = CharacterService(db)
        success = await service.delete_character(character_id)
        
        if not success:
            raise HTTPException(status_code=404, detail="Personagem não encontrado")
        
        return SuccessResponse(message="Personagem removido com sucesso")
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erro ao deletar personagem {character_id}: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Erro interno do servidor")


@router.get("/stats/global", response_model=dict)
async def get_global_stats(db: AsyncSession = Depends(get_db)):
    """
    Obter estatísticas globais da plataforma
    """
    try:
        service = CharacterService(db)
        stats = await service.get_global_statistics()
        
        return stats
        
    except Exception as e:
        logger.error(f"Erro ao obter estatísticas globais: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Erro interno do servidor") 