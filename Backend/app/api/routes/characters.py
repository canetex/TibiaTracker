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

from app.db.database import get_db
from app.models.character import Character, CharacterSnapshot
from app.schemas.character import (
    CharacterCreate, CharacterUpdate, Character as CharacterSchema,
    CharacterWithSnapshots, CharacterSummary, CharacterListResponse,
    CharacterSnapshotCreate, CharacterSnapshot as CharacterSnapshotSchema,
    CharacterEvolution, CharacterEvolutionResponse, CharacterStats,
    SnapshotListResponse
)
from app.services.character import CharacterService
from app.services.scraping import scrape_character_data, get_supported_servers, get_server_info, is_server_supported, is_world_supported

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
        existing_query = select(Character).where(
            and_(
                Character.name.ilike(character_name),
                Character.server == server.lower(),
                Character.world == world.lower()
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
        character = Character(
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
        snapshot = CharacterSnapshot(
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


# ===== ENDPOINTS DE PERSONAGENS =====

@router.get("/", response_model=CharacterListResponse)
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
    
    query = select(Character)
    
    # Aplicar filtros
    filters = []
    if server:
        filters.append(Character.server == server)
    if world:
        filters.append(Character.world == world)
    if is_active is not None:
        filters.append(Character.is_active == is_active)
    if is_favorited is not None:
        filters.append(Character.is_favorited == is_favorited)
    if search:
        filters.append(Character.name.ilike(f"%{search}%"))
    
    if filters:
        query = query.where(and_(*filters))
    
    # Contar total
    count_query = select(func.count(Character.id)).where(and_(*filters)) if filters else select(func.count(Character.id))
    result = await db.execute(count_query)
    total = result.scalar()
    
    # Aplicar paginação e ordenação
    query = query.order_by(Character.name).offset(skip).limit(limit)
    
    result = await db.execute(query)
    characters = result.scalars().all()
    
    # Converter para schema resumido
    character_summaries = []
    for char in characters:
        # Contar snapshots para cada personagem
        snapshot_count_query = select(func.count(CharacterSnapshot.id)).where(CharacterSnapshot.character_id == char.id)
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


@router.post("/", response_model=CharacterSchema)
async def create_character(
    character_data: CharacterCreate,
    db: AsyncSession = Depends(get_db)
):
    """Criar novo personagem"""
    
    # Verificar se já existe personagem com o mesmo nome/servidor/world
    existing_query = select(Character).where(
        and_(
            Character.name == character_data.name,
            Character.server == character_data.server,
            Character.world == character_data.world
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
    character = Character(**character_data.dict())
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
    
    query = select(Character).where(Character.id == character_id)
    
    if include_snapshots:
        query = query.options(selectinload(Character.snapshots))
    
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
    
    result = await db.execute(select(Character).where(Character.id == character_id))
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
    
    result = await db.execute(select(Character).where(Character.id == character_id))
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
    result = await db.execute(select(Character).where(Character.id == character_id))
    character = result.scalar_one_or_none()
    
    if not character:
        raise HTTPException(status_code=404, detail="Personagem não encontrado")
    
    # Criar snapshot
    snapshot_data.character_id = character_id
    snapshot = CharacterSnapshot(**snapshot_data.dict())
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
    result = await db.execute(select(Character).where(Character.id == character_id))
    character = result.scalar_one_or_none()
    
    if not character:
        raise HTTPException(status_code=404, detail="Personagem não encontrado")
    
    query = select(CharacterSnapshot).where(CharacterSnapshot.character_id == character_id)
    
    # Aplicar filtros de data
    filters = []
    if start_date:
        filters.append(CharacterSnapshot.scraped_at >= start_date)
    if end_date:
        filters.append(CharacterSnapshot.scraped_at <= end_date)
    
    if filters:
        query = query.where(and_(*filters))
    
    # Contar total
    count_query = select(func.count(CharacterSnapshot.id)).where(CharacterSnapshot.character_id == character_id)
    if filters:
        count_query = count_query.where(and_(*filters))
    
    result = await db.execute(count_query)
    total = result.scalar()
    
    # Aplicar paginação e ordenação (mais recentes primeiro)
    query = query.order_by(desc(CharacterSnapshot.scraped_at)).offset(skip).limit(limit)
    
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
    result = await db.execute(select(Character).where(Character.id == character_id))
    character = result.scalar_one_or_none()
    
    if not character:
        raise HTTPException(status_code=404, detail="Personagem não encontrado")
    
    # Data de início da análise
    end_date = datetime.utcnow()
    start_date = end_date - timedelta(days=days)
    
    # Obter snapshots do período
    snapshots_query = select(CharacterSnapshot).where(
        and_(
            CharacterSnapshot.character_id == character_id,
            CharacterSnapshot.scraped_at >= start_date,
            CharacterSnapshot.scraped_at <= end_date
        )
    ).order_by(CharacterSnapshot.scraped_at)
    
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
    result = await db.execute(select(Character).where(Character.id == character_id))
    character = result.scalar_one_or_none()
    
    if not character:
        raise HTTPException(status_code=404, detail="Personagem não encontrado")
    
    # Obter todos os snapshots
    snapshots_query = select(CharacterSnapshot).where(
        CharacterSnapshot.character_id == character_id
    ).order_by(CharacterSnapshot.scraped_at)
    
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
    
    result = await db.execute(select(Character).where(Character.id == character_id))
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
    
    result = await db.execute(select(Character).where(Character.id == character_id))
    character = result.scalar_one_or_none()
    
    if not character:
        raise HTTPException(status_code=404, detail="Personagem não encontrado")
    
    character.is_active = not character.is_active
    await db.commit()
    
    status = "ativado" if character.is_active else "desativado"
    return {"message": f"Personagem '{character.name}' {status} para scraping"} 