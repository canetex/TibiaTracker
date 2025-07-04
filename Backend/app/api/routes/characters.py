"""
Rotas da API para gerenciamento de personagens
==============================================

Endpoints para CRUD de personagens e seus snapshots históricos.
"""

from fastapi import APIRouter, Depends, HTTPException, Query, Path
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, desc, and_, or_
from sqlalchemy.orm import selectinload
from typing import List, Optional
from datetime import datetime, timedelta
import logging

from app.db.database import get_db
from app.models.character import Character as CharacterModel, CharacterSnapshot as CharacterSnapshotModel
from app.schemas.character import (
    CharacterCreate, CharacterUpdate, Character as CharacterSchema,
    CharacterWithSnapshots, CharacterSummary, CharacterListResponse,
    CharacterSnapshotCreate, CharacterSnapshot as CharacterSnapshotSchema,
    CharacterEvolution, CharacterEvolutionResponse, CharacterStats,
    SnapshotListResponse
)
from app.services.character import CharacterService
from app.services.scraping import scrape_character_data, get_supported_servers, get_server_info, is_server_supported, is_world_supported

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/characters", tags=["characters"])


# ===== ENDPOINTS DE INFORMAÇÃO =====

@router.get("/supported-servers")
async def get_supported_servers_info():
    """Listar todos os servidores suportados e suas informações"""
    
    servers = get_supported_servers()
    server_details = {}
    
    for server in servers:
        info = get_server_info(server)
        if info:
            server_details[server] = info
    
    return {
        "supported_servers": servers,
        "server_details": server_details,
        "total_servers": len(servers)
    }


@router.get("/server-info/{server}")
async def get_server_details(server: str):
    """Obter informações detalhadas de um servidor específico"""
    
    info = get_server_info(server)
    if not info:
        raise HTTPException(
            status_code=404, 
            detail=f"Servidor '{server}' não suportado. Use /supported-servers para ver servidores disponíveis"
        )
    
    return {
        "server": server,
        "info": info
    }


@router.get("/server-worlds/{server}")
async def get_server_world_details(server: str):
    """Obter configurações detalhadas de todos os mundos de um servidor"""
    
    if not is_server_supported(server):
        raise HTTPException(
            status_code=404,
            detail=f"Servidor '{server}' não suportado. Use /supported-servers para ver servidores disponíveis"
        )
    
    # Para o Taleon, retornar configurações detalhadas por mundo
    if server.lower() == "taleon":
        from app.services.scraping.taleon import TaleonCharacterScraper
        scraper = TaleonCharacterScraper()
        world_details = scraper.get_world_details()
        
        return {
            "server": server,
            "worlds_count": len(world_details),
            "worlds": world_details
        }
    
    # Para outros servidores futuros, retornar informação básica
    server_info = get_server_info(server)
    return {
        "server": server,
        "worlds_count": len(server_info["supported_worlds"]),
        "worlds": {world: {"name": world.title()} for world in server_info["supported_worlds"]}
    }


@router.get("/server-worlds/{server}/{world}")
async def get_specific_world_details(server: str, world: str):
    """Obter configurações específicas de um mundo"""
    
    if not is_server_supported(server):
        raise HTTPException(
            status_code=404,
            detail=f"Servidor '{server}' não suportado"
        )
    
    if not is_world_supported(server, world):
        raise HTTPException(
            status_code=404,
            detail=f"Mundo '{world}' não suportado pelo servidor '{server}'"
        )
    
    # Para o Taleon, retornar configuração detalhada
    if server.lower() == "taleon":
        from app.services.scraping.taleon import TaleonCharacterScraper
        scraper = TaleonCharacterScraper()
        world_config = scraper.get_world_config_info(world)
        
        return {
            "server": server,
            "world": world,
            "config": world_config
        }
    
    # Para outros servidores, retornar informação básica
    return {
        "server": server,
        "world": world,
        "config": {
            "name": world.title(),
            "supported": True
        }
    }


# ===== ENDPOINTS DE TESTE =====

@router.get("/search")
async def search_character(
    name: str = Query(..., description="Nome do personagem"),
    server: str = Query(..., description="Servidor (taleon, rubini, etc)"), 
    world: str = Query(..., description="World (san, aura, gaia)"),
    db: AsyncSession = Depends(get_db)
):
    """Buscar personagem - se não existir, faz scraping e cria"""
    
    try:
        # Primeiro verificar se já existe no banco
        existing_query = select(CharacterModel).where(
            and_(
                CharacterModel.name.ilike(name),
                CharacterModel.server == server.lower(),
                CharacterModel.world == world.lower()
            )
        ).options(selectinload(CharacterModel.snapshots))
        
        result = await db.execute(existing_query)
        existing_character = result.scalar_one_or_none()
        
        if existing_character:
            # Personagem já existe, retornar dados existentes
            # Obter snapshot mais recente
            latest_snapshot = None
            if existing_character.snapshots:
                latest_snapshot = sorted(existing_character.snapshots, key=lambda x: x.scraped_at, reverse=True)[0]
            
            return {
                "success": True,
                "message": f"Personagem '{existing_character.name}' encontrado no banco de dados",
                "character": {
                    "id": existing_character.id,
                    "name": existing_character.name,
                    "server": existing_character.server,
                    "world": existing_character.world,
                    "level": existing_character.level,
                    "vocation": existing_character.vocation,
                    "outfit_image_url": existing_character.outfit_image_url,
                    "last_scraped_at": existing_character.last_scraped_at,
                    "is_favorited": existing_character.is_favorited,
                    "latest_snapshot": {
                        "level": latest_snapshot.level if latest_snapshot else existing_character.level,
                        "experience": latest_snapshot.experience if latest_snapshot else 0,
                        "deaths": latest_snapshot.deaths if latest_snapshot else 0,
                        "charm_points": latest_snapshot.charm_points if latest_snapshot else None,
                        "bosstiary_points": latest_snapshot.bosstiary_points if latest_snapshot else None,
                        "achievement_points": latest_snapshot.achievement_points if latest_snapshot else None,
                        "scraped_at": latest_snapshot.scraped_at if latest_snapshot else None
                    } if latest_snapshot else None
                },
                "from_database": True
            }
        
        # Personagem não existe, fazer scraping
        scrape_result = await scrape_character_data(server, world, name)
        
        if not scrape_result.success:
            raise HTTPException(
                status_code=422,
                detail={
                    "message": "Personagem não encontrado ou erro no scraping",
                    "error": scrape_result.error_message,
                    "retry_after": scrape_result.retry_after.isoformat() if scrape_result.retry_after else None
                }
            )
        
        scraped_data = scrape_result.data
        
        # Criar personagem no banco
        character = CharacterModel(
            name=scraped_data['name'],
            server=server.lower(),
            world=world.lower(),
            level=scraped_data['level'],
            vocation=scraped_data['vocation'],
            residence=scraped_data.get('residence'),
            profile_url=scraped_data.get('profile_url'),
            outfit_image_url=scraped_data.get('outfit_image_url'),
            is_active=True,
            is_public=True,
            is_favorited=False,
            last_scraped_at=datetime.utcnow()
        )
        
        db.add(character)
        await db.flush()  # Para obter o ID
        
        # Criar primeiro snapshot
        snapshot = CharacterSnapshotModel(
            character_id=character.id,
            level=scraped_data['level'],
            experience=scraped_data.get('experience', 0),
            deaths=scraped_data.get('deaths', 0),
            charm_points=scraped_data.get('charm_points'),
            bosstiary_points=scraped_data.get('bosstiary_points'),
            achievement_points=scraped_data.get('achievement_points'),
            vocation=scraped_data['vocation'],
            world=world.lower(),
            residence=scraped_data.get('residence'),
            house=scraped_data.get('house'),
            guild=scraped_data.get('guild'),
            guild_rank=scraped_data.get('guild_rank'),
            is_online=scraped_data.get('is_online', False),
            last_login=scraped_data.get('last_login'),
            outfit_image_url=scraped_data.get('outfit_image_url'),
            scraped_at=datetime.utcnow(),
            scrape_source="search",
            scrape_duration=scrape_result.duration_ms
        )
        
        db.add(snapshot)
        await db.commit()
        await db.refresh(character)
        
        return {
            "success": True,
            "message": f"Personagem '{character.name}' encontrado e adicionado com sucesso!",
            "character": {
                "id": character.id,
                "name": character.name,
                "server": character.server,
                "world": character.world,
                "level": character.level,
                "vocation": character.vocation,
                "outfit_image_url": character.outfit_image_url,
                "last_scraped_at": character.last_scraped_at,
                "is_favorited": character.is_favorited,
                "latest_snapshot": {
                    "level": snapshot.level,
                    "experience": snapshot.experience,
                    "deaths": snapshot.deaths,
                    "charm_points": snapshot.charm_points,
                    "bosstiary_points": snapshot.bosstiary_points,
                    "achievement_points": snapshot.achievement_points,
                    "scraped_at": snapshot.scraped_at
                }
            },
            "scraping_duration_ms": scrape_result.duration_ms,
            "from_database": False
        }
        
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f"Erro interno: {str(e)}")


@router.get("/test-scraping/{server}/{world}/{character_name}")
async def test_scraping(
    server: str,
    world: str, 
    character_name: str
):
    """Endpoint de teste para scraping - NÃO salva no banco"""
    
    try:
        result = await scrape_character_data(server, world, character_name)
        
        if result.success:
            return {
                "success": True,
                "message": f"Scraping realizado com sucesso em {result.duration_ms}ms",
                "data": result.data,
                "duration_ms": result.duration_ms
            }
        else:
            return {
                "success": False,
                "error": result.error_message,
                "retry_after": result.retry_after.isoformat() if result.retry_after else None
            }
            
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro no teste de scraping: {str(e)}")


@router.post("/scrape-and-create")
async def scrape_and_create_character(
    server: str = Query(..., description="Servidor (taleon, rubini, etc)"),
    world: str = Query(..., description="World (san, aura, gaia)"),
    character_name: str = Query(..., description="Nome do personagem"),
    db: AsyncSession = Depends(get_db)
):
    """Fazer scraping e criar personagem + primeiro snapshot"""
    
    try:
        # Verificar se já existe
        existing_query = select(CharacterModel).where(
            and_(
                CharacterModel.name.ilike(character_name),
                CharacterModel.server == server.lower(),
                CharacterModel.world == world.lower()
            )
        )
        result = await db.execute(existing_query)
        existing_character = result.scalar_one_or_none()
        
        if existing_character:
            return {
                "success": False,
                "message": f"Personagem '{character_name}' já existe no servidor '{server}' world '{world}'",
                "character_id": existing_character.id
            }
        
        # Fazer scraping
        scrape_result = await scrape_character_data(server, world, character_name)
        
        if not scrape_result.success:
            raise HTTPException(
                status_code=422,
                detail={
                    "message": "Falha no scraping",
                    "error": scrape_result.error_message,
                    "retry_after": scrape_result.retry_after.isoformat() if scrape_result.retry_after else None
                }
            )
        
        scraped_data = scrape_result.data
        
        # Criar personagem
        character = CharacterModel(
            name=scraped_data['name'],
            server=server.lower(),
            world=world.lower(),
            level=scraped_data['level'],
            vocation=scraped_data['vocation'],
            residence=scraped_data.get('residence'),
            profile_url=scraped_data.get('profile_url'),
            outfit_image_url=scraped_data.get('outfit_image_url'),
            is_active=True,
            is_public=True,
            is_favorited=False,
            last_scraped_at=datetime.utcnow()
        )
        
        db.add(character)
        await db.flush()  # Para obter o ID
        
        # Criar primeiro snapshot
        snapshot = CharacterSnapshotModel(
            character_id=character.id,
            level=scraped_data['level'],
            experience=scraped_data.get('experience', 0),
            deaths=scraped_data.get('deaths', 0),
            charm_points=scraped_data.get('charm_points'),
            bosstiary_points=scraped_data.get('bosstiary_points'),
            achievement_points=scraped_data.get('achievement_points'),
            vocation=scraped_data['vocation'],
            world=world.lower(),
            residence=scraped_data.get('residence'),
            house=scraped_data.get('house'),
            guild=scraped_data.get('guild'),
            guild_rank=scraped_data.get('guild_rank'),
            is_online=scraped_data.get('is_online', False),
            last_login=scraped_data.get('last_login'),
            outfit_image_url=scraped_data.get('outfit_image_url'),
            scraped_at=datetime.utcnow(),
            scrape_source="manual",
            scrape_duration=scrape_result.duration_ms
        )
        
        db.add(snapshot)
        await db.commit()
        await db.refresh(character)
        
        return {
            "success": True,
            "message": f"Personagem '{character.name}' criado com sucesso!",
            "character": {
                "id": character.id,
                "name": character.name,
                "server": character.server,
                "world": character.world,
                "level": character.level,
                "vocation": character.vocation,
                "outfit_image_url": character.outfit_image_url
            },
            "scraping_duration_ms": scrape_result.duration_ms,
            "scraped_data": scraped_data
        }
        
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f"Erro interno: {str(e)}")


@router.post("/scrape-with-history")
async def scrape_character_with_history(
    server: str = Query(..., description="Servidor (taleon, rubini, etc)"),
    world: str = Query(..., description="World (san, aura, gaia)"),
    character_name: str = Query(..., description="Nome do personagem"),
    db: AsyncSession = Depends(get_db)
):
    """Fazer scraping e salvar histórico completo de experiência"""
    
    try:
        # Verificar se já existe
        existing_query = select(CharacterModel).where(
            and_(
                CharacterModel.name.ilike(character_name),
                CharacterModel.server == server.lower(),
                CharacterModel.world == world.lower()
            )
        )
        result = await db.execute(existing_query)
        existing_character = result.scalar_one_or_none()
        
        # Fazer scraping
        scrape_result = await scrape_character_data(server, world, character_name)
        
        if not scrape_result.success:
            raise HTTPException(
                status_code=422,
                detail={
                    "message": "Falha no scraping",
                    "error": scrape_result.error_message,
                    "retry_after": scrape_result.retry_after.isoformat() if scrape_result.retry_after else None
                }
            )
        
        scraped_data = scrape_result.data
        
        # Obter histórico de experiência se disponível
        history_data = scraped_data.get('experience_history', [])
        
        logger.info(f"[SCRAPE-WITH-HISTORY] Personagem {character_name}: {len(history_data)} entradas de histórico encontradas")
        logger.info(f"[SCRAPE-WITH-HISTORY] Dados completos do scraping: {scraped_data.keys()}")
        logger.info(f"[SCRAPE-WITH-HISTORY] experience_history: {history_data}")
        
        character = existing_character
        if not character:
            # Criar personagem se não existe
            character = CharacterModel(
                name=scraped_data['name'],
                server=server.lower(),
                world=world.lower(),
                level=scraped_data['level'],
                vocation=scraped_data['vocation'],
                residence=scraped_data.get('residence'),
                profile_url=scraped_data.get('profile_url'),
                outfit_image_url=scraped_data.get('outfit_image_url'),
                is_active=True,
                is_public=True,
                is_favorited=False,
                last_scraped_at=datetime.utcnow()
            )
            
            db.add(character)
            await db.flush()  # Para obter o ID
        else:
            # Atualizar personagem existente
            character.level = scraped_data['level']
            character.vocation = scraped_data['vocation']
            character.residence = scraped_data.get('residence')
            character.outfit_image_url = scraped_data.get('outfit_image_url')
            character.last_scraped_at = datetime.utcnow()
        
        snapshots_created = 0
        snapshots_updated = 0
        
        # Criar/atualizar snapshots para cada entrada do histórico
        if history_data:
            for entry in history_data:
                # Verificar se já existe snapshot para esta data
                existing_snapshot_query = select(CharacterSnapshotModel).where(
                    and_(
                        CharacterSnapshotModel.character_id == character.id,
                        func.date(CharacterSnapshotModel.scraped_at) == entry['date']
                    )
                )
                snapshot_result = await db.execute(existing_snapshot_query)
                existing_snapshot = snapshot_result.scalar_one_or_none()
                
                snapshot_date = datetime.combine(entry['date'], datetime.min.time())
                
                if existing_snapshot:
                    # SOBRESCREVER dados existentes com informações mais recentes
                    logger.info(f"Atualizando snapshot existente para {entry['date']}: "
                              f"experiência {existing_snapshot.experience:,} → {entry['experience_gained']:,}")
                    
                    existing_snapshot.level = scraped_data['level']
                    existing_snapshot.experience = entry['experience_gained']  # SOBRESCREVER
                    existing_snapshot.deaths = scraped_data.get('deaths', 0)
                    existing_snapshot.charm_points = scraped_data.get('charm_points')
                    existing_snapshot.bosstiary_points = scraped_data.get('bosstiary_points')
                    existing_snapshot.achievement_points = scraped_data.get('achievement_points')
                    existing_snapshot.vocation = scraped_data['vocation']
                    existing_snapshot.world = world.lower()
                    existing_snapshot.residence = scraped_data.get('residence')
                    existing_snapshot.house = scraped_data.get('house')
                    existing_snapshot.guild = scraped_data.get('guild')
                    existing_snapshot.guild_rank = scraped_data.get('guild_rank')
                    existing_snapshot.is_online = scraped_data.get('is_online', False)
                    existing_snapshot.last_login = scraped_data.get('last_login')
                    existing_snapshot.outfit_image_url = scraped_data.get('outfit_image_url')
                    existing_snapshot.scrape_source = "history_update"  # Marcar como atualização
                    existing_snapshot.scrape_duration = scrape_result.duration_ms
                    # scraped_at mantém a data original do snapshot
                    
                    snapshots_updated += 1  # Contar como atualizado
                else:
                    # Criar novo snapshot para esta data
                    logger.info(f"Criando novo snapshot para {entry['date']}: "
                              f"experiência {entry['experience_gained']:,}")
                    
                    snapshot = CharacterSnapshotModel(
                        character_id=character.id,
                        level=scraped_data['level'],  # Usar level atual para todos
                        experience=entry['experience_gained'],  # Experiência específica do dia
                        deaths=scraped_data.get('deaths', 0),
                        charm_points=scraped_data.get('charm_points'),
                        bosstiary_points=scraped_data.get('bosstiary_points'),
                        achievement_points=scraped_data.get('achievement_points'),
                        vocation=scraped_data['vocation'],
                        world=world.lower(),
                        residence=scraped_data.get('residence'),
                        house=scraped_data.get('house'),
                        guild=scraped_data.get('guild'),
                        guild_rank=scraped_data.get('guild_rank'),
                        is_online=scraped_data.get('is_online', False),
                        last_login=scraped_data.get('last_login'),
                        outfit_image_url=scraped_data.get('outfit_image_url'),
                        scraped_at=snapshot_date,
                        scrape_source="history",
                        scrape_duration=scrape_result.duration_ms
                    )
                    
                    db.add(snapshot)
                    snapshots_created += 1
        else:
            # Se não há histórico, criar snapshot apenas atual
            snapshot = CharacterSnapshotModel(
                character_id=character.id,
                level=scraped_data['level'],
                experience=scraped_data.get('experience', 0),
                deaths=scraped_data.get('deaths', 0),
                charm_points=scraped_data.get('charm_points'),
                bosstiary_points=scraped_data.get('bosstiary_points'),
                achievement_points=scraped_data.get('achievement_points'),
                vocation=scraped_data['vocation'],
                world=world.lower(),
                residence=scraped_data.get('residence'),
                house=scraped_data.get('house'),
                guild=scraped_data.get('guild'),
                guild_rank=scraped_data.get('guild_rank'),
                is_online=scraped_data.get('is_online', False),
                last_login=scraped_data.get('last_login'),
                outfit_image_url=scraped_data.get('outfit_image_url'),
                scraped_at=datetime.utcnow(),
                scrape_source="manual",
                scrape_duration=scrape_result.duration_ms
            )
            
            db.add(snapshot)
            snapshots_created = 1
            snapshots_updated = 0
        
        await db.commit()
        await db.refresh(character)
        
        return {
            "success": True,
            "message": f"Personagem '{character.name}' processado com sucesso!",
            "character": {
                "id": character.id,
                "name": character.name,
                "server": character.server,
                "world": character.world,
                "level": character.level,
                "vocation": character.vocation,
                "outfit_image_url": character.outfit_image_url
            },
            "snapshots_created": snapshots_created,
            "snapshots_updated": snapshots_updated,
            "total_snapshots_processed": snapshots_created + snapshots_updated,
            "history_entries": len(history_data),
            "scraping_duration_ms": scrape_result.duration_ms,
            "scraped_data": scraped_data
        }
        
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f"Erro interno: {str(e)}")


# ===== ENDPOINTS DE PERSONAGENS =====

@router.get("/recent")
async def get_recent_characters(
    limit: int = Query(10, ge=1, le=50, description="Número máximo de personagens"),
    db: AsyncSession = Depends(get_db)
):
    """Obter personagens adicionados recentemente"""
    try:
        result = await db.execute(
            select(CharacterModel)
            .where(CharacterModel.is_active == True)
            .order_by(desc(CharacterModel.created_at))
            .limit(limit)
        )
        characters = result.scalars().all()
        
        # Converter para formato do frontend
        response_data = []
        for char in characters:
            # Obter último snapshot
            snapshot_result = await db.execute(
                select(CharacterSnapshotModel)
                .where(CharacterSnapshotModel.character_id == char.id)
                .order_by(desc(CharacterSnapshotModel.scraped_at))
                .limit(1)
            )
            latest_snapshot = snapshot_result.scalar_one_or_none()
            
            # Contar total de snapshots
            count_result = await db.execute(
                select(func.count(CharacterSnapshotModel.id))
                .where(CharacterSnapshotModel.character_id == char.id)
            )
            total_snapshots = count_result.scalar()
            
            char_data = {
                "id": char.id,
                "name": char.name,
                "server": char.server,
                "world": char.world,
                "level": char.level,
                "vocation": char.vocation,
                "outfit_image_url": char.outfit_image_url,
                "last_scraped_at": char.last_scraped_at,
                "is_favorited": char.is_favorited,
                "total_snapshots": total_snapshots,
                "latest_snapshot": None
            }
            
            if latest_snapshot:
                char_data["latest_snapshot"] = {
                    "level": latest_snapshot.level,
                    "experience": latest_snapshot.experience,
                    "deaths": latest_snapshot.deaths,
                    "charm_points": latest_snapshot.charm_points,
                    "bosstiary_points": latest_snapshot.bosstiary_points,
                    "achievement_points": latest_snapshot.achievement_points,
                    "scraped_at": latest_snapshot.scraped_at
                }
            
            response_data.append(char_data)
        
        return response_data
        
    except Exception as e:
        logger.error(f"Erro ao obter personagens recentes: {e}")
        return []


@router.get("/stats/global")
async def get_global_stats(db: AsyncSession = Depends(get_db)):
    """Obter estatísticas globais da plataforma"""
    try:
        # Total de personagens
        total_chars_result = await db.execute(
            select(func.count(CharacterModel.id)).where(CharacterModel.is_active == True)
        )
        total_characters = total_chars_result.scalar() or 0

        # Total de snapshots
        total_snapshots_result = await db.execute(
            select(func.count(CharacterSnapshotModel.id))
        )
        total_snapshots = total_snapshots_result.scalar() or 0

        # Personagens favoritados
        favorited_result = await db.execute(
            select(func.count(CharacterModel.id))
            .where(and_(CharacterModel.is_active == True, CharacterModel.is_favorited == True))
        )
        favorited_characters = favorited_result.scalar() or 0

        # Personagens por servidor
        server_stats_result = await db.execute(
            select(CharacterModel.server, func.count(CharacterModel.id))
            .where(CharacterModel.is_active == True)
            .group_by(CharacterModel.server)
        )
        server_stats = {server: count for server, count in server_stats_result.fetchall()}

        return {
            "total_characters": total_characters,
            "total_snapshots": total_snapshots,
            "favorited_characters": favorited_characters,
            "characters_by_server": server_stats,
            "last_updated": datetime.utcnow().isoformat()
        }

    except Exception as e:
        logger.error(f"Erro ao obter estatísticas globais: {e}")
        return {
            "total_characters": 0,
            "total_snapshots": 0,
            "favorited_characters": 0,
            "characters_by_server": {},
            "last_updated": datetime.utcnow().isoformat()
        }


@router.get("", response_model=CharacterListResponse)
async def list_characters(
    skip: int = Query(0, ge=0, description="Número de registros a pular"),
    limit: int = Query(50, ge=1, le=100, description="Número máximo de registros"),
    server: Optional[str] = Query(None, description="Filtrar por servidor"),
    world: Optional[str] = Query(None, description="Filtrar por world"),
    is_active: Optional[bool] = Query(None, description="Filtrar por personagens ativos"),
    is_favorited: Optional[bool] = Query(None, description="Filtrar por favoritos"),
    search: Optional[str] = Query(None, description="Buscar por nome do personagem"),
    db: AsyncSession = Depends(get_db)
):
    """Listar personagens com filtros e paginação"""
    
    query = select(CharacterModel)
    
    # Aplicar filtros
    filters = []
    if server:
        filters.append(CharacterModel.server == server)
    if world:
        filters.append(CharacterModel.world == world)
    if is_active is not None:
        filters.append(CharacterModel.is_active == is_active)
    if is_favorited is not None:
        filters.append(CharacterModel.is_favorited == is_favorited)
    if search:
        filters.append(CharacterModel.name.ilike(f"%{search}%"))
    
    if filters:
        query = query.where(and_(*filters))
    
    # Contar total
    count_query = select(func.count(CharacterModel.id)).where(and_(*filters)) if filters else select(func.count(CharacterModel.id))
    result = await db.execute(count_query)
    total = result.scalar()
    
    # Aplicar paginação e ordenação
    query = query.order_by(CharacterModel.name).offset(skip).limit(limit)
    
    result = await db.execute(query)
    characters = result.scalars().all()
    
    # Converter para schema resumido
    character_summaries = []
    for char in characters:
        # Contar snapshots para cada personagem
        snapshot_count_query = select(func.count(CharacterSnapshotModel.id)).where(CharacterSnapshotModel.character_id == char.id)
        snapshot_result = await db.execute(snapshot_count_query)
        snapshots_count = snapshot_result.scalar()
        
        summary = CharacterSummary(
            id=char.id,
            name=char.name,
            server=char.server,
            world=char.world,
            level=char.level,
            vocation=char.vocation,
            is_active=char.is_active,
            is_favorited=char.is_favorited,
            last_scraped_at=char.last_scraped_at,
            snapshots_count=snapshots_count
        )
        character_summaries.append(summary)
    
    return CharacterListResponse(
        characters=character_summaries,
        total=total,
        page=skip // limit + 1,
        per_page=limit
    )


@router.get("/", response_model=CharacterListResponse)
async def list_characters_alias(
    skip: int = Query(0, ge=0, description="Número de registros a pular"),
    limit: int = Query(50, ge=1, le=100, description="Número máximo de registros"),
    server: Optional[str] = Query(None, description="Filtrar por servidor"),
    world: Optional[str] = Query(None, description="Filtrar por world"),
    is_active: Optional[bool] = Query(None, description="Filtrar por personagens ativos"),
    is_favorited: Optional[bool] = Query(None, description="Filtrar por favoritos"),
    search: Optional[str] = Query(None, description="Buscar por nome do personagem"),
    db: AsyncSession = Depends(get_db)
):
    """Listar personagens com filtros e paginação (alias com barra para compatibilidade)"""
    
    # Chamamos a função principal
    return await list_characters(skip, limit, server, world, is_active, is_favorited, search, db)


@router.post("/", response_model=CharacterSchema)
async def create_character(
    character_data: CharacterCreate,
    db: AsyncSession = Depends(get_db)
):
    """Criar novo personagem"""
    
    # Verificar se já existe personagem com o mesmo nome/servidor/world
    existing_query = select(CharacterModel).where(
        and_(
            CharacterModel.name == character_data.name,
            CharacterModel.server == character_data.server,
            CharacterModel.world == character_data.world
        )
    )
    result = await db.execute(existing_query)
    existing_character = result.scalar_one_or_none()
    
    if existing_character:
        raise HTTPException(
            status_code=400,
            detail=f"Personagem '{character_data.name}' já existe no servidor '{character_data.server}' world '{character_data.world}'"
        )
    
    # Criar novo personagem
    character = CharacterModel(**character_data.dict())
    db.add(character)
    await db.commit()
    await db.refresh(character)
    
    return character


@router.get("/{character_id}", response_model=CharacterWithSnapshots)
async def get_character(
    character_id: int,
    include_snapshots: bool = Query(True, description="Incluir snapshots no response"),
    snapshots_limit: int = Query(30, ge=1, le=100, description="Limite de snapshots mais recentes"),
    db: AsyncSession = Depends(get_db)
):
    """Obter personagem por ID com snapshots opcionais"""
    
    query = select(CharacterModel).where(CharacterModel.id == character_id)
    
    if include_snapshots:
        query = query.options(selectinload(CharacterModel.snapshots))
    
    result = await db.execute(query)
    character = result.scalar_one_or_none()
    
    if not character:
        raise HTTPException(status_code=404, detail="Personagem não encontrado")
    
    if include_snapshots and character.snapshots:
        # Limitar snapshots aos mais recentes
        character.snapshots = sorted(character.snapshots, key=lambda x: x.scraped_at, reverse=True)[:snapshots_limit]
    
    return character


@router.put("/{character_id}", response_model=CharacterSchema)
async def update_character(
    character_id: int,
    character_data: CharacterUpdate,
    db: AsyncSession = Depends(get_db)
):
    """Atualizar personagem"""
    
    result = await db.execute(select(CharacterModel).where(CharacterModel.id == character_id))
    character = result.scalar_one_or_none()
    
    if not character:
        raise HTTPException(status_code=404, detail="Personagem não encontrado")
    
    # Atualizar apenas campos fornecidos
    update_data = character_data.dict(exclude_unset=True)
    for field, value in update_data.items():
        setattr(character, field, value)
    
    await db.commit()
    await db.refresh(character)
    
    return character


@router.delete("/{character_id}")
async def delete_character(
    character_id: int,
    db: AsyncSession = Depends(get_db)
):
    """Deletar personagem e todos os seus snapshots"""
    
    result = await db.execute(select(CharacterModel).where(CharacterModel.id == character_id))
    character = result.scalar_one_or_none()
    
    if not character:
        raise HTTPException(status_code=404, detail="Personagem não encontrado")
    
    await db.delete(character)
    await db.commit()
    
    return {"message": f"Personagem '{character.name}' deletado com sucesso"}


# ===== ENDPOINTS DE SNAPSHOTS =====

@router.post("/{character_id}/snapshots", response_model=CharacterSnapshotSchema)
async def create_snapshot(
    character_id: int,
    snapshot_data: CharacterSnapshotCreate,
    db: AsyncSession = Depends(get_db)
):
    """Criar novo snapshot para o personagem"""
    
    # Verificar se personagem existe
    result = await db.execute(select(CharacterModel).where(CharacterModel.id == character_id))
    character = result.scalar_one_or_none()
    
    if not character:
        raise HTTPException(status_code=404, detail="Personagem não encontrado")
    
    # Criar snapshot
    snapshot_data.character_id = character_id
    snapshot = CharacterSnapshotModel(**snapshot_data.dict())
    db.add(snapshot)
    
    # Atualizar dados atuais do personagem
    character.level = snapshot_data.level
    character.vocation = snapshot_data.vocation
    character.world = snapshot_data.world
    character.residence = snapshot_data.residence
    character.outfit_image_url = snapshot_data.outfit_image_url
    character.last_scraped_at = datetime.utcnow()
    
    await db.commit()
    await db.refresh(snapshot)
    
    return snapshot


@router.get("/{character_id}/snapshots", response_model=SnapshotListResponse)
async def list_character_snapshots(
    character_id: int,
    skip: int = Query(0, ge=0, description="Número de registros a pular"),
    limit: int = Query(50, ge=1, le=100, description="Número máximo de registros"),
    start_date: Optional[datetime] = Query(None, description="Data inicial (YYYY-MM-DD)"),
    end_date: Optional[datetime] = Query(None, description="Data final (YYYY-MM-DD)"),
    db: AsyncSession = Depends(get_db)
):
    """Listar snapshots de um personagem com filtros"""
    
    # Verificar se personagem existe
    result = await db.execute(select(CharacterModel).where(CharacterModel.id == character_id))
    character = result.scalar_one_or_none()
    
    if not character:
        raise HTTPException(status_code=404, detail="Personagem não encontrado")
    
    query = select(CharacterSnapshotModel).where(CharacterSnapshotModel.character_id == character_id)
    
    # Aplicar filtros de data
    filters = []
    if start_date:
        filters.append(CharacterSnapshotModel.scraped_at >= start_date)
    if end_date:
        filters.append(CharacterSnapshotModel.scraped_at <= end_date)
    
    if filters:
        query = query.where(and_(*filters))
    
    # Contar total
    count_query = select(func.count(CharacterSnapshotModel.id)).where(CharacterSnapshotModel.character_id == character_id)
    if filters:
        count_query = count_query.where(and_(*filters))
    
    result = await db.execute(count_query)
    total = result.scalar()
    
    # Aplicar paginação e ordenação (mais recentes primeiro)
    query = query.order_by(desc(CharacterSnapshotModel.scraped_at)).offset(skip).limit(limit)
    
    result = await db.execute(query)
    snapshots = result.scalars().all()
    
    return SnapshotListResponse(
        snapshots=snapshots,
        total=total,
        page=skip // limit + 1,
        per_page=limit
    )


@router.get("/{character_id}/evolution", response_model=CharacterEvolutionResponse)
async def get_character_evolution(
    character_id: int,
    days: int = Query(30, ge=1, le=365, description="Número de dias para análise"),
    db: AsyncSession = Depends(get_db)
):
    """Obter dados de evolução do personagem em um período"""
    
    # Verificar se personagem existe
    result = await db.execute(select(CharacterModel).where(CharacterModel.id == character_id))
    character = result.scalar_one_or_none()
    
    if not character:
        raise HTTPException(status_code=404, detail="Personagem não encontrado")
    
    # Data de início da análise
    end_date = datetime.utcnow()
    start_date = end_date - timedelta(days=days)
    
    # Obter snapshots do período
    snapshots_query = select(CharacterSnapshotModel).where(
        and_(
            CharacterSnapshotModel.character_id == character_id,
            CharacterSnapshotModel.scraped_at >= start_date,
            CharacterSnapshotModel.scraped_at <= end_date
        )
    ).order_by(CharacterSnapshotModel.scraped_at)
    
    result = await db.execute(snapshots_query)
    snapshots = result.scalars().all()
    
    if not snapshots:
        raise HTTPException(status_code=404, detail="Nenhum snapshot encontrado no período")
    
    # Calcular evolução
    first_snapshot = snapshots[0]
    last_snapshot = snapshots[-1]
    
    # Detectar mudanças de world
    world_changes = []
    current_world = first_snapshot.world
    for snapshot in snapshots[1:]:
        if snapshot.world != current_world:
            world_changes.append(f"{current_world} -> {snapshot.world} em {snapshot.scraped_at.strftime('%Y-%m-%d')}")
            current_world = snapshot.world
    
    evolution = CharacterEvolution(
        character_id=character_id,
        character_name=character.name,
        period_start=first_snapshot.scraped_at,
        period_end=last_snapshot.scraped_at,
        level_start=first_snapshot.level,
        level_end=last_snapshot.level,
        level_gained=last_snapshot.level - first_snapshot.level,
        experience_start=first_snapshot.experience,
        experience_end=last_snapshot.experience,
        experience_gained=last_snapshot.experience - first_snapshot.experience,
        deaths_start=first_snapshot.deaths,
        deaths_end=last_snapshot.deaths,
        deaths_total=last_snapshot.deaths - first_snapshot.deaths,
        charm_points_start=first_snapshot.charm_points,
        charm_points_end=last_snapshot.charm_points,
        charm_points_gained=(last_snapshot.charm_points or 0) - (first_snapshot.charm_points or 0) if first_snapshot.charm_points and last_snapshot.charm_points else None,
        bosstiary_points_start=first_snapshot.bosstiary_points,
        bosstiary_points_end=last_snapshot.bosstiary_points,
        bosstiary_points_gained=(last_snapshot.bosstiary_points or 0) - (first_snapshot.bosstiary_points or 0) if first_snapshot.bosstiary_points and last_snapshot.bosstiary_points else None,
        achievement_points_start=first_snapshot.achievement_points,
        achievement_points_end=last_snapshot.achievement_points,
        achievement_points_gained=(last_snapshot.achievement_points or 0) - (first_snapshot.achievement_points or 0) if first_snapshot.achievement_points and last_snapshot.achievement_points else None,
        world_changes=world_changes
    )
    
    # Criar summary do personagem
    character_summary = CharacterSummary(
        id=character.id,
        name=character.name,
        server=character.server,
        world=character.world,
        level=character.level,
        vocation=character.vocation,
        is_active=character.is_active,
        is_favorited=character.is_favorited,
        last_scraped_at=character.last_scraped_at,
        snapshots_count=len(snapshots)
    )
    
    return CharacterEvolutionResponse(
        character=character_summary,
        evolution=evolution,
        snapshots=snapshots
    )


@router.get("/{character_id}/stats", response_model=CharacterStats)
async def get_character_stats(
    character_id: int,
    db: AsyncSession = Depends(get_db)
):
    """Obter estatísticas completas do personagem"""
    
    # Verificar se personagem existe
    result = await db.execute(select(CharacterModel).where(CharacterModel.id == character_id))
    character = result.scalar_one_or_none()
    
    if not character:
        raise HTTPException(status_code=404, detail="Personagem não encontrado")
    
    # Obter todos os snapshots
    snapshots_query = select(CharacterSnapshotModel).where(
        CharacterSnapshotModel.character_id == character_id
    ).order_by(CharacterSnapshotModel.scraped_at)
    
    result = await db.execute(snapshots_query)
    snapshots = result.scalars().all()
    
    if not snapshots:
        raise HTTPException(status_code=404, detail="Nenhum snapshot encontrado")
    
    # Calcular estatísticas
    highest_level_snapshot = max(snapshots, key=lambda x: x.level)
    highest_exp_snapshot = max(snapshots, key=lambda x: x.experience)
    
    # Calcular média de exp por dia
    if len(snapshots) > 1:
        total_days = (snapshots[-1].scraped_at - snapshots[0].scraped_at).days
        exp_gain = snapshots[-1].experience - snapshots[0].experience
        avg_daily_exp = exp_gain / total_days if total_days > 0 else 0
    else:
        avg_daily_exp = 0
    
    # Worlds visitados
    worlds_visited = list(set(snapshot.world for snapshot in snapshots))
    
    stats = CharacterStats(
        character_id=character_id,
        character_name=character.name,
        total_snapshots=len(snapshots),
        first_snapshot=snapshots[0].scraped_at,
        last_snapshot=snapshots[-1].scraped_at,
        highest_level=highest_level_snapshot.level,
        highest_level_date=highest_level_snapshot.scraped_at,
        highest_experience=highest_exp_snapshot.experience,
        highest_experience_date=highest_exp_snapshot.scraped_at,
        average_daily_exp_gain=avg_daily_exp,
        average_level_per_month=None,  # Implementar se necessário
        worlds_visited=worlds_visited
    )
    
    return stats


# ===== ENDPOINTS UTILITÁRIOS =====

@router.get("/{character_id}/toggle-favorite")
async def toggle_favorite(
    character_id: int,
    db: AsyncSession = Depends(get_db)
):
    """Alternar status de favorito do personagem"""
    
    result = await db.execute(select(CharacterModel).where(CharacterModel.id == character_id))
    character = result.scalar_one_or_none()
    
    if not character:
        raise HTTPException(status_code=404, detail="Personagem não encontrado")
    
    character.is_favorited = not character.is_favorited
    await db.commit()
    
    status = "adicionado aos" if character.is_favorited else "removido dos"
    return {"message": f"Personagem '{character.name}' {status} favoritos"}


@router.get("/{character_id}/toggle-active")
async def toggle_active(
    character_id: int,
    db: AsyncSession = Depends(get_db)
):
    """Alternar status ativo do personagem"""
    
    result = await db.execute(select(CharacterModel).where(CharacterModel.id == character_id))
    character = result.scalar_one_or_none()
    
    if not character:
        raise HTTPException(status_code=404, detail="Personagem não encontrado")
    
    character.is_active = not character.is_active
    await db.commit()
    
    status = "ativado" if character.is_active else "desativado"
    return {"message": f"Personagem '{character.name}' {status} para scraping"}


@router.post("/{character_id}/refresh")
async def refresh_character_data(
    character_id: int,
    db: AsyncSession = Depends(get_db)
):
    """Fazer novo scraping dos dados do personagem"""
    
    # Buscar personagem
    result = await db.execute(select(CharacterModel).where(CharacterModel.id == character_id))
    character = result.scalar_one_or_none()
    
    if not character:
        raise HTTPException(status_code=404, detail="Personagem não encontrado")
    
    try:
        # Fazer novo scraping com histórico
        scrape_result = await scrape_character_data(character.server, character.world, character.name)
        
        if not scrape_result.success:
            raise HTTPException(
                status_code=422,
                detail={
                    "message": "Falha no scraping",
                    "error": scrape_result.error_message,
                    "retry_after": scrape_result.retry_after.isoformat() if scrape_result.retry_after else None
                }
            )
        
        scraped_data = scrape_result.data
        history_data = scraped_data.get('experience_history', [])
        
        logger.info(f"[REFRESH] Personagem {character.name}: {len(history_data)} entradas de histórico encontradas")
        logger.info(f"[REFRESH] Dados completos do scraping: {scraped_data.keys()}")
        logger.info(f"[REFRESH] experience_history: {history_data}")
        
        # Atualizar dados do personagem
        character.level = scraped_data['level']
        character.vocation = scraped_data['vocation']
        character.residence = scraped_data.get('residence')
        character.outfit_image_url = scraped_data.get('outfit_image_url')
        character.last_scraped_at = datetime.utcnow()
        
        snapshots_created = 0
        snapshots_updated = 0
        
        # Processar histórico se disponível
        if history_data:
            logger.info(f"[REFRESH] Processando {len(history_data)} entradas de histórico...")
            for i, entry in enumerate(history_data, 1):
                logger.debug(f"[REFRESH] Processando entrada {i}/{len(history_data)}: {entry['date_text']} ({entry['date']}) = {entry['experience_gained']:,}")
                
                # Verificar se já existe snapshot para esta data (pegar só o primeiro, nunca lançar erro)
                existing_snapshot_query = select(CharacterSnapshotModel).where(
                    and_(
                        CharacterSnapshotModel.character_id == character.id,
                        func.date(CharacterSnapshotModel.scraped_at) == entry['date']
                    )
                ).limit(1)
                snapshot_result = await db.execute(existing_snapshot_query)
                existing_snapshot = snapshot_result.scalar_one_or_none()
                
                snapshot_date = datetime.combine(entry['date'], datetime.min.time())
                
                if existing_snapshot:
                    # Atualizar snapshot existente
                    logger.debug(f"[REFRESH] Atualizando snapshot existente para {entry['date_text']}")
                    existing_snapshot.experience = entry['experience_gained']
                    existing_snapshot.level = scraped_data['level']
                    existing_snapshot.vocation = scraped_data['vocation']
                    existing_snapshot.deaths = scraped_data.get('deaths', 0)
                    existing_snapshot.charm_points = scraped_data.get('charm_points')
                    existing_snapshot.bosstiary_points = scraped_data.get('bosstiary_points')
                    existing_snapshot.achievement_points = scraped_data.get('achievement_points')
                    existing_snapshot.world = character.world
                    existing_snapshot.residence = scraped_data.get('residence')
                    existing_snapshot.outfit_image_url = scraped_data.get('outfit_image_url')
                    existing_snapshot.scrape_source = "refresh"
                    snapshots_updated += 1
                else:
                    # Criar novo snapshot
                    logger.debug(f"[REFRESH] Criando novo snapshot para {entry['date_text']}")
                    snapshot = CharacterSnapshotModel(
                        character_id=character.id,
                        level=scraped_data['level'],
                        experience=entry['experience_gained'],
                        deaths=scraped_data.get('deaths', 0),
                        charm_points=scraped_data.get('charm_points'),
                        bosstiary_points=scraped_data.get('bosstiary_points'),
                        achievement_points=scraped_data.get('achievement_points'),
                        vocation=scraped_data['vocation'],
                        world=character.world,
                        residence=scraped_data.get('residence'),
                        house=scraped_data.get('house'),
                        guild=scraped_data.get('guild'),
                        guild_rank=scraped_data.get('guild_rank'),
                        is_online=scraped_data.get('is_online', False),
                        last_login=scraped_data.get('last_login'),
                        outfit_image_url=scraped_data.get('outfit_image_url'),
                        scraped_at=snapshot_date,
                        scrape_source="refresh",
                        scrape_duration=scrape_result.duration_ms
                    )
                    db.add(snapshot)
                    snapshots_created += 1
        else:
            # Se não há histórico, criar/atualizar snapshot de hoje
            today = datetime.now().date()
            existing_snapshot_query = select(CharacterSnapshotModel).where(
                and_(
                    CharacterSnapshotModel.character_id == character.id,
                    func.date(CharacterSnapshotModel.scraped_at) == today
                )
            ).limit(1)
            snapshot_result = await db.execute(existing_snapshot_query)
            existing_snapshot = snapshot_result.scalar_one_or_none()
            
            if existing_snapshot:
                # Atualizar snapshot de hoje
                existing_snapshot.experience = scraped_data.get('experience', 0)
                existing_snapshot.level = scraped_data['level']
                existing_snapshot.vocation = scraped_data['vocation']
                existing_snapshot.deaths = scraped_data.get('deaths', 0)
                existing_snapshot.scrape_source = "refresh"
                snapshots_updated = 1
            else:
                # Criar novo snapshot para hoje
                snapshot = CharacterSnapshotModel(
                    character_id=character.id,
                    level=scraped_data['level'],
                    experience=scraped_data.get('experience', 0),
                    deaths=scraped_data.get('deaths', 0),
                    charm_points=scraped_data.get('charm_points'),
                    bosstiary_points=scraped_data.get('bosstiary_points'),
                    achievement_points=scraped_data.get('achievement_points'),
                    vocation=scraped_data['vocation'],
                    world=character.world,
                    residence=scraped_data.get('residence'),
                    house=scraped_data.get('house'),
                    guild=scraped_data.get('guild'),
                    guild_rank=scraped_data.get('guild_rank'),
                    is_online=scraped_data.get('is_online', False),
                    last_login=scraped_data.get('last_login'),
                    outfit_image_url=scraped_data.get('outfit_image_url'),
                    scraped_at=datetime.utcnow(),
                    scrape_source="refresh",
                    scrape_duration=scrape_result.duration_ms
                )
                db.add(snapshot)
                snapshots_created = 1
        
        await db.commit()
        
        return {
            "success": True,
            "message": f"Dados de '{character.name}' atualizados com sucesso!",
            "snapshots_created": snapshots_created,
            "snapshots_updated": snapshots_updated,
            "history_entries": len(history_data),
            "scraping_duration_ms": scrape_result.duration_ms
        }
        
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        logger.error(f"Erro ao atualizar personagem {character_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Erro interno: {str(e)}")


@router.get("/{character_id}/charts/experience")
async def get_character_experience_chart(
    character_id: int,
    days: int = Query(30, ge=1, le=365, description="Número de dias para análise"),
    db: AsyncSession = Depends(get_db)
):
    """Obter dados de experiência para gráfico"""
    
    # Verificar se personagem existe
    result = await db.execute(select(CharacterModel).where(CharacterModel.id == character_id))
    character = result.scalar_one_or_none()
    
    if not character:
        raise HTTPException(status_code=404, detail="Personagem não encontrado")
    
    # Data de início da análise
    end_date = datetime.utcnow()
    start_date = end_date - timedelta(days=days)
    
    # Obter snapshots do período ordenados por data
    snapshots_query = select(CharacterSnapshotModel).where(
        and_(
            CharacterSnapshotModel.character_id == character_id,
            CharacterSnapshotModel.scraped_at >= start_date,
            CharacterSnapshotModel.scraped_at <= end_date
        )
    ).order_by(CharacterSnapshotModel.scraped_at)
    
    result = await db.execute(snapshots_query)
    snapshots = result.scalars().all()
    
    if not snapshots:
        return {
            "character_id": character_id,
            "character_name": character.name,
            "period_days": days,
            "data": [],
            "summary": {
                "total_gained": 0,
                "average_daily": 0,
                "snapshots_count": 0
            }
        }
    
    # Preparar dados para o gráfico
    chart_data = []
    total_gained = 0
    
    # Se há apenas um snapshot, mostrá-lo mesmo assim
    if len(snapshots) == 1:
        snapshot = snapshots[0]
        date_str = snapshot.scraped_at.strftime("%Y-%m-%d")
        
        chart_data.append({
            "date": date_str,
            "experience": snapshot.experience,
            "level": snapshot.level
        })
        
        return {
            "character_id": character_id,
            "character_name": character.name,
            "period_days": days,
            "data": chart_data,
            "summary": {
                "total_gained": 0,
                "average_daily": 0,
                "snapshots_count": 1
            }
        }
    
    # Para múltiplos snapshots, calcular ganhos entre eles
    for i, snapshot in enumerate(snapshots):
        date_str = snapshot.scraped_at.strftime("%Y-%m-%d")
        
        if i == 0:
            # Primeiro snapshot - experiência base
            exp_gained = 0
        else:
            # Calcular experiência ganha desde o snapshot anterior
            exp_gained = snapshot.experience - snapshots[i-1].experience
            total_gained += exp_gained
        
        chart_data.append({
            "date": date_str,
            "experience": snapshot.experience,
            "experience_gained": exp_gained,
            "level": snapshot.level
        })
    
    # Calcular média diária considerando apenas dias com ganho
    days_with_gain = len([d for d in chart_data if d.get("experience_gained", 0) > 0])
    avg_daily = total_gained / days_with_gain if days_with_gain > 0 else 0
    
    return {
        "character_id": character_id,
        "character_name": character.name,
        "period_days": days,
        "data": chart_data,
        "summary": {
            "total_gained": total_gained,
            "average_daily": avg_daily,
            "snapshots_count": len(snapshots)
        }
    }


@router.get("/{character_id}/charts/level")
async def get_character_level_chart(
    character_id: int,
    days: int = Query(30, ge=1, le=365, description="Número de dias para análise"),
    db: AsyncSession = Depends(get_db)
):
    """Obter dados de level para gráfico"""
    
    # Verificar se personagem existe
    result = await db.execute(select(CharacterModel).where(CharacterModel.id == character_id))
    character = result.scalar_one_or_none()
    
    if not character:
        raise HTTPException(status_code=404, detail="Personagem não encontrado")
    
    # Data de início da análise
    end_date = datetime.utcnow()
    start_date = end_date - timedelta(days=days)
    
    # Obter snapshots do período
    snapshots_query = select(CharacterSnapshotModel).where(
        and_(
            CharacterSnapshotModel.character_id == character_id,
            CharacterSnapshotModel.scraped_at >= start_date,
            CharacterSnapshotModel.scraped_at <= end_date
        )
    ).order_by(CharacterSnapshotModel.scraped_at)
    
    result = await db.execute(snapshots_query)
    snapshots = result.scalars().all()
    
    if not snapshots:
        return {
            "character_id": character_id,
            "character_name": character.name,
            "period_days": days,
            "data": [],
            "summary": {
                "levels_gained": 0,
                "level_start": 0,
                "level_end": 0,
                "snapshots_count": 0
            }
        }
    
    # Preparar dados para o gráfico
    chart_data = []
    
    for snapshot in snapshots:
        date_str = snapshot.scraped_at.strftime("%Y-%m-%d")
        
        chart_data.append({
            "date": date_str,
            "level": snapshot.level,
            "vocation": snapshot.vocation
        })
    
    level_start = snapshots[0].level if snapshots else 0
    level_end = snapshots[-1].level if snapshots else 0
    level_gained = level_end - level_start
    
    return {
        "character_id": character_id,
        "character_name": character.name,
        "period_days": days,
        "data": chart_data,
        "summary": {
            "levels_gained": level_gained,
            "level_start": level_start,
            "level_end": level_end,
            "snapshots_count": len(snapshots)
        }
    } 