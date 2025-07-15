"""
Serviço de Processamento em Lotes
=================================

Gerencia processamento em lotes de personagens para servidores com volume alto.
Otimizado para o Rubinot e outros servidores com +10.000 personagens.
"""

import asyncio
import logging
from typing import List, Dict, Any, Optional, Tuple
from datetime import datetime, timedelta
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, or_, func
from sqlalchemy.orm import selectinload
import aiohttp
from dataclasses import dataclass

from app.models.character import Character as CharacterModel, CharacterSnapshot as CharacterSnapshotModel
from app.services.scraping import scrape_character_data
from app.services.character import CharacterService

logger = logging.getLogger(__name__)


@dataclass
class BulkProcessingConfig:
    """Configuração para processamento em lotes"""
    batch_size: int = 50  # Tamanho do lote
    max_concurrent: int = 10  # Máximo de requests concorrentes
    delay_between_batches: float = 2.0  # Delay entre lotes (segundos)
    delay_between_requests: float = 1.0  # Delay entre requests (segundos)
    max_retries: int = 3  # Máximo de tentativas por personagem
    retry_delay: float = 5.0  # Delay entre tentativas (segundos)


@dataclass
class BulkProcessingResult:
    """Resultado do processamento em lotes"""
    total_processed: int
    successful: int
    failed: int
    skipped: int
    processing_time: float
    errors: List[Dict[str, Any]]


class BulkProcessor:
    """
    Processador em lotes para personagens
    """
    
    def __init__(self, db: AsyncSession, config: Optional[BulkProcessingConfig] = None):
        self.db = db
        self.config = config or BulkProcessingConfig()
        self.service = CharacterService(db)
    
    async def process_characters_batch(
        self, 
        character_list: List[Dict[str, Any]], 
        server: str,
        world: str
    ) -> BulkProcessingResult:
        """
        Processar uma lista de personagens em lotes
        
        Args:
            character_list: Lista de personagens com nome e dados opcionais
            server: Servidor (ex: 'rubinot')
            world: Mundo (ex: 'auroria')
            
        Returns:
            BulkProcessingResult: Resultado do processamento
        """
        start_time = datetime.now()
        total_processed = 0
        successful = 0
        failed = 0
        skipped = 0
        errors = []
        
        logger.info(f"🚀 Iniciando processamento em lotes: {len(character_list)} personagens")
        logger.info(f"📊 Configuração: lote={self.config.batch_size}, concorrência={self.config.max_concurrent}")
        
        # Dividir em lotes
        batches = [
            character_list[i:i + self.config.batch_size] 
            for i in range(0, len(character_list), self.config.batch_size)
        ]
        
        logger.info(f"📦 Criados {len(batches)} lotes para processamento")
        
        for batch_idx, batch in enumerate(batches, 1):
            logger.info(f"📋 Processando lote {batch_idx}/{len(batches)} ({len(batch)} personagens)")
            
            # Processar lote com concorrência limitada
            batch_results = await self._process_batch_with_semaphore(batch, server, world)
            
            # Atualizar contadores
            total_processed += len(batch)
            successful += batch_results['successful']
            failed += batch_results['failed']
            skipped += batch_results['skipped']
            errors.extend(batch_results['errors'])
            
            # Log do progresso
            logger.info(f"✅ Lote {batch_idx} concluído: {batch_results['successful']} sucessos, "
                       f"{batch_results['failed']} falhas, {batch_results['skipped']} pulados")
            
            # Delay entre lotes (exceto o último)
            if batch_idx < len(batches):
                await asyncio.sleep(self.config.delay_between_batches)
        
        processing_time = (datetime.now() - start_time).total_seconds()
        
        result = BulkProcessingResult(
            total_processed=total_processed,
            successful=successful,
            failed=failed,
            skipped=skipped,
            processing_time=processing_time,
            errors=errors
        )
        
        logger.info(f"🎉 Processamento concluído: {result}")
        return result
    
    async def _process_batch_with_semaphore(
        self, 
        batch: List[Dict[str, Any]], 
        server: str, 
        world: str
    ) -> Dict[str, Any]:
        """Processar lote com controle de concorrência"""
        semaphore = asyncio.Semaphore(self.config.max_concurrent)
        
        async def process_single_character(char_data: Dict[str, Any]) -> Dict[str, Any]:
            async with semaphore:
                return await self._process_single_character(char_data, server, world)
        
        # Executar todos os personagens do lote com concorrência limitada
        tasks = [process_single_character(char_data) for char_data in batch]
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        # Contar resultados
        successful = 0
        failed = 0
        skipped = 0
        errors = []
        
        for result in results:
            if isinstance(result, Exception):
                failed += 1
                errors.append({
                    'error': str(result),
                    'type': 'exception'
                })
            elif isinstance(result, dict) and result.get('status') == 'success':
                successful += 1
            elif isinstance(result, dict) and result.get('status') == 'skipped':
                skipped += 1
            else:
                failed += 1
                if isinstance(result, dict):
                    errors.append(result.get('error', 'Unknown error'))
                else:
                    errors.append('Unknown error')
        
        return {
            'successful': successful,
            'failed': failed,
            'skipped': skipped,
            'errors': errors
        }
    
    async def _process_single_character(
        self, 
        char_data: Dict[str, Any], 
        server: str, 
        world: str
    ) -> Dict[str, Any]:
        """Processar um único personagem com retry"""
        character_name = char_data['name']
        
        for attempt in range(self.config.max_retries):
            try:
                # Verificar se já existe
                existing_character = await self.service.get_character_by_name_server_world(
                    character_name, server, world
                )
                
                if existing_character:
                    logger.debug(f"⏭️ Personagem {character_name} já existe, pulando")
                    return {'status': 'skipped', 'reason': 'already_exists'}
                
                # Fazer scraping
                scrape_result = await scrape_character_data(server, world, character_name)
                
                if not scrape_result.success:
                    if attempt < self.config.max_retries - 1:
                        logger.warning(f"⚠️ Tentativa {attempt + 1} falhou para {character_name}: {scrape_result.error_message}")
                        await asyncio.sleep(self.config.retry_delay)
                        continue
                    else:
                        return {
                            'status': 'failed',
                            'error': f"Scraping falhou após {self.config.max_retries} tentativas: {scrape_result.error_message}"
                        }
                
                # Criar personagem com snapshot
                from app.schemas.character import CharacterCreate
                
                character_data = CharacterCreate(
                    name=character_name,
                    server=server,
                    world=world
                )
                
                if scrape_result.data:
                    await self.service.create_character_with_snapshot(
                        character_data, scrape_result.data
                    )
                else:
                    logger.warning(f"⚠️ Dados vazios para {character_name}")
                    return {'status': 'failed', 'error': 'Empty data from scraping'}
                
                logger.debug(f"✅ Personagem {character_name} criado com sucesso")
                return {'status': 'success'}
                
            except Exception as e:
                if attempt < self.config.max_retries - 1:
                    logger.warning(f"⚠️ Tentativa {attempt + 1} falhou para {character_name}: {e}")
                    await asyncio.sleep(self.config.retry_delay)
                    continue
                else:
                    return {
                        'status': 'failed',
                        'error': f"Erro após {self.config.max_retries} tentativas: {str(e)}"
                    }
            
            # Delay entre requests
            await asyncio.sleep(self.config.delay_between_requests)
        
        return {'status': 'failed', 'error': 'Max retries exceeded'}
    
    async def process_rubinot_initial_load(self, world: str) -> BulkProcessingResult:
        """
        Processar carga inicial do Rubinot para um mundo específico
        
        Esta função é otimizada para o volume alto do Rubinot (+10.000 chars)
        """
        logger.info(f"🚀 Iniciando carga inicial do Rubinot para mundo: {world}")
        
        # Configuração otimizada para Rubinot
        rubinot_config = BulkProcessingConfig(
            batch_size=100,  # Lotes maiores para Rubinot
            max_concurrent=20,  # Mais concorrência
            delay_between_batches=1.0,  # Delay menor
            delay_between_requests=0.5,  # Delay menor entre requests
            max_retries=2,  # Menos tentativas para velocidade
            retry_delay=3.0
        )
        
        # Criar processador com configuração específica
        processor = BulkProcessor(self.db, rubinot_config)
        
        # TODO: Implementar obtenção da lista de personagens do Rubinot
        # Por enquanto, retornar resultado vazio
        logger.warning("⚠️ Lista de personagens do Rubinot não implementada ainda")
        
        return BulkProcessingResult(
            total_processed=0,
            successful=0,
            failed=0,
            skipped=0,
            processing_time=0.0,
            errors=[{'error': 'Lista de personagens não implementada'}]
        )
    
    async def get_processing_stats(self, server: str, world: str) -> Dict[str, Any]:
        """Obter estatísticas de processamento para um servidor/mundo"""
        try:
            # Contar personagens por servidor/mundo
            result = await self.db.execute(
                select(func.count(CharacterModel.id)).where(
                    and_(
                        CharacterModel.server == server.lower(),
                        CharacterModel.world == world.lower()
                    )
                )
            )
            character_count = result.scalar() or 0
            
            # Contar snapshots
            result = await self.db.execute(
                select(func.count(CharacterSnapshotModel.id)).where(
                    and_(
                        CharacterSnapshotModel.world == world.lower()
                    )
                )
            )
            snapshot_count = result.scalar() or 0
            
            # Personagens ativos
            result = await self.db.execute(
                select(func.count(CharacterModel.id)).where(
                    and_(
                        CharacterModel.server == server.lower(),
                        CharacterModel.world == world.lower(),
                        CharacterModel.is_active == True
                    )
                )
            )
            active_count = result.scalar() or 0
            
            return {
                'server': server,
                'world': world,
                'total_characters': character_count,
                'total_snapshots': snapshot_count,
                'active_characters': active_count,
                'last_updated': datetime.now().isoformat()
            }
            
        except Exception as e:
            logger.error(f"Erro ao obter estatísticas: {e}")
            return {
                'server': server,
                'world': world,
                'error': str(e)
            } 