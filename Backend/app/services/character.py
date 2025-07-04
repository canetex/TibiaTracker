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

from app.models.character import Character as CharacterModel, CharacterSnapshot as CharacterSnapshotModel
from app.schemas.character import (
    CharacterCreate, CharacterUpdate, Character as CharacterSchema, 
    CharacterListResponse, CharacterStats,
    CharacterSnapshot as CharacterSnapshotSchema
)

logger = logging.getLogger(__name__)


class CharacterService:
    """Serviço para operações de personagens"""

    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_character(self, character_id: int) -> Optional[CharacterModel]:
        """Buscar personagem por ID"""
        try:
            result = await self.db.execute(
                select(CharacterModel).where(CharacterModel.id == character_id)
            )
            return result.scalar_one_or_none()
        except Exception as e:
            logger.error(f"Erro ao buscar personagem {character_id}: {e}")
            return None

    async def get_character_by_name_server_world(
        self, name: str, server: str, world: str
    ) -> Optional[CharacterModel]:
        """Buscar personagem por nome, servidor e mundo"""
        try:
            result = await self.db.execute(
                select(CharacterModel).where(
                    and_(
                        CharacterModel.name.ilike(name),
                        CharacterModel.server == server,
                        CharacterModel.world == world
                    )
                )
            )
            return result.scalar_one_or_none()
        except Exception as e:
            logger.error(f"Erro ao buscar personagem {name}/{server}/{world}: {e}")
            return None

    async def create_character_with_snapshot(
        self, character_data: CharacterCreate, snapshot_data: Dict[str, Any]
    ) -> CharacterModel:
        """Criar personagem com snapshot inicial"""
        try:
            # Criar personagem
            character = CharacterModel(
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
            snapshot = CharacterSnapshotModel(
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
    ) -> CharacterSnapshotModel:
        """Criar novo snapshot para um personagem"""
        try:
            snapshot = CharacterSnapshotModel(
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
                outfit_image_url=snapshot_data.get('outfit_image_url'),
                outfit_data=snapshot_data.get('outfit_data'),
                profile_url=snapshot_data.get('profile_url'),
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
    ) -> Optional[CharacterModel]:
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

    async def get_character_with_stats(self, character_id: int) -> Optional[CharacterSchema]:
        """Obter personagem com último snapshot e estatísticas"""
        try:
            # Buscar personagem com snapshots
            result = await self.db.execute(
                select(CharacterModel)
                .options(selectinload(CharacterModel.snapshots))
                .where(CharacterModel.id == character_id)
            )
            character = result.scalar_one_or_none()

            if not character:
                return None

            # Converter para response
            return CharacterSchema.from_orm(character)

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
            query = select(CharacterModel).where(CharacterModel.is_active == True)

            # Aplicar filtros
            if favorited_only:
                query = query.where(CharacterModel.is_favorited == True)

            if server:
                query = query.where(CharacterModel.server == server)

            if world:
                query = query.where(CharacterModel.world == world)

            # Contar total
            count_query = select(func.count(CharacterModel.id)).select_from(query.subquery())
            total_result = await self.db.execute(count_query)
            total = total_result.scalar() or 0

            # Aplicar paginação
            offset = (page - 1) * size
            query = query.order_by(desc(CharacterModel.created_at)).offset(offset).limit(size)

            # Executar query
            result = await self.db.execute(query)
            characters = result.scalars().all()

            # Converter para response
            from app.schemas.character import CharacterSummary
            character_summaries = []
            for character in characters:
                character_summaries.append(CharacterSummary.from_orm(character))

            return CharacterListResponse(
                characters=character_summaries,
                total=total,
                page=page,
                per_page=size
            )

        except Exception as e:
            logger.error(f"Erro ao listar personagens: {e}")
            return CharacterListResponse(
                characters=[], total=0, page=page, per_page=size
            )

    async def get_recent_characters(self, limit: int = 10) -> List[CharacterSchema]:
        """Obter personagens adicionados recentemente"""
        try:
            result = await self.db.execute(
                select(CharacterModel)
                .where(CharacterModel.is_active == True)
                .order_by(desc(CharacterModel.created_at))
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
    ) -> Optional[CharacterStats]:
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
                select(CharacterSnapshotModel)
                .where(
                    and_(
                        CharacterSnapshotModel.character_id == character_id,
                        CharacterSnapshotModel.scraped_at >= date_limit
                    )
                )
                .order_by(CharacterSnapshotModel.scraped_at)
            )
            snapshots = result.scalars().all()

            # Calcular estatísticas básicas
            total_snapshots = len(snapshots)
            first_snapshot = snapshots[0].scraped_at if snapshots else None
            last_snapshot = snapshots[-1].scraped_at if snapshots else None
            
            # Encontrar picos
            highest_level = max((snap.level for snap in snapshots), default=0)
            highest_experience = max((snap.experience for snap in snapshots), default=0)
            
            # Encontrar datas dos picos
            highest_level_date = None
            highest_experience_date = None
            for snap in snapshots:
                if snap.level == highest_level and highest_level_date is None:
                    highest_level_date = snap.scraped_at
                if snap.experience == highest_experience and highest_experience_date is None:
                    highest_experience_date = snap.scraped_at

            # Calcular médias
            average_daily_exp_gain = None
            average_level_per_month = None
            if len(snapshots) > 1:
                exp_gain = snapshots[-1].experience - snapshots[0].experience
                days_diff = (snapshots[-1].scraped_at - snapshots[0].scraped_at).days
                if days_diff > 0:
                    average_daily_exp_gain = exp_gain / days_diff
                    
                level_gain = snapshots[-1].level - snapshots[0].level
                if days_diff > 0:
                    average_level_per_month = (level_gain * 30) / days_diff

            # Worlds visitados
            worlds_visited = list(set(snap.world for snap in snapshots))

            return CharacterStats(
                character_id=character_id,
                character_name=character.name,
                total_snapshots=total_snapshots,
                first_snapshot=first_snapshot,
                last_snapshot=last_snapshot,
                highest_level=highest_level,
                highest_level_date=highest_level_date,
                highest_experience=highest_experience,
                highest_experience_date=highest_experience_date,
                average_daily_exp_gain=average_daily_exp_gain,
                average_level_per_month=average_level_per_month,
                worlds_visited=worlds_visited
            )

        except Exception as e:
            logger.error(f"Erro ao obter estatísticas do personagem {character_id}: {e}")
            return None

    async def get_global_statistics(self) -> Dict[str, Any]:
        """Obter estatísticas globais da plataforma"""
        try:
            # Total de personagens
            total_chars_result = await self.db.execute(
                select(func.count(CharacterModel.id)).where(CharacterModel.is_active == True)
            )
            total_characters = total_chars_result.scalar() or 0

            # Total de snapshots
            total_snapshots_result = await self.db.execute(
                select(func.count(CharacterSnapshotModel.id))
            )
            total_snapshots = total_snapshots_result.scalar() or 0

            # Personagens por servidor
            server_stats_result = await self.db.execute(
                select(CharacterModel.server, func.count(CharacterModel.id))
                .where(CharacterModel.is_active == True)
                .group_by(CharacterModel.server)
            )
            server_stats = {server: count for server, count in server_stats_result.fetchall()}

            # Personagens favoritados
            favorited_result = await self.db.execute(
                select(func.count(CharacterModel.id))
                .where(and_(CharacterModel.is_active == True, CharacterModel.is_favorited == True))
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