#!/usr/bin/env python3
"""
Script de Re-scraping Completo de Todos os Personagens
======================================================

Este script faz scraping completo de todos os personagens ativos no banco,
atualizando seus dados e criando novos snapshots com informações atualizadas.
"""

import asyncio
import sys
import os
from datetime import datetime, timedelta
from typing import List, Dict, Any
import logging

# Adicionar o diretório do backend ao path
sys.path.insert(0, '/app')

from app.db.database import get_db_session
from app.models.character import Character, CharacterSnapshot
from app.services.scraping.taleon import TaleonCharacterScraper

# Configurar logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/tibia-tracker/full-rescrape.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class FullRescrapeService:
    """Serviço para re-scraping completo de todos os personagens"""
    
    def __init__(self):
        self.scraper = TaleonCharacterScraper()
        self.stats = {
            'total_characters': 0,
            'successful_scrapes': 0,
            'failed_scrapes': 0,
            'level_ups': 0,
            'errors': []
        }
    
    async def get_all_active_characters(self) -> List[Character]:
        """Buscar todos os personagens ativos"""
        async with get_db_session() as session:
            from sqlalchemy import select
            stmt = select(Character).where(Character.is_active == True).order_by(Character.name)
            result = await session.execute(stmt)
            characters = result.scalars().all()
            return characters
    
    async def scrape_character(self, character: Character) -> Dict[str, Any]:
        """Fazer scraping de um personagem específico"""
        try:
            logger.info(f"🔍 Scraping {character.name} ({character.world})...")
            
            async with self.scraper:
                result = await self.scraper.scrape_character(character.world, character.name)
                
                if not result.success:
                    error_msg = f"Erro no scraping de {character.name}: {result.error_message}"
                    logger.error(error_msg)
                    self.stats['errors'].append(error_msg)
                    return {'success': False, 'error': result.error_message}
                
                data = result.data
                logger.info(f"✅ {character.name} - Level: {data['level']}, Exp: {data['experience']:,}")
                
                # Verificar se subiu de level
                if data['level'] > character.level:
                    logger.info(f"🎉 {character.name} subiu de level! {character.level} → {data['level']}")
                    self.stats['level_ups'] += 1
                
                return {
                    'success': True,
                    'data': data,
                    'duration_ms': result.duration_ms
                }
                
        except Exception as e:
            error_msg = f"Erro inesperado no scraping de {character.name}: {str(e)}"
            logger.error(error_msg)
            self.stats['errors'].append(error_msg)
            return {'success': False, 'error': str(e)}
    
    async def create_snapshot(self, character: Character, scraped_data: Dict[str, Any]) -> bool:
        """Criar snapshot com os dados do scraping"""
        try:
            data = scraped_data['data']
            
            new_snapshot = CharacterSnapshot(
                character_id=character.id,
                level=data['level'],
                experience=data['experience'],
                deaths=data['deaths'],
                charm_points=data['charm_points'],
                bosstiary_points=data['bosstiary_points'],
                achievement_points=data['achievement_points'],
                vocation=data['vocation'],
                world=data['world'],
                residence=data['residence'],
                house=data['house'],
                guild=data['guild'],
                guild_rank=data['guild_rank'],
                is_online=data['is_online'],
                last_login=data['last_login'],
                outfit_image_url=data['outfit_image_url'],
                outfit_data=data.get('outfit_data'),
                profile_url=data['profile_url'],
                scrape_source='full_rescrape',
                scrape_duration=scraped_data['duration_ms'],
                exp_date=data.get('exp_date') or datetime.utcnow().date()
            )
            
            async with get_db_session() as session:
                session.add(new_snapshot)
                await session.commit()
                
                logger.info(f"💾 Snapshot criado para {character.name} (ID: {new_snapshot.id})")
                return True
                
        except Exception as e:
            error_msg = f"Erro ao criar snapshot para {character.name}: {str(e)}"
            logger.error(error_msg)
            self.stats['errors'].append(error_msg)
            return False
    
    async def update_character_data(self, character: Character, scraped_data: Dict[str, Any]) -> bool:
        """Atualizar dados do personagem no banco"""
        try:
            data = scraped_data['data']
            
            async with get_db_session() as session:
                # Buscar personagem atualizado
                current_character = await session.get(Character, character.id)
                if not current_character:
                    logger.error(f"Personagem {character.name} não encontrado para atualização")
                    return False
                
                # Atualizar campos
                current_character.level = data['level']
                current_character.vocation = data['vocation']
                current_character.residence = data['residence']
                current_character.guild = data['guild']
                current_character.outfit_image_url = data['outfit_image_url']
                current_character.last_scraped_at = datetime.now()
                current_character.scrape_error_count = 0
                current_character.last_scrape_error = None
                current_character.next_scrape_at = datetime.now() + timedelta(hours=24)
                
                await session.commit()
                logger.info(f"📝 Dados de {character.name} atualizados no banco")
                return True
                
        except Exception as e:
            error_msg = f"Erro ao atualizar dados de {character.name}: {str(e)}"
            logger.error(error_msg)
            self.stats['errors'].append(error_msg)
            return False
    
    async def process_character(self, character: Character) -> bool:
        """Processar um personagem completo (scraping + snapshot + atualização)"""
        try:
            # 1. Fazer scraping
            scraped_data = await self.scrape_character(character)
            if not scraped_data['success']:
                self.stats['failed_scrapes'] += 1
                return False
            
            # 2. Criar snapshot
            snapshot_created = await self.create_snapshot(character, scraped_data)
            if not snapshot_created:
                return False
            
            # 3. Atualizar dados do personagem
            character_updated = await self.update_character_data(character, scraped_data)
            if not character_updated:
                return False
            
            self.stats['successful_scrapes'] += 1
            return True
            
        except Exception as e:
            error_msg = f"Erro geral no processamento de {character.name}: {str(e)}"
            logger.error(error_msg)
            self.stats['errors'].append(error_msg)
            self.stats['failed_scrapes'] += 1
            return False
    
    async def run_full_rescrape(self):
        """Executar re-scraping completo de todos os personagens"""
        start_time = datetime.now()
        logger.info("🚀 Iniciando re-scraping completo de todos os personagens...")
        
        try:
            # Buscar todos os personagens ativos
            characters = await self.get_all_active_characters()
            self.stats['total_characters'] = len(characters)
            
            logger.info(f"📊 Encontrados {len(characters)} personagens ativos para processar")
            
            # Processar cada personagem
            for i, character in enumerate(characters, 1):
                logger.info(f"📋 [{i}/{len(characters)}] Processando {character.name}...")
                
                success = await self.process_character(character)
                
                # Delay entre requests para não sobrecarregar o servidor
                if i < len(characters):  # Não fazer delay no último
                    await asyncio.sleep(3)  # 3 segundos entre requests
            
            # Relatório final
            end_time = datetime.now()
            duration = end_time - start_time
            
            logger.info("=" * 60)
            logger.info("📊 RELATÓRIO FINAL DO RE-SCRAPING")
            logger.info("=" * 60)
            logger.info(f"⏱️  Duração total: {duration}")
            logger.info(f"👥 Total de personagens: {self.stats['total_characters']}")
            logger.info(f"✅ Scrapings bem-sucedidos: {self.stats['successful_scrapes']}")
            logger.info(f"❌ Scrapings falharam: {self.stats['failed_scrapes']}")
            logger.info(f"🎉 Personagens que subiram de level: {self.stats['level_ups']}")
            logger.info(f"📈 Taxa de sucesso: {(self.stats['successful_scrapes']/self.stats['total_characters']*100):.1f}%")
            
            if self.stats['errors']:
                logger.info(f"⚠️  Erros encontrados: {len(self.stats['errors'])}")
                for error in self.stats['errors'][:5]:  # Mostrar apenas os primeiros 5 erros
                    logger.error(f"   - {error}")
                if len(self.stats['errors']) > 5:
                    logger.error(f"   ... e mais {len(self.stats['errors']) - 5} erros")
            
            logger.info("=" * 60)
            
        except Exception as e:
            logger.error(f"❌ Erro crítico no re-scraping: {str(e)}")
            raise

async def main():
    """Função principal"""
    service = FullRescrapeService()
    await service.run_full_rescrape()

if __name__ == "__main__":
    asyncio.run(main()) 