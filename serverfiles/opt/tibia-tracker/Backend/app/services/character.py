"""
Serviço de gerenciamento de personagens
======================================

Lógica de negócio para operações com personagens e snapshots.
"""

import logging
from typing import Optional, List, Dict, Any
from datetime import datetime, timedelta
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, desc, and_, or_
from sqlalchemy.orm import selectinload

from app.models.character import Character, CharacterSnapshot
from app.schemas.character import (
    CharacterCreate, CharacterUpdate, CharacterResponse, 
    CharacterListResponse, CharacterStatsResponse,
    CharacterSnapshotResponse
)

logger = logging.getLogger(__name__)


class CharacterService:
    """Serviço para operações de personagens"""

    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_character(self, character_id: int) -> Optional[Character]:
        """Buscar personagem por ID"""
        try:
            result = await self.db.execute(
                select(Character).where(Character.id == character_id)
            )
            return result.scalar_one_or_none()
        except Exception as e:
            logger.error(f"Erro ao buscar personagem {character_id}: {e}")
            return None

    async def get_character_by_name_server_world(
        self, name: str, server: str, world: str
    ) -> Optional[Character]:
        """Buscar personagem por nome, servidor e mundo"""
        try:
            result = await self.db.execute(
                select(Character).where(
                    and_(
                        Character.name.ilike(name),
                        Character.server == server,
                        Character.world == world
                    )
                )
            )
            return result.scalar_one_or_none()
        except Exception as e:
            logger.error(f"Erro ao buscar personagem {name}/{server}/{world}: {e}")
            return None

    async def create_character_with_snapshot(
        self, character_data: CharacterCreate, snapshot_data: Dict[str, Any]
    ) -> Character:
        """Criar personagem com snapshot inicial"""
        try:
            # Criar personagem
            character = Character(
                name=character_data.name,
                server=character_data.server,
                world=character_data.world,
                level=snapshot_data.get('level', 0),
                vocation=snapshot_data.get('vocation', 'None'),
                residence=snapshot_data.get('residence', ''),
                profile_url=snapshot_data.get('profile_url', ''),
                last_scraped_at=datetime.now(),
                next_scrape_at=datetime.now() + timedelta(days=1),
                scrape_error_count=0
            )

            self.db.add(character)
            await self.db.flush()  # Para obter o ID

            # Criar snapshot inicial
            snapshot = CharacterSnapshot(
                character_id=character.id,
                level=snapshot_data.get('level', 0),
                experience=snapshot_data.get('experience', 0),
                deaths=snapshot_data.get('deaths', 0),
                charm_points=snapshot_data.get('charm_points'),
                bosstiary_points=snapshot_data.get('bosstiary_points'),
                achievement_points=snapshot_data.get('achievement_points'),
                vocation=snapshot_data.get('vocation', 'None'),
                residence=snapshot_data.get('residence', ''),
                house=snapshot_data.get('house'),
                guild=snapshot_data.get('guild'),
                guild_rank=snapshot_data.get('guild_rank'),
                is_online=snapshot_data.get('is_online', False),
                last_login=snapshot_data.get('last_login'),
                outfit_data=None,  # Implementar no futuro
                scrape_source="manual"
            )

            self.db.add(snapshot)
            await self.db.commit()

            logger.info(f"Personagem {character.name} criado com snapshot inicial")
            return character

        except Exception as e:
            await self.db.rollback()
            logger.error(f"Erro ao criar personagem: {e}")
            raise

    async def create_snapshot(
        self, character_id: int, snapshot_data: Dict[str, Any], source: str = "scheduled"
    ) -> CharacterSnapshot:
        """Criar novo snapshot para um personagem"""
        try:
            snapshot = CharacterSnapshot(
                character_id=character_id,
                level=snapshot_data.get('level', 0),
                experience=snapshot_data.get('experience', 0),
                deaths=snapshot_data.get('deaths', 0),
                charm_points=snapshot_data.get('charm_points'),
                bosstiary_points=snapshot_data.get('bosstiary_points'),
                achievement_points=snapshot_data.get('achievement_points'),
                vocation=snapshot_data.get('vocation', 'None'),
                residence=snapshot_data.get('residence', ''),
                house=snapshot_data.get('house'),
                guild=snapshot_data.get('guild'),
                guild_rank=snapshot_data.get('guild_rank'),
                is_online=snapshot_data.get('is_online', False),
                last_login=snapshot_data.get('last_login'),
                scrape_source=source
            )

            self.db.add(snapshot)

            # Atualizar informações básicas do personagem
            character = await self.get_character(character_id)
            if character:
                character.level = snapshot_data.get('level', character.level)
                character.vocation = snapshot_data.get('vocation', character.vocation)
                character.residence = snapshot_data.get('residence', character.residence)
                character.last_scraped_at = datetime.now()
                character.scrape_error_count = 0
                character.last_scrape_error = None
                character.next_scrape_at = datetime.now() + timedelta(days=1)

            await self.db.commit()

            logger.info(f"Snapshot criado para personagem {character_id} via {source}")
            return snapshot

        except Exception as e:
            await self.db.rollback()
            logger.error(f"Erro ao criar snapshot: {e}")
            raise

    async def update_character(
        self, character_id: int, character_data: CharacterUpdate
    ) -> Optional[Character]:
        """Atualizar configurações do personagem"""
        try:
            character = await self.get_character(character_id)
            if not character:
                return None

            if character_data.is_favorited is not None:
                character.is_favorited = character_data.is_favorited

            if character_data.is_public is not None:
                character.is_public = character_data.is_public

            await self.db.commit()

            logger.info(f"Personagem {character_id} atualizado")
            return character

        except Exception as e:
            await self.db.rollback()
            logger.error(f"Erro ao atualizar personagem {character_id}: {e}")
            return None

    async def set_favorite(self, character_id: int, is_favorited: bool) -> bool:
        """Favoritar/desfavoritar personagem"""
        try:
            character = await self.get_character(character_id)
            if not character:
                return False

            character.is_favorited = is_favorited
            await self.db.commit()

            action = "favoritado" if is_favorited else "desfavoritado"
            logger.info(f"Personagem {character_id} {action}")
            return True

        except Exception as e:
            await self.db.rollback()
            logger.error(f"Erro ao favoritar personagem {character_id}: {e}")
            return False

    async def delete_character(self, character_id: int) -> bool:
        """Deletar personagem e todos os snapshots"""
        try:
            character = await self.get_character(character_id)
            if not character:
                return False

            await self.db.delete(character)
            await self.db.commit()

            logger.info(f"Personagem {character_id} deletado")
            return True

        except Exception as e:
            await self.db.rollback()
            logger.error(f"Erro ao deletar personagem {character_id}: {e}")
            return False

    async def get_character_with_stats(self, character_id: int) -> Optional[CharacterResponse]:
        """Obter personagem com último snapshot e estatísticas"""
        try:
            # Buscar personagem com snapshots
            result = await self.db.execute(
                select(Character)
                .options(selectinload(Character.snapshots))
                .where(Character.id == character_id)
            )
            character = result.scalar_one_or_none()

            if not character:
                return None

            # Buscar último snapshot
            latest_snapshot_result = await self.db.execute(
                select(CharacterSnapshot)
                .where(CharacterSnapshot.character_id == character_id)
                .order_by(desc(CharacterSnapshot.scraped_at))
                .limit(1)
            )
            latest_snapshot = latest_snapshot_result.scalar_one_or_none()

            # Contar snapshots
            total_snapshots_result = await self.db.execute(
                select(func.count(CharacterSnapshot.id))
                .where(CharacterSnapshot.character_id == character_id)
            )
            total_snapshots = total_snapshots_result.scalar() or 0

            # Converter para response
            latest_snapshot_response = None
            if latest_snapshot:
                latest_snapshot_response = CharacterSnapshotResponse.from_orm(latest_snapshot)

            return CharacterResponse(
                id=character.id,
                name=character.name,
                server=character.server,
                world=character.world,
                level=character.level,
                vocation=character.vocation,
                residence=character.residence,
                is_active=character.is_active,
                is_public=character.is_public,
                is_favorited=character.is_favorited,
                profile_url=character.profile_url,
                last_scraped_at=character.last_scraped_at,
                scrape_error_count=character.scrape_error_count,
                last_scrape_error=character.last_scrape_error,
                next_scrape_at=character.next_scrape_at,
                created_at=character.created_at,
                updated_at=character.updated_at,
                latest_snapshot=latest_snapshot_response,
                total_snapshots=total_snapshots
            )

        except Exception as e:
            logger.error(f"Erro ao obter personagem com stats {character_id}: {e}")
            return None

    async def list_characters(
        self,
        page: int = 1,
        size: int = 20,
        favorited_only: bool = False,
        server: Optional[str] = None,
        world: Optional[str] = None
    ) -> CharacterListResponse:
        """Listar personagens com filtros e paginação"""
        try:
            # Construir query base
            query = select(Character).where(Character.is_active == True)

            # Aplicar filtros
            if favorited_only:
                query = query.where(Character.is_favorited == True)

            if server:
                query = query.where(Character.server == server)

            if world:
                query = query.where(Character.world == world)

            # Contar total
            count_query = select(func.count(Character.id)).select_from(query.subquery())
            total_result = await self.db.execute(count_query)
            total = total_result.scalar() or 0

            # Aplicar paginação
            offset = (page - 1) * size
            query = query.order_by(desc(Character.created_at)).offset(offset).limit(size)

            # Executar query
            result = await self.db.execute(query)
            characters = result.scalars().all()

            # Converter para response
            character_responses = []
            for character in characters:
                char_response = await self.get_character_with_stats(character.id)
                if char_response:
                    character_responses.append(char_response)

            has_next = (page * size) < total

            return CharacterListResponse(
                characters=character_responses,
                total=total,
                page=page,
                size=size,
                has_next=has_next
            )

        except Exception as e:
            logger.error(f"Erro ao listar personagens: {e}")
            return CharacterListResponse(
                characters=[], total=0, page=page, size=size, has_next=False
            )

    async def get_recent_characters(self, limit: int = 10) -> List[CharacterResponse]:
        """Obter personagens adicionados recentemente"""
        try:
            result = await self.db.execute(
                select(Character)
                .where(Character.is_active == True)
                .order_by(desc(Character.created_at))
                .limit(limit)
            )
            characters = result.scalars().all()

            character_responses = []
            for character in characters:
                char_response = await self.get_character_with_stats(character.id)
                if char_response:
                    character_responses.append(char_response)

            return character_responses

        except Exception as e:
            logger.error(f"Erro ao obter personagens recentes: {e}")
            return []

    async def get_character_statistics(
        self, character_id: int, days: int = 30
    ) -> Optional[CharacterStatsResponse]:
        """Obter estatísticas detalhadas de um personagem"""
        try:
            # Verificar se personagem existe
            character = await self.get_character(character_id)
            if not character:
                return None

            # Data limite
            date_limit = datetime.now() - timedelta(days=days)

            # Buscar snapshots no período
            result = await self.db.execute(
                select(CharacterSnapshot)
                .where(
                    and_(
                        CharacterSnapshot.character_id == character_id,
                        CharacterSnapshot.scraped_at >= date_limit
                    )
                )
                .order_by(CharacterSnapshot.scraped_at)
            )
            snapshots = result.scalars().all()

            # Construir progressões
            level_progression = [
                {"date": snap.scraped_at.isoformat(), "level": snap.level}
                for snap in snapshots
            ]

            experience_progression = [
                {"date": snap.scraped_at.isoformat(), "experience": snap.experience}
                for snap in snapshots
            ]

            deaths_progression = [
                {"date": snap.scraped_at.isoformat(), "deaths": snap.deaths}
                for snap in snapshots
            ]

            charm_points_progression = [
                {"date": snap.scraped_at.isoformat(), "charm_points": snap.charm_points}
                for snap in snapshots if snap.charm_points is not None
            ]

            bosstiary_points_progression = [
                {"date": snap.scraped_at.isoformat(), "bosstiary_points": snap.bosstiary_points}
                for snap in snapshots if snap.bosstiary_points is not None
            ]

            achievement_points_progression = [
                {"date": snap.scraped_at.isoformat(), "achievement_points": snap.achievement_points}
                for snap in snapshots if snap.achievement_points is not None
            ]

            # Primeira e última data
            first_seen = snapshots[0].scraped_at if snapshots else None
            last_updated = snapshots[-1].scraped_at if snapshots else None

            return CharacterStatsResponse(
                character_id=character_id,
                total_snapshots=len(snapshots),
                level_progression=level_progression,
                experience_progression=experience_progression,
                deaths_progression=deaths_progression,
                charm_points_progression=charm_points_progression,
                bosstiary_points_progression=bosstiary_points_progression,
                achievement_points_progression=achievement_points_progression,
                first_seen=first_seen,
                last_updated=last_updated
            )

        except Exception as e:
            logger.error(f"Erro ao obter estatísticas do personagem {character_id}: {e}")
            return None

    async def get_global_statistics(self) -> Dict[str, Any]:
        """Obter estatísticas globais da plataforma"""
        try:
            # Total de personagens
            total_chars_result = await self.db.execute(
                select(func.count(Character.id)).where(Character.is_active == True)
            )
            total_characters = total_chars_result.scalar() or 0

            # Total de snapshots
            total_snapshots_result = await self.db.execute(
                select(func.count(CharacterSnapshot.id))
            )
            total_snapshots = total_snapshots_result.scalar() or 0

            # Personagens por servidor
            server_stats_result = await self.db.execute(
                select(Character.server, func.count(Character.id))
                .where(Character.is_active == True)
                .group_by(Character.server)
            )
            server_stats = {server: count for server, count in server_stats_result.fetchall()}

            # Personagens favoritados
            favorited_result = await self.db.execute(
                select(func.count(Character.id))
                .where(and_(Character.is_active == True, Character.is_favorited == True))
            )
            favorited_characters = favorited_result.scalar() or 0

            return {
                "total_characters": total_characters,
                "total_snapshots": total_snapshots,
                "favorited_characters": favorited_characters,
                "characters_by_server": server_stats,
                "last_updated": datetime.now().isoformat()
            }

        except Exception as e:
            logger.error(f"Erro ao obter estatísticas globais: {e}")
            return {}

    async def schedule_next_update(self, character_id: int):
        """Agendar próxima atualização do personagem"""
        try:
            character = await self.get_character(character_id)
            if character:
                # Agendar para 00:01 do próximo dia
                tomorrow = datetime.now().replace(hour=0, minute=1, second=0, microsecond=0) + timedelta(days=1)
                character.next_scrape_at = tomorrow
                await self.db.commit()
                
                logger.info(f"Próxima atualização agendada para {character.name}: {tomorrow}")

        except Exception as e:
            logger.error(f"Erro ao agendar atualização para personagem {character_id}: {e}")
            await self.db.rollback() 