"""
Rotas da API para gerenciamento de personagens
==============================================

Endpoints para CRUD de personagens e seus snapshots históricos.
"""

from fastapi import APIRouter, Depends, HTTPException, Query, Path, Request, Body
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, desc, and_, or_, exists, text
from sqlalchemy.orm import selectinload, aliased
from typing import List, Optional
from datetime import datetime, timedelta
import logging
import re

# Rate Limiting
from slowapi.util import get_remote_address
from slowapi import Limiter

from app.db.database import get_db
from app.core.utils import get_utc_now, normalize_datetime, days_between, calculate_last_experience_data, calculate_experience_stats, format_date_pt_br
from app.models.character import Character as CharacterModel, CharacterSnapshot as CharacterSnapshotModel, CharacterFavorite as CharacterFavoriteModel
from app.schemas.character import (
    CharacterBase, CharacterCreate, CharacterUpdate, Character,
    CharacterSnapshot, CharacterSnapshotCreate, CharacterWithSnapshots,
    CharacterStats, CharacterIDsRequest, CharacterIDsResponse,
    ServerType, WorldType, VocationType,
    CharacterFilter, TopExpResponse, LinearityResponse
)
from app.services.character import CharacterService
from app.services.scraping import scrape_character_data, get_supported_servers, get_server_info, is_server_supported, is_world_supported
import numpy as np

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/characters", tags=["characters"])

# Rate Limiter
limiter = Limiter(key_func=get_remote_address)

# Funções de validação para prevenir SQL Injection e XSS
def validate_character_name(name: str) -> str:
    """Validar nome do personagem - apenas letras, números e espaços"""
    if not name or len(name) < 2 or len(name) > 20:
        raise HTTPException(status_code=400, detail="Nome deve ter entre 2 e 20 caracteres")
    
    # Apenas letras, números e espaços
    if not re.match(r'^[a-zA-Z0-9\s]+$', name):
        raise HTTPException(status_code=400, detail="Nome contém caracteres inválidos")
    
    return name.strip()

def validate_server_name(server: str) -> str:
    """Validar nome do servidor"""
    valid_servers = ["taleon", "rubini", "rubinot"]
    if server.lower() not in valid_servers:
        raise HTTPException(status_code=400, detail=f"Servidor inválido. Válidos: {', '.join(valid_servers)}")
    return server.lower()

def validate_world_name(world: str) -> str:
    """Validar nome do world"""
    if not world or len(world) < 2 or len(world) > 10:
        raise HTTPException(status_code=400, detail="World deve ter entre 2 e 10 caracteres")
    
    # Apenas letras e números
    if not re.match(r'^[a-zA-Z0-9]+$', world):
        raise HTTPException(status_code=400, detail="World contém caracteres inválidos")
    
    return world.lower()

def validate_search_query(search: str) -> str:
    """Validar query de busca"""
    if not search or len(search) < 2 or len(search) > 50:
        raise HTTPException(status_code=400, detail="Busca deve ter entre 2 e 50 caracteres")
    
    # Apenas letras, números e espaços
    if not re.match(r'^[a-zA-Z0-9\s]+$', search):
        raise HTTPException(status_code=400, detail="Busca contém caracteres inválidos")
    
    return search.strip()


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
@limiter.limit("10/minute")  # Máximo 10 buscas por minuto
async def search_character(
    request: Request,
    name: str = Query(..., description="Nome do personagem"),
    server: str = Query(..., description="Servidor (taleon, rubini, etc)"), 
    world: str = Query(..., description="World (san, aura, gaia)"),
    db: AsyncSession = Depends(get_db)
):
    # Validar inputs
    name = validate_character_name(name)
    server = validate_server_name(server)
    world = validate_world_name(world)
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
            
            # Calcular estatísticas de experiência dos últimos 30 dias
            thirty_days_ago = get_utc_now() - timedelta(days=30)
            recent_snapshots = [
                snap for snap in existing_character.snapshots 
                if snap.scraped_at >= thirty_days_ago
            ]
            
            # Calcular estatísticas usando a função corrigida
            exp_stats = calculate_experience_stats(existing_character.snapshots, days=30)
            
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
                    "guild": existing_character.guild,
                    "outfit_image_url": existing_character.outfit_image_url,
                    "last_scraped_at": existing_character.last_scraped_at,
            
                    "total_snapshots": len(existing_character.snapshots),
                    "total_exp_gained": exp_stats['total_exp_gained'],
                    "average_daily_exp": exp_stats['average_daily_exp'],
                    "last_experience": exp_stats['last_experience'],
                    "last_experience_date": exp_stats['last_experience_date'],
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
            guild=scraped_data.get('guild'),
            profile_url=scraped_data.get('profile_url'),
            outfit_image_url=scraped_data.get('outfit_image_url'),
            is_active=True,
            is_public=True,
            last_scraped_at=datetime.utcnow()
        )
        
        db.add(character)
        await db.flush()  # Para obter o ID
        
        # Criar primeiro snapshot
        today = datetime.now().date()
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
            exp_date=today,  # Data da experiência (hoje)
            scraped_at=datetime.utcnow(),  # Data do scraping
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
                "guild": character.guild,
                "outfit_image_url": character.outfit_image_url,
                "last_scraped_at": character.last_scraped_at,

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
@limiter.limit("5/minute")  # Máximo 5 criações por minuto
async def scrape_and_create_character(
    request: Request,
    server: str = Query(..., description="Servidor (taleon, rubini, etc)"),
    world: str = Query(..., description="World (san, aura, gaia)"),
    character_name: str = Query(..., description="Nome do personagem"),
    db: AsyncSession = Depends(get_db)
):
    # Validar inputs
    server = validate_server_name(server)
    world = validate_world_name(world)
    character_name = validate_character_name(character_name)
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
            guild=scraped_data.get('guild'),
            profile_url=scraped_data.get('profile_url'),
            outfit_image_url=scraped_data.get('outfit_image_url'),
            is_active=True,
            is_public=True,
            last_scraped_at=datetime.utcnow()
        )
        
        db.add(character)
        await db.flush()  # Para obter o ID
        
        # Criar primeiro snapshot
        today = datetime.now().date()
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
            exp_date=today,  # Data da experiência (hoje)
            scraped_at=datetime.utcnow(),  # Data do scraping
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
    
    logger.info(f"[SCRAPE-WITH-HISTORY] Iniciando scraping com histórico para {character_name} em {server}/{world}")
    
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
        
        logger.info(f"[SCRAPE-WITH-HISTORY] Personagem existente: {existing_character.id if existing_character else 'NÃO'}")
        
        # Fazer scraping
        logger.info(f"[SCRAPE-WITH-HISTORY] Iniciando scraping...")
        scrape_result = await scrape_character_data(server, world, character_name)
        
        if not scrape_result.success:
            logger.error(f"[SCRAPE-WITH-HISTORY] Falha no scraping: {scrape_result.error_message}")
            raise HTTPException(
                status_code=422,
                detail={
                    "message": "Falha no scraping",
                    "error": scrape_result.error_message,
                    "retry_after": scrape_result.retry_after.isoformat() if scrape_result.retry_after else None
                }
            )
        
        scraped_data = scrape_result.data
        logger.info(f"[SCRAPE-WITH-HISTORY] Scraping concluído com sucesso")
        
        # Extrair histórico completo de experiência
        history_data = scraped_data.get('experience_history', [])
        logger.info(f"[SCRAPE-WITH-HISTORY] Personagem {character_name}: {len(history_data)} entradas de histórico encontradas")
        logger.info(f"[SCRAPE-WITH-HISTORY] Dados completos do scraping: {list(scraped_data.keys())}")
        logger.info(f"[SCRAPE-WITH-HISTORY] experience_history: {history_data}")
        
        character = existing_character
        if not character:
            # Criar personagem se não existe
            logger.info(f"[SCRAPE-WITH-HISTORY] Criando novo personagem...")
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
                last_scraped_at=datetime.utcnow()
            )
            
            db.add(character)
            await db.flush()  # Para obter o ID
            logger.info(f"[SCRAPE-WITH-HISTORY] Novo personagem criado com ID: {character.id}")
        else:
            # Atualizar personagem existente
            logger.info(f"[SCRAPE-WITH-HISTORY] Atualizando personagem existente ID: {character.id}")
            character.level = scraped_data['level']
            character.vocation = scraped_data['vocation']
            character.residence = scraped_data.get('residence')
            character.outfit_image_url = scraped_data.get('outfit_image_url')
            character.last_scraped_at = datetime.utcnow()
        
        snapshots_created = 0
        snapshots_updated = 0
        
        # Criar/atualizar snapshots para cada entrada do histórico
        if history_data:
            logger.info(f"[SCRAPE-WITH-HISTORY] Processando {len(history_data)} entradas de histórico...")
            for i, entry in enumerate(history_data):
                logger.info(f"[SCRAPE-WITH-HISTORY] Processando entrada {i+1}/{len(history_data)}: {entry}")
                
                # Verificar se entry['date'] é válido
                if not entry.get('date'):
                    logger.warning(f"[SCRAPE-WITH-HISTORY] Entrada sem data válida: {entry}")
                    continue
                
                # Verificar se já existe snapshot para esta data usando exp_date
                existing_snapshot_query = select(CharacterSnapshotModel).where(
                    and_(
                        CharacterSnapshotModel.character_id == character.id,
                        CharacterSnapshotModel.exp_date == entry['date']
                    )
                ).order_by(desc(CharacterSnapshotModel.scraped_at)).limit(1)
                snapshot_result = await db.execute(existing_snapshot_query)
                existing_snapshot = snapshot_result.scalar_one_or_none()
                
                snapshot_date = datetime.combine(entry['date'], datetime.min.time())
                
                if existing_snapshot:
                    # SOBRESCREVER dados existentes com informações mais recentes
                    logger.info(f"[SCRAPE-WITH-HISTORY] Atualizando snapshot existente para {entry['date']}: "
                              f"experiência {existing_snapshot.experience:,} → {entry['experience_gained']:,}")
                    
                    existing_snapshot.level = scraped_data['level']
                    existing_snapshot.experience = max(0, entry['experience_gained'])  # Garantir que não seja negativo
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
                    logger.info(f"[SCRAPE-WITH-HISTORY] Criando novo snapshot para {entry['date']}: "
                              f"experiência {entry['experience_gained']:,}")
                    
                    snapshot = CharacterSnapshotModel(
                        character_id=character.id,
                        level=scraped_data['level'],  # Usar level atual para todos
                        experience=max(0, entry['experience_gained']),  # Experiência específica do dia, garantindo que não seja negativa
                        exp_date=entry['date'],  # Data da experiência (da entrada do histórico)
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
            logger.info(f"[SCRAPE-WITH-HISTORY] Nenhum histórico encontrado, criando snapshot atual...")
            snapshot = CharacterSnapshotModel(
                character_id=character.id,
                level=scraped_data['level'],
                experience=max(0, scraped_data.get('experience', 0)),  # Garantir que não seja negativo
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
        
        logger.info(f"[SCRAPE-WITH-HISTORY] Salvando no banco de dados...")
        await db.commit()
        await db.refresh(character)
        
        logger.info(f"[SCRAPE-WITH-HISTORY] Concluído! Snapshots criados: {snapshots_created}, atualizados: {snapshots_updated}")
        
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
        logger.error(f"[SCRAPE-WITH-HISTORY] Erro: {str(e)}")
        await db.rollback()
        raise HTTPException(status_code=500, detail=f"Erro interno: {str(e)}")


# ===== ENDPOINTS DE PERSONAGENS =====

@router.get("/recent")
async def get_recent_characters(
    limit: int = Query(10, ge=1, le=100, description="Número máximo de personagens"),
    db: AsyncSession = Depends(get_db)
):
    """Obter personagens adicionados recentemente"""
    try:
        result = await db.execute(
            select(CharacterModel)
            .where(CharacterModel.is_active == True)
            .order_by(desc(CharacterModel.last_scraped_at))
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
            
            # Calcular estatísticas de experiência usando a nova função
            all_snapshots_result = await db.execute(
                select(CharacterSnapshotModel)
                .where(CharacterSnapshotModel.character_id == char.id)
            )
            all_snapshots = all_snapshots_result.scalars().all()
            
            # Calcular estatísticas de experiência
            exp_stats = calculate_experience_stats(all_snapshots, days=30)

            char_data = {
                "id": char.id,
                "name": char.name,
                "server": char.server,
                "world": char.world,
                "level": char.level,
                "vocation": char.vocation,
                "guild": char.guild,
                "outfit_image_url": char.outfit_image_url,
                "last_scraped_at": char.last_scraped_at,
                "recovery_active": char.recovery_active,
                "total_snapshots": total_snapshots,
                "total_exp_gained": exp_stats['total_exp_gained'],
                "average_daily_exp": exp_stats['average_daily_exp'],
                "last_experience": exp_stats['last_experience'],
                "last_experience_date": exp_stats['last_experience_date'],
                "exp_gained": exp_stats['exp_gained'],
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
            .where(CharacterModel.is_active == True)
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


@router.get("")
@limiter.limit("30/minute")  # Máximo 30 listagens por minuto
async def list_characters(
    request: Request,
    skip: int = Query(0, ge=0, description="Número de registros a pular"),
    limit: int = Query(50, ge=1, le=1000, description="Número máximo de registros"),
    server: Optional[str] = Query(None, description="Filtrar por servidor"),
    world: Optional[str] = Query(None, description="Filtrar por world"),
    is_active: Optional[bool] = Query(None, description="Filtrar por personagens ativos"),
    search: Optional[str] = Query(None, description="Buscar por nome do personagem"),
    guild: Optional[str] = Query(None, description="Filtrar por guild"),
    activity_filter: Optional[str] = Query(None, description="Filtrar por atividade (active_today, active_yesterday, active_2days, active_3days)"),
    db: AsyncSession = Depends(get_db)
):
    # Validar inputs opcionais
    if server:
        server = validate_server_name(server)
    if world:
        world = validate_world_name(world)
    if search:
        search = validate_search_query(search)
    """Listar personagens com filtros e paginação"""
    
    query = select(CharacterModel)
    
    # Aplicar filtros básicos
    filters = []
    if server:
        filters.append(CharacterModel.server == server)
    if world:
        filters.append(CharacterModel.world == world)
    if is_active is not None:
        filters.append(CharacterModel.is_active == is_active)

    if search:
        filters.append(CharacterModel.name.ilike(f"%{search}%"))
    if guild:
        filters.append(CharacterModel.guild.ilike(f"%{guild}%"))
    
    # Aplicar filtro de atividade se especificado
    if activity_filter:
        from datetime import datetime, timedelta
        
        # Calcular a data baseada no filtro
        today = datetime.utcnow().date()
        
        if activity_filter == 'active_today':
            target_date = today
        elif activity_filter == 'active_yesterday':
            target_date = today - timedelta(days=1)
        elif activity_filter == 'active_2days':
            target_date = today - timedelta(days=2)
        elif activity_filter == 'active_3days':
            target_date = today - timedelta(days=3)
        else:
            # Filtro inválido, ignorar
            target_date = None
        
        if target_date:
            # Subconsulta para encontrar personagens com experiência > 0 na data específica
            # Converter target_date para datetime com timezone para comparação correta
            target_datetime_start = datetime.combine(target_date, datetime.min.time())
            target_datetime_end = datetime.combine(target_date + timedelta(days=1), datetime.min.time())
            
            subquery = select(CharacterSnapshotModel.character_id).where(
                and_(
                    CharacterSnapshotModel.scraped_at >= target_datetime_start,
                    CharacterSnapshotModel.scraped_at < target_datetime_end,
                    CharacterSnapshotModel.experience.is_not(None)
                )
            ).distinct()
            
            filters.append(CharacterModel.id.in_(subquery))
    
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
        
        # Buscar snapshots para calcular última experiência
        snapshots_query = select(CharacterSnapshotModel).where(CharacterSnapshotModel.character_id == char.id)
        snapshots_result = await db.execute(snapshots_query)
        snapshots = snapshots_result.scalars().all()
        
        # Calcular última experiência válida
        last_experience, last_experience_date = calculate_last_experience_data(snapshots)
        
        # Adicionar dados calculados ao character
        char_dict = {
            **char.__dict__,
            'snapshots_count': snapshots_count,
            'last_experience': last_experience,
            'last_experience_date': last_experience_date
        }
        
        character_summaries.append(char_dict)
    
    return {
        "characters": character_summaries,
        "total": total,
        "page": skip // limit + 1,
        "per_page": limit
    }


@router.get("/")
async def list_characters_alias(
    skip: int = Query(0, ge=0, description="Número de registros a pular"),
    limit: int = Query(50, ge=1, le=1000, description="Número máximo de registros"),
    server: Optional[str] = Query(None, description="Filtrar por servidor"),
    world: Optional[str] = Query(None, description="Filtrar por world"),
    is_active: Optional[bool] = Query(None, description="Filtrar por personagens ativos"),
    search: Optional[str] = Query(None, description="Buscar por nome do personagem"),
    guild: Optional[str] = Query(None, description="Filtrar por guild"),
    activity_filter: Optional[str] = Query(None, description="Filtrar por atividade (active_today, active_yesterday, active_2days, active_3days)"),
    db: AsyncSession = Depends(get_db)
):
    """Listar personagens com filtros e paginação (alias com barra para compatibilidade)"""
    
    # Chamamos a função principal
    return await list_characters(skip, limit, server, world, is_active, search, guild, activity_filter, db)


@router.post("/", response_model=Character)
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


# ===== ENDPOINTS DE FILTRAGEM =====

@router.get("/filter-ids", response_model=CharacterIDsResponse)
async def filter_character_ids(
    server: Optional[str] = Query(None),
    world: Optional[str] = Query(None),
    is_active: Optional[bool] = Query(None),
    search: Optional[str] = Query(None),
    guild: Optional[str] = Query(None),
    activity_filter: Optional[List[str]] = Query(None),
    min_level: Optional[int] = Query(None),
    max_level: Optional[int] = Query(None),
    vocation: Optional[str] = Query(None),
    min_deaths: Optional[int] = Query(None, alias='minDeaths', description='Filtrar por número mínimo de mortes'),
    max_deaths: Optional[int] = Query(None, alias='maxDeaths', description='Filtrar por número máximo de mortes'),
    min_snapshots: Optional[int] = Query(None, alias='minSnapshots', description='Filtrar por número mínimo de snapshots'),
    max_snapshots: Optional[int] = Query(None, alias='maxSnapshots', description='Filtrar por número máximo de snapshots'),
    min_experience: Optional[int] = Query(None, alias='minExperience', description='Filtrar por experiência mínima'),
    max_experience: Optional[int] = Query(None, alias='maxExperience', description='Filtrar por experiência máxima'),
    is_favorited: Optional[str] = Query(None, description='Filtrar por favoritos (true, false, ou omitir para todos)'),
    favorite_ids: Optional[List[int]] = Query(None, description='Lista de IDs favoritos do usuário (frontend)'),
    recovery_active: Optional[str] = Query(None, description='Filtrar por recovery ativo (true, false, ou omitir para todos)'),
    limit: Optional[int] = Query(1000, ge=1, le=10000),
    db: AsyncSession = Depends(get_db),
    request: Request = None
):
    """
    Filtrar personagens e retornar apenas os IDs que correspondem aos critérios.
    Lógica: AND entre campos diferentes, OR entre múltiplas opções do mesmo campo.
    """
    # Log completo dos parâmetros recebidos
    logger.info(f"[FILTER-IDS] === INÍCIO DA FUNÇÃO ===")
    logger.info(f"[FILTER-IDS] server: {server} (tipo: {type(server)})")
    logger.info(f"[FILTER-IDS] world: {world} (tipo: {type(world)})")
    logger.info(f"[FILTER-IDS] guild: {guild} (tipo: {type(guild)})")
    logger.info(f"[FILTER-IDS] min_level: {min_level} (tipo: {type(min_level)})")
    logger.info(f"[FILTER-IDS] max_level: {max_level} (tipo: {type(max_level)})")
    logger.info(f"[FILTER-IDS] vocation: {vocation} (tipo: {type(vocation)})")
    logger.info(f"[FILTER-IDS] activity_filter: {activity_filter} (tipo: {type(activity_filter)})")
    logger.info(f"[FILTER-IDS] is_favorited: {is_favorited} (tipo: {type(is_favorited)})")
    logger.info(f"[FILTER-IDS] favorite_ids: {favorite_ids} (tipo: {type(favorite_ids)})")
    logger.info(f"[FILTER-IDS] recovery_active: {recovery_active} (tipo: {type(recovery_active)})")
    logger.info(f"[FILTER-IDS] limit: {limit} (tipo: {type(limit)})")
    
    # Log da URL completa se request estiver disponível
    if request:
        logger.info(f"[FILTER-IDS] URL completa: {request.url}")
        logger.info(f"[FILTER-IDS] Query params: {dict(request.query_params)}")
        
        # Pegar min_level e max_level diretamente dos query_params
        if 'min_level' in request.query_params:
            try:
                min_level = int(request.query_params['min_level'])
                logger.info(f"[FILTER-IDS] min_level extraído dos query_params: {min_level}")
            except ValueError:
                logger.warning(f"[FILTER-IDS] min_level inválido nos query_params: {request.query_params['min_level']}")
                min_level = None
        
        if 'max_level' in request.query_params:
            try:
                max_level = int(request.query_params['max_level'])
                logger.info(f"[FILTER-IDS] max_level extraído dos query_params: {max_level}")
            except ValueError:
                logger.warning(f"[FILTER-IDS] max_level inválido nos query_params: {request.query_params['max_level']}")
                max_level = None
        
        # Verificar parâmetros de favoritos nos query_params
        if 'is_favorited' in request.query_params:
            logger.info(f"[FILTER-IDS] is_favorited nos query_params: {request.query_params['is_favorited']}")
        
        if 'favorite_ids' in request.query_params:
            logger.info(f"[FILTER-IDS] favorite_ids nos query_params: {request.query_params.getlist('favorite_ids')}")
            # Tentar converter para lista de inteiros
            try:
                favorite_ids_from_params = [int(id_str) for id_str in request.query_params.getlist('favorite_ids')]
                logger.info(f"[FILTER-IDS] favorite_ids convertidos: {favorite_ids_from_params}")
                favorite_ids = favorite_ids_from_params
            except ValueError as e:
                logger.error(f"[FILTER-IDS] Erro ao converter favorite_ids: {e}")
                favorite_ids = []
    
    # Converter min_level e max_level para inteiros se necessário
    if min_level is not None:
        if isinstance(min_level, str) and min_level.strip():
            try:
                min_level = int(min_level)
                logger.info(f"[FILTER-IDS] min_level convertido para: {min_level}")
            except ValueError:
                logger.warning(f"[FILTER-IDS] min_level inválido: {min_level}")
                min_level = None
        elif not isinstance(min_level, int):
            min_level = None
    
    if max_level is not None:
        if isinstance(max_level, str) and max_level.strip():
            try:
                max_level = int(max_level)
                logger.info(f"[FILTER-IDS] max_level convertido para: {max_level}")
            except ValueError:
                logger.warning(f"[FILTER-IDS] max_level inválido: {max_level}")
                max_level = None
        elif not isinstance(max_level, int):
            max_level = None
    
    # Query base - apenas da tabela Character
    query = select(CharacterModel.id)
    conditions = []

    # Filtros do Character principal (AND)
    if server:
        conditions.append(CharacterModel.server.ilike(server))
    if world:
        conditions.append(CharacterModel.world.ilike(world))
    if is_active is not None:
        conditions.append(CharacterModel.is_active == is_active)
    if recovery_active is not None and recovery_active != '':
        if recovery_active.lower() == 'true':
            conditions.append(CharacterModel.recovery_active == True)
        elif recovery_active.lower() == 'false':
            conditions.append(CharacterModel.recovery_active == False)

    if search:
        conditions.append(CharacterModel.name.ilike(f"%{search}%"))
    if guild:
        conditions.append(CharacterModel.guild.ilike(f"%{guild}%"))

    # Filtro de favoritos
    if is_favorited is not None and is_favorited != '':
        logger.info(f"[FILTER-IDS] Aplicando filtro de favoritos: is_favorited={is_favorited}")
        if is_favorited.lower() == 'true':
            # Apenas favoritos do frontend (cookie)
            if favorite_ids:
                logger.info(f"[FILTER-IDS] Filtrando apenas favoritos. IDs: {favorite_ids}")
                conditions.append(CharacterModel.id.in_(favorite_ids))
            else:
                logger.warning(f"[FILTER-IDS] is_favorited=true mas favorite_ids está vazio!")
        elif is_favorited.lower() == 'false':
            # Apenas não favoritos do frontend (cookie)
            if favorite_ids:
                logger.info(f"[FILTER-IDS] Filtrando apenas não favoritos. IDs: {favorite_ids}")
                conditions.append(~CharacterModel.id.in_(favorite_ids))
            else:
                logger.warning(f"[FILTER-IDS] is_favorited=false mas favorite_ids está vazio!")
        else:
            logger.warning(f"[FILTER-IDS] Valor inválido para is_favorited: {is_favorited}")
    else:
        logger.info(f"[FILTER-IDS] Nenhum filtro de favoritos aplicado")

    # Filtro de vocação (OR se múltiplas opções)
    if vocation:
        if isinstance(vocation, list):
            vocation_conditions = [CharacterModel.vocation.ilike(v) for v in vocation]
            conditions.append(or_(*vocation_conditions))
        else:
            conditions.append(CharacterModel.vocation.ilike(vocation))

    # Filtros de level da tabela principal
    if min_level is not None:
        logger.info(f"[FILTER-IDS] Aplicando filtro min_level >= {min_level}")
        conditions.append(CharacterModel.level >= min_level)
    if max_level is not None:
        logger.info(f"[FILTER-IDS] Aplicando filtro max_level <= {max_level}")
        conditions.append(CharacterModel.level <= max_level)

    # Filtros que dependem do snapshot mais recente
    snapshot_filters = []
    if min_deaths is not None:
        snapshot_filters.append(CharacterSnapshotModel.deaths >= min_deaths)
    if max_deaths is not None:
        snapshot_filters.append(CharacterSnapshotModel.deaths <= max_deaths)
    if min_experience is not None:
        snapshot_filters.append(CharacterSnapshotModel.experience >= min_experience)
    if max_experience is not None:
        snapshot_filters.append(CharacterSnapshotModel.experience <= max_experience)

    # Se houver filtros de snapshot, fazer join com subquery do snapshot mais recente
    if snapshot_filters:
        # Subquery para pegar o último snapshot de cada personagem
        latest_snapshots = select(
            CharacterSnapshotModel.character_id,
            func.max(CharacterSnapshotModel.scraped_at).label("latest_date")
        ).group_by(CharacterSnapshotModel.character_id).alias("latest_snap")

        # Join com o snapshot mais recente
        query = select(CharacterModel.id).join(
            latest_snapshots, CharacterModel.id == latest_snapshots.c.character_id
        ).join(
            CharacterSnapshotModel,
            and_(
                CharacterSnapshotModel.character_id == latest_snapshots.c.character_id,
                CharacterSnapshotModel.scraped_at == latest_snapshots.c.latest_date
            )
        )
        if conditions:
            query = query.where(and_(*conditions))
        if snapshot_filters:
            query = query.where(and_(*snapshot_filters))
    else:
        if conditions:
            query = query.where(and_(*conditions))

    # Limite
    query = query.limit(limit)

    # Executar query
    result = await db.execute(query)
    character_ids = [row[0] for row in result.fetchall()]
    
    logger.info(f"[FILTER-IDS] IDs encontrados após filtros básicos: {len(character_ids)}")

    # Se há filtros de atividade, fazer uma segunda consulta para filtrar por snapshots
    if activity_filter and character_ids:
        from datetime import datetime, timedelta
        today = datetime.utcnow().date()
        activity_conditions = []
        for activity in activity_filter:
            if activity == 'active_today':
                target_date = today
            elif activity == 'active_yesterday':
                target_date = today - timedelta(days=1)
            elif activity == 'active_2days':
                target_date = today - timedelta(days=2)
            elif activity == 'active_3days':
                target_date = today - timedelta(days=3)
            else:
                continue
            target_datetime_start = datetime.combine(target_date, datetime.min.time())
            target_datetime_end = datetime.combine(target_date + timedelta(days=1), datetime.min.time())
            activity_conditions.append(
                and_(
                    CharacterSnapshotModel.scraped_at >= target_datetime_start,
                    CharacterSnapshotModel.scraped_at < target_datetime_end,
                    CharacterSnapshotModel.experience.is_not(None)
                )
            )
        if activity_conditions:
            activity_query = select(CharacterSnapshotModel.character_id).where(
                and_(
                    CharacterSnapshotModel.character_id.in_(character_ids),
                    or_(*activity_conditions)
                )
            ).distinct()
            activity_result = await db.execute(activity_query)
            active_character_ids = [row[0] for row in activity_result.fetchall()]
            character_ids = [cid for cid in character_ids if cid in active_character_ids]
            logger.info(f"[FILTER-IDS] IDs após filtro de atividade: {len(character_ids)}")

    logger.info(f"[FILTER-IDS] Retornando {len(character_ids)} IDs")
    logger.info(f"[FILTER-IDS] === FIM DA FUNÇÃO ===")
    return CharacterIDsResponse(
        ids=character_ids
    )


@router.post("/by-ids")
async def get_characters_by_ids(req: CharacterIDsRequest, db: AsyncSession = Depends(get_db)):
    """Buscar personagens com dados de card"""
    
    if not req.ids:
        return []
    
    # Buscar personagens com snapshots
    query = (
        select(CharacterModel)
        .where(CharacterModel.id.in_(req.ids))
        .options(selectinload(CharacterModel.snapshots))
    )
    
    result = await db.execute(query)
    characters = result.scalars().all()
    
    # Processar cada personagem para calcular experiência
    character_list = []
    for character in characters:
        # Converter para dicionário
        char_dict = {
            "id": character.id,
            "name": character.name,
            "server": character.server,
            "world": character.world,
            "level": character.level,
            "vocation": character.vocation,
            "residence": character.residence,
            "guild": character.guild,
            "is_active": character.is_active,
            "is_public": character.is_public,
            "profile_url": character.profile_url,
            "character_url": character.character_url,
            "outfit_image_url": character.outfit_image_url,
            "outfit_image_path": character.outfit_image_path,
            "last_scraped_at": character.last_scraped_at,
            "scrape_error_count": character.scrape_error_count,
            "last_scrape_error": character.last_scrape_error,
            "next_scrape_at": character.next_scrape_at,
            "created_at": character.created_at,
            "updated_at": character.updated_at,
            "snapshots": character.snapshots
        }
        
        if character.snapshots:
            # Calcular última experiência válida
            last_experience, last_experience_date = calculate_last_experience_data(character.snapshots)
            
            # Adicionar campos calculados
            char_dict["last_experience"] = last_experience
            char_dict["last_experience_date"] = last_experience_date
            

        else:
            char_dict["last_experience"] = None
            char_dict["last_experience_date"] = None
        
        character_list.append(char_dict)
    
    return character_list


# ===== ENDPOINTS DE PERSONAGEM ESPECÍFICO =====

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


@router.put("/{character_id}", response_model=Character)
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

@router.post("/{character_id}/snapshots", response_model=CharacterSnapshot)
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


@router.get("/{character_id}/snapshots")
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
    
    return {
        "snapshots": snapshots,
        "total": total,
        "page": skip // limit + 1,
        "per_page": limit
    }


@router.get("/{character_id}/evolution")
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
    
    # Calcular experiência total ganha no período (soma dos dias)
    total_experience_gained = sum(max(0, snapshot.experience) for snapshot in snapshots)
    
    # Detectar mudanças de world
    world_changes = []
    current_world = first_snapshot.world
    for snapshot in snapshots[1:]:
        if snapshot.world != current_world:
            world_changes.append(f"{current_world} -> {snapshot.world} em {snapshot.scraped_at.strftime('%Y-%m-%d')}")
            current_world = snapshot.world
    
    evolution = {
        "character_id": character_id,
        "character_name": character.name,
        "period_start": first_snapshot.scraped_at,
        "period_end": last_snapshot.scraped_at,
        "level_start": first_snapshot.level,
        "level_end": last_snapshot.level,
        "level_gained": last_snapshot.level - first_snapshot.level,
        "experience_start": 0,  # Não há experiência inicial acumulada
        "experience_end": total_experience_gained,  # Total de experiência ganha no período
        "experience_gained": total_experience_gained,  # Total de experiência ganha no período
        "deaths_start": first_snapshot.deaths,
        "deaths_end": last_snapshot.deaths,
        "deaths_total": last_snapshot.deaths - first_snapshot.deaths,
        "charm_points_start": first_snapshot.charm_points,
        "charm_points_end": last_snapshot.charm_points,
        "charm_points_gained": (last_snapshot.charm_points or 0) - (first_snapshot.charm_points or 0) if first_snapshot.charm_points and last_snapshot.charm_points else None,
        "bosstiary_points_start": first_snapshot.bosstiary_points,
        "bosstiary_points_end": last_snapshot.bosstiary_points,
        "bosstiary_points_gained": (last_snapshot.bosstiary_points or 0) - (first_snapshot.bosstiary_points or 0) if first_snapshot.bosstiary_points and last_snapshot.bosstiary_points else None,
        "achievement_points_start": first_snapshot.achievement_points,
        "achievement_points_end": last_snapshot.achievement_points,
        "achievement_points_gained": (last_snapshot.achievement_points or 0) - (first_snapshot.achievement_points or 0) if first_snapshot.achievement_points and last_snapshot.achievement_points else None,
        "world_changes": world_changes
    }
    
    return {
        "character": character,
        "evolution": evolution,
        "snapshots": snapshots
    }


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
    
    # Calcular experiência total ganha no período (soma dos dias)
    total_experience_gained = sum(max(0, snapshot.experience) for snapshot in snapshots)
    
    # Encontrar snapshot com maior experiência ganha em um único dia
    highest_daily_exp_snapshot = max(snapshots, key=lambda x: max(0, x.experience))
    
    # Calcular média de exp por dia
    if len(snapshots) > 1:
        total_days = (snapshots[-1].scraped_at - snapshots[0].scraped_at).days
        avg_daily_exp = total_experience_gained / total_days if total_days > 0 else 0
    else:
        avg_daily_exp = total_experience_gained
    
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
        highest_experience=total_experience_gained,  # Total de experiência ganha no período
        highest_experience_date=snapshots[-1].scraped_at,  # Data do último snapshot
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
    
    await db.commit()
    
    return {"message": f"Personagem '{character.name}' favorito atualizado"}


@router.get("/{character_id}/toggle-active")
async def toggle_active(
    character_id: int,
    db: AsyncSession = Depends(get_db)
):
    """Ativar/desativar personagem"""
    try:
        service = CharacterService(db)
        character = await service.get_character(character_id)
        
        if not character:
            raise HTTPException(status_code=404, detail="Personagem não encontrado")
        
        character.is_active = not character.is_active
        await db.commit()
        
        status = "ativado" if character.is_active else "desativado"
        return {
            "success": True,
            "message": f"Personagem {character.name} {status}",
            "is_active": character.is_active
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erro ao alterar status ativo do personagem {character_id}: {e}")
        raise HTTPException(status_code=500, detail="Erro interno do servidor")

@router.get("/{character_id}/toggle-recovery")
async def toggle_recovery(
    character_id: int,
    db: AsyncSession = Depends(get_db)
):
    """Ativar/desativar recovery automático do personagem"""
    try:
        service = CharacterService(db)
        character = await service.get_character(character_id)
        
        if not character:
            raise HTTPException(status_code=404, detail="Personagem não encontrado")
        
        # Toggle do status atual
        new_status = not character.recovery_active
        success = await service.toggle_recovery_active(character_id, new_status)
        
        if success:
            return {
                "success": True,
                "message": f"Recovery {'ativado' if new_status else 'desativado'} para {character.name}",
                "recovery_active": new_status
            }
        else:
            raise HTTPException(status_code=500, detail="Erro ao alterar recovery")
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erro ao alterar recovery do personagem {character_id}: {e}")
        raise HTTPException(status_code=500, detail="Erro interno do servidor")

@router.post("/{character_id}/manual-scrape")
async def manual_scrape_character(
    character_id: int,
    db: AsyncSession = Depends(get_db)
):
    """Fazer scraping manual de um personagem específico"""
    try:
        service = CharacterService(db)
        character = await service.get_character(character_id)
        
        if not character:
            raise HTTPException(status_code=404, detail="Personagem não encontrado")
        
        logger.info(f"🔄 Iniciando scraping manual para {character.name}")
        
        # Fazer scraping
        scrape_result = await scrape_character_data(
            character.server, character.world, character.name
        )
        
        if scrape_result.success:
            # Criar/atualizar snapshots com histórico completo
            snapshot_result = await service.create_snapshot_with_history(
                character.id, scrape_result.data, "manual"
            )
            
            # Atualizar dados do personagem
            character.last_scraped_at = datetime.now()
            character.scrape_error_count = 0
            character.last_scrape_error = None
            
            # Se teve experiência, ativar recovery se estiver inativo
            if scrape_result.data.get('experience', 0) > 0 and not character.recovery_active:
                character.recovery_active = True
                logger.info(f"✅ Recovery reativado para {character.name} após experiência detectada")
            
            await db.commit()
            
            return {
                "success": True,
                "message": f"Scraping manual concluído para {character.name}",
                "snapshots_created": snapshot_result.get('created', 0),
                "snapshots_updated": snapshot_result.get('updated', 0),
                "recovery_active": character.recovery_active
            }
        else:
            # Incrementar contador de erro
            character.scrape_error_count += 1
            character.last_scrape_error = scrape_result.error_message
            character.last_scraped_at = datetime.now()
            
            # Verificar se deve desativar recovery por erro
            if character.scrape_error_count >= 3:
                character.recovery_active = False
                logger.warning(f"⚠️ Recovery desativado para {character.name} por 3 erros consecutivos")
            
            await db.commit()
            
            return {
                "success": False,
                "message": f"Erro no scraping: {scrape_result.error_message}",
                "recovery_active": character.recovery_active
            }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erro no scraping manual do personagem {character_id}: {e}")
        raise HTTPException(status_code=500, detail="Erro interno do servidor")

@router.get("/recovery-stats")
async def get_recovery_stats(db: AsyncSession = Depends(get_db)):
    """Obter estatísticas de recovery dos personagens"""
    try:
        service = CharacterService(db)
        stats = await service.get_recovery_stats()
        
        return {
            "success": True,
            "stats": stats,
            "message": "Estatísticas de recovery obtidas com sucesso"
        }
        
    except Exception as e:
        logger.error(f"Erro ao obter estatísticas de recovery: {e}")
        raise HTTPException(status_code=500, detail="Erro interno do servidor")

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
                
                # Verificar se entry['date'] é válido
                if not entry.get('date'):
                    logger.warning(f"[REFRESH] Entrada sem data válida: {entry}")
                    continue
                
                # Verificar se já existe snapshot para esta data usando exp_date
                existing_snapshot_query = select(CharacterSnapshotModel).where(
                    and_(
                        CharacterSnapshotModel.character_id == character.id,
                        CharacterSnapshotModel.exp_date == entry['date']
                    )
                ).limit(1)
                snapshot_result = await db.execute(existing_snapshot_query)
                existing_snapshot = snapshot_result.scalar_one_or_none()
                
                snapshot_date = datetime.combine(entry['date'], datetime.min.time())
                
                if existing_snapshot:
                    # Atualizar snapshot existente
                    logger.debug(f"[REFRESH] Atualizando snapshot existente para {entry['date_text']}")
                    existing_snapshot.experience = max(0, entry['experience_gained'])  # Garantir que não seja negativo
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
                        experience=max(0, entry['experience_gained']),  # Garantir que não seja negativo
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
                        exp_date=entry['date'],  # Data da experiência (da entrada do histórico)
                        scraped_at=snapshot_date,  # Data do scraping
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
                    CharacterSnapshotModel.exp_date == today
                )
            ).limit(1)
            snapshot_result = await db.execute(existing_snapshot_query)
            existing_snapshot = snapshot_result.scalar_one_or_none()
            
            if existing_snapshot:
                # Atualizar snapshot de hoje
                existing_snapshot.experience = max(0, scraped_data.get('experience', 0))  # Garantir que não seja negativo
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
                    experience=max(0, scraped_data.get('experience', 0)),  # Garantir que não seja negativo
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
                    exp_date=today,  # Data da experiência (hoje)
                    scraped_at=datetime.utcnow(),  # Data do scraping
                    scrape_source="refresh",
                    scrape_duration=scrape_result.duration_ms
                )
                db.add(snapshot)
                snapshots_created = 1
        
        await db.commit()

        # Atualizar o campo guild do personagem principal com base no snapshot mais recente (sempre após o commit)
        latest_snapshot_result = await db.execute(
            select(CharacterSnapshotModel)
            .where(CharacterSnapshotModel.character_id == character.id)
            .order_by(CharacterSnapshotModel.scraped_at.desc())
            .limit(1)
        )
        latest_snapshot = latest_snapshot_result.scalar_one_or_none()
        if latest_snapshot:
            character.guild = latest_snapshot.guild  # Pode ser None!
            await db.flush()  # Força a persistência imediata
            await db.commit()
            logger.info(f"[REFRESH] Guild do personagem {character.id} atualizada para: {latest_snapshot.guild}")

        return {
            "success": True,
            "message": f"Dados de '{character.name}' atualizados com sucesso!",
            "id": character.id,
            "scraping_date": latest_snapshot.scraped_at.isoformat() if latest_snapshot else None,
            "guild": latest_snapshot.guild if latest_snapshot else None,
            "level": latest_snapshot.level if latest_snapshot else None,
            "experience": latest_snapshot.experience if latest_snapshot else None,
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
        
        # Para um único snapshot, usar a experiência como ganho do dia
        exp_gained = max(0, snapshot.experience)  # Garantir que não seja negativo
        
        chart_data.append({
            "date": date_str,
            "experience": exp_gained,  # Experiência ganha no dia
            "experience_gained": exp_gained,  # Experiência ganha no dia
            "level": snapshot.level
        })
        
        return {
            "character_id": character_id,
            "character_name": character.name,
            "period_days": days,
            "data": chart_data,
            "summary": {
                "total_gained": exp_gained,
                "average_daily": exp_gained,
                "snapshots_count": 1
            }
        }
    
    # Para múltiplos snapshots, mostrar experiência ganha por dia
    for i, snapshot in enumerate(snapshots):
        date_str = snapshot.scraped_at.strftime("%Y-%m-%d")
        
        # Experiência ganha no dia (já está no snapshot)
        exp_gained = max(0, snapshot.experience)  # Garantir que não seja negativo
        total_gained += exp_gained
        
        chart_data.append({
            "date": date_str,
            "experience": exp_gained,  # Experiência ganha neste dia específico
            "experience_gained": exp_gained,  # Experiência ganha neste dia específico
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
    
    # Preparar dados para o gráfico com preenchimento de dias
    chart_data = []
    
    # Criar um dicionário com o level mais recente para cada dia
    daily_levels = {}
    for snapshot in snapshots:
        date_str = snapshot.scraped_at.strftime("%Y-%m-%d")
        # Manter o level mais recente do dia
        daily_levels[date_str] = snapshot.level
    
    # Preencher todos os dias do período com o level apropriado
    current_level = snapshots[0].level if snapshots else 0
    current_date = start_date.date()
    end_date_only = end_date.date()
    
    while current_date <= end_date_only:
        date_str = current_date.strftime("%Y-%m-%d")
        
        # Se temos um level para este dia, usar ele e atualizar o current_level
        if date_str in daily_levels:
            current_level = daily_levels[date_str]
        
        chart_data.append({
            "date": date_str,
            "level": current_level,
            "vocation": snapshots[0].vocation if snapshots else "Unknown"
        })
        
        current_date += timedelta(days=1)
    
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


@router.get("/top-exp", response_model=List[TopExpResponse])
async def get_top_exp(
    days: int = Query(30, ge=1, le=365),
    limit: int = Query(10, ge=1, le=100),
    server: Optional[str] = None,
    world: Optional[str] = None,
    vocation: Optional[str] = None,
    guild: Optional[str] = None,
    min_level: Optional[int] = None,
    max_level: Optional[int] = None,
):
    """
    Get top characters by experience gained in a period.
    """
    try:
        db = next(get_db())
        end_date = datetime.now()
        start_date = end_date - timedelta(days=days)

        # Build base query
        query = db.query(
            Character.id,
            Character.name,
            Character.level,
            Character.vocation,
            Character.world,
            Character.server,
            Character.guild,
            func.max(CharacterSnapshot.experience).label('end_exp'),
            func.min(CharacterSnapshot.experience).label('start_exp'),
            func.max(CharacterSnapshot.level).label('end_level'),
            func.min(CharacterSnapshot.level).label('start_level'),
        ).join(
            CharacterSnapshot,
            Character.id == CharacterSnapshot.character_id
        ).filter(
            CharacterSnapshot.created_at.between(start_date, end_date)
        ).group_by(
            Character.id
        )

        # Apply filters
        if server:
            query = query.filter(Character.server == server)
        if world:
            query = query.filter(Character.world == world)
        if vocation:
            query = query.filter(Character.vocation == vocation)
        if guild:
            query = query.filter(Character.guild == guild)
        if min_level:
            query = query.filter(Character.level >= min_level)
        if max_level:
            query = query.filter(Character.level <= max_level)

        # Calculate experience gained and order by it
        query = query.having(
            func.max(CharacterSnapshot.experience) > func.min(CharacterSnapshot.experience)
        ).order_by(
            desc(func.max(CharacterSnapshot.experience) - func.min(CharacterSnapshot.experience))
        ).limit(limit)

        results = query.all()

        # Format response
        response = []
        for result in results:
            exp_gained = result.end_exp - result.start_exp
            levels_gained = result.end_level - result.start_level
            avg_exp_per_day = exp_gained / days

            response.append({
                "id": result.id,
                "name": result.name,
                "level": result.level,
                "vocation": result.vocation,
                "world": result.world,
                "server": result.server,
                "guild": result.guild,
                "experienceGained": exp_gained,
                "levelsGained": levels_gained,
                "averageExpPerDay": avg_exp_per_day,
                "startLevel": result.start_level,
                "endLevel": result.end_level,
                "startExp": result.start_exp,
                "endExp": result.end_exp,
                "period": days
            })

        return response

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/linearity", response_model=List[LinearityResponse])
async def get_exp_linearity(
    days: int = Query(30, ge=1, le=365),
    limit: int = Query(10, ge=1, le=100),
    server: Optional[str] = None,
    world: Optional[str] = None,
    vocation: Optional[str] = None,
    guild: Optional[str] = None,
    min_level: Optional[int] = None,
    max_level: Optional[int] = None,
):
    """
    Get characters ranked by experience gain linearity.
    Linearity is calculated as the sum of the absolute differences between
    daily experience gain and the average daily gain.
    A lower linearity index means more consistent experience gain.
    """
    try:
        db = next(get_db())
        end_date = datetime.now()
        start_date = end_date - timedelta(days=days)

        # Build base query to get daily experience for each character
        query = db.query(
            Character.id,
            Character.name,
            Character.level,
            Character.vocation,
            Character.world,
            Character.server,
            Character.guild,
            func.date(CharacterSnapshot.created_at).label('date'),
            func.max(CharacterSnapshot.experience).label('daily_exp')
        ).join(
            CharacterSnapshot,
            Character.id == CharacterSnapshot.character_id
        ).filter(
            CharacterSnapshot.created_at.between(start_date, end_date)
        ).group_by(
            Character.id,
            func.date(CharacterSnapshot.created_at)
        )

        # Apply filters
        if server:
            query = query.filter(Character.server == server)
        if world:
            query = query.filter(Character.world == world)
        if vocation:
            query = query.filter(Character.vocation == vocation)
        if guild:
            query = query.filter(Character.guild == guild)
        if min_level:
            query = query.filter(Character.level >= min_level)
        if max_level:
            query = query.filter(Character.level <= max_level)

        results = query.all()

        # Group results by character
        char_data = {}
        for result in results:
            if result.id not in char_data:
                char_data[result.id] = {
                    'id': result.id,
                    'name': result.name,
                    'level': result.level,
                    'vocation': result.vocation,
                    'world': result.world,
                    'server': result.server,
                    'guild': result.guild,
                    'daily_exp': []
                }
            char_data[result.id]['daily_exp'].append(result.daily_exp)

        # Calculate linearity index for each character
        linearity_data = []
        for char_id, data in char_data.items():
            if len(data['daily_exp']) > 1:
                # Calculate daily gains
                daily_gains = []
                for i in range(1, len(data['daily_exp'])):
                    gain = data['daily_exp'][i] - data['daily_exp'][i-1]
                    daily_gains.append(gain)

                if daily_gains:
                    # Calculate average daily gain
                    avg_gain = sum(daily_gains) / len(daily_gains)

                    # Calculate linearity index
                    if avg_gain > 0:
                        # Calculate relative distance from average for each day
                        relative_distances = [(gain/avg_gain - 1) for gain in daily_gains]
                        # Get min and max distances
                        min_distance = min(relative_distances)
                        max_distance = max(relative_distances)
                        # Linearity index is the range of relative distances
                        linearity_index = max_distance - min_distance

                        linearity_data.append({
                            **data,
                            'daily_gains': daily_gains,
                            'average_gain': avg_gain,
                            'linearity_index': linearity_index,
                            'total_exp_gained': sum(daily_gains),
                            'days_tracked': len(daily_gains),
                            'min_gain': min(daily_gains),
                            'max_gain': max(daily_gains)
                        })

        # Sort by linearity index (most linear first)
        linearity_data.sort(key=lambda x: x['linearity_index'])
        return linearity_data[:limit]

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/filter-ids")
async def get_filtered_character_ids(
    search: Optional[str] = None,
    guild: Optional[str] = None,
    limit: Optional[str] = None,
    db: Session = Depends(get_db)
):
    """
    Get filtered character IDs based on search criteria
    """
    try:
        query = db.query(Character.id)

        if search:
            query = query.filter(Character.name.ilike(f"%{search}%"))
        if guild:
            query = query.filter(Character.guild.ilike(f"%{guild}%"))

        if limit and limit.lower() != "all":
            try:
                limit_num = int(limit)
                query = query.limit(limit_num)
            except ValueError:
                pass

        character_ids = [str(row.id) for row in query.all()]
        return {"character_ids": character_ids}

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/")
async def get_all_characters(
    db: Session = Depends(get_db),
    skip: int = 0,
    limit: int = 100
):
    """
    Get all characters with pagination
    """
    try:
        query = db.query(Character)
        total = query.count()
        characters = query.offset(skip).limit(limit).all()
        
        return {
            "total": total,
            "characters": characters,
            "skip": skip,
            "limit": limit
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))