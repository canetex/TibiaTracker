"""
Serviço de Agendamento de Tarefas
=================================

Gerencia tarefas agendadas usando APScheduler para atualizações automáticas.
"""

import logging
from datetime import datetime, timedelta
from typing import Optional
import asyncio

from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.jobstores.memory import MemoryJobStore
from apscheduler.executors.asyncio import AsyncIOExecutor
from apscheduler.triggers.cron import CronTrigger
from apscheduler.triggers.date import DateTrigger
import pytz

from app.core.config import settings
from app.db.database import get_db_session
from app.services.scraping import scrape_character_data
from app.services.character import CharacterService

logger = logging.getLogger(__name__)

# Instância global do scheduler
scheduler: Optional[AsyncIOScheduler] = None


def create_scheduler() -> AsyncIOScheduler:
    """
    Criar e configurar o scheduler
    """
    jobstores = {
        'default': MemoryJobStore()
    }
    
    executors = {
        'default': AsyncIOExecutor()
    }
    
    job_defaults = {
        'coalesce': True,
        'max_instances': 3,
        'misfire_grace_time': 300  # 5 minutos
    }
    
    timezone = pytz.timezone(settings.SCHEDULER_TIMEZONE)
    
    return AsyncIOScheduler(
        jobstores=jobstores,
        executors=executors,
        job_defaults=job_defaults,
        timezone=timezone
    )


def start_scheduler():
    """
    Iniciar o scheduler e agendar tarefas
    """
    global scheduler
    
    try:
        scheduler = create_scheduler()
        
        # Agendar atualização diária de todos os personagens
        scheduler.add_job(
            func=update_all_characters,
            trigger=CronTrigger(
                hour=settings.DAILY_UPDATE_HOUR,
                minute=settings.DAILY_UPDATE_MINUTE,
                timezone=settings.SCHEDULER_TIMEZONE
            ),
            id='daily_character_update',
            name='Atualização diária de personagens',
            replace_existing=True
        )
        
        # Agendar limpeza de dados antigos (semanal)
        scheduler.add_job(
            func=cleanup_old_data,
            trigger=CronTrigger(
                day_of_week='sun',
                hour=2,
                minute=0,
                timezone=settings.SCHEDULER_TIMEZONE
            ),
            id='weekly_cleanup',
            name='Limpeza semanal de dados',
            replace_existing=True
        )
        
        scheduler.start()
        logger.info("🕒 Scheduler iniciado com sucesso")
        logger.info(f"⏰ Atualização diária agendada para {settings.DAILY_UPDATE_HOUR:02d}:{settings.DAILY_UPDATE_MINUTE:02d}")
        
    except Exception as e:
        logger.error(f"❌ Erro ao iniciar scheduler: {e}")
        raise


def stop_scheduler():
    """
    Parar o scheduler
    """
    global scheduler
    
    if scheduler and scheduler.running:
        try:
            scheduler.shutdown(wait=True)
            logger.info("🛑 Scheduler parado com sucesso")
        except Exception as e:
            logger.error(f"❌ Erro ao parar scheduler: {e}")
    else:
        logger.info("ℹ️ Scheduler já estava parado")


async def update_all_characters():
    """
    Atualizar todos os personagens ativos com recovery ativo
    """
    logger.info("🔄 Iniciando atualização diária de personagens...")
    
    try:
        async with get_db_session() as db:
            service = CharacterService(db)
            
            # Buscar personagens que precisam ser atualizados (apenas com recovery ativo)
            from sqlalchemy import select, and_, or_
            from app.models.character import Character
            
            result = await db.execute(
                select(Character).where(
                    and_(
                        Character.is_active == True,
                        Character.recovery_active == True,  # Apenas personagens com recovery ativo
                        or_(
                            Character.next_scrape_at <= datetime.now(),
                            Character.next_scrape_at.is_(None)
                        )
                    )
                )
            )
            characters = result.scalars().all()
            
            logger.info(f"📋 Encontrados {len(characters)} personagens para atualizar (com recovery ativo)")
            
            success_count = 0
            error_count = 0
            deactivated_count = 0
            
            for character in characters:
                try:
                    await update_character_data(character.id, source="scheduled")
                    success_count += 1
                    
                    # Pequeno delay entre updates para não sobrecarregar os sites
                    await asyncio.sleep(settings.SCRAPE_DELAY_SECONDS)
                    
                except Exception as e:
                    logger.error(f"❌ Erro ao atualizar personagem {character.name}: {e}")
                    error_count += 1
                    
                    # Incrementar contador de erro e agendar retry
                    character.scrape_error_count += 1
                    character.last_scrape_error = str(e)
                    
                    # Verificar se deve desativar recovery por erro consecutivo
                    if character.scrape_error_count >= 3:
                        character.recovery_active = False
                        deactivated_count += 1
                        logger.warning(f"⚠️ Personagem {character.name} desativado por 3 erros consecutivos")
                        character.next_scrape_at = datetime.now() + timedelta(hours=24)
                    elif character.scrape_error_count >= settings.SCRAPE_RETRY_ATTEMPTS:
                        character.next_scrape_at = datetime.now() + timedelta(hours=24)
                        logger.warning(f"⚠️ Personagem {character.name} atingiu limite de erros, próxima tentativa em 24h")
                    else:
                        character.next_scrape_at = datetime.now() + timedelta(minutes=settings.SCRAPE_RETRY_DELAY_MINUTES)
                    
                    await db.commit()
            
            # Verificar personagens com 10 dias sem experiência e desativar recovery
            await check_and_deactivate_inactive_characters(db)
            
            logger.info(f"✅ Atualização concluída: {success_count} sucessos, {error_count} erros, {deactivated_count} desativados por erro")
            
    except Exception as e:
        logger.error(f"❌ Erro na atualização diária: {e}")


async def update_character_data(character_id: int, source: str = "scheduled"):
    """
    Atualizar dados de um personagem específico
    """
    try:
        async with get_db_session() as db:
            try:
                service = CharacterService(db)
                character = await service.get_character(character_id)
                
                if not character:
                    logger.warning(f"⚠️ Personagem {character_id} não encontrado")
                    return
                
                logger.info(f"🔄 Atualizando personagem {character.name}")
                
                # Fazer scraping
                scrape_result = await scrape_character_data(
                    character.server, character.world, character.name
                )
                
                if scrape_result.success:
                    # Criar/atualizar snapshots com histórico completo
                    snapshot_result = await service.create_snapshot_with_history(character.id, scrape_result.data, source)
                    
                    # Agendar próxima atualização
                    await service.schedule_next_update(character.id)
                    
                    # Commit da transação
                    await db.commit()
                    
                    logger.info(f"✅ Personagem {character.name} atualizado com sucesso - "
                              f"Snapshots: {snapshot_result['created']} criados, {snapshot_result['updated']} atualizados")
                    
                else:
                    # Lidar com erro
                    character.scrape_error_count += 1
                    character.last_scrape_error = scrape_result.error_message
                    
                    if scrape_result.retry_after:
                        character.next_scrape_at = scrape_result.retry_after
                    else:
                        character.next_scrape_at = datetime.now() + timedelta(hours=1)
                    
                    # Commit da transação
                    await db.commit()
                    
                    logger.warning(f"⚠️ Erro ao atualizar {character.name}: {scrape_result.error_message}")
                    
            except Exception as e:
                # Rollback em caso de erro
                await db.rollback()
                logger.error(f"❌ Erro ao atualizar personagem {character_id}: {e}")
                raise
                
    except Exception as e:
        logger.error(f"❌ Erro ao atualizar personagem {character_id}: {e}")


async def cleanup_old_data():
    """
    Limpeza de dados antigos (manter apenas últimos 90 dias)
    """
    logger.info("🧹 Iniciando limpeza de dados antigos...")
    
    try:
        async with get_db_session() as db:
            from sqlalchemy import delete, and_
            from app.models.character import CharacterSnapshot
            
            # Data limite (90 dias atrás)
            cutoff_date = datetime.now() - timedelta(days=90)
            
            # Deletar snapshots antigos
            result = await db.execute(
                delete(CharacterSnapshot).where(
                    CharacterSnapshot.scraped_at < cutoff_date
                )
            )
            
            deleted_count = result.rowcount
            await db.commit()
            
            logger.info(f"🗑️ Removidos {deleted_count} snapshots antigos")
            
    except Exception as e:
        logger.error(f"❌ Erro na limpeza de dados: {e}")


def schedule_character_update(character_id: int, when: datetime):
    """
    Agendar atualização de um personagem específico
    """
    if not scheduler:
        logger.warning("⚠️ Scheduler não está iniciado")
        return
    
    job_id = f"character_update_{character_id}"
    
    try:
        scheduler.add_job(
            func=update_character_data,
            trigger=DateTrigger(run_date=when),
            args=[character_id, "retry"],
            id=job_id,
            name=f"Atualização do personagem {character_id}",
            replace_existing=True
        )
        
        logger.info(f"📅 Atualização agendada para personagem {character_id} em {when}")
        
    except Exception as e:
        logger.error(f"❌ Erro ao agendar atualização: {e}")


def get_scheduler_info() -> dict:
    """
    Obter informações sobre o scheduler
    """
    if not scheduler:
        return {"status": "stopped", "jobs": []}
    
    jobs = []
    for job in scheduler.get_jobs():
        jobs.append({
            "id": job.id,
            "name": job.name,
            "next_run": job.next_run_time.isoformat() if job.next_run_time else None,
            "trigger": str(job.trigger)
        })
    
    return {
        "status": "running" if scheduler.running else "stopped",
        "timezone": str(scheduler.timezone),
        "jobs": jobs
    } 


async def check_and_deactivate_inactive_characters(db):
    """
    Verificar e desativar personagens que não tiveram experiência nos últimos 10 dias
    """
    try:
        from sqlalchemy import select, and_, not_, exists
        from app.models.character import Character, CharacterSnapshot
        
        # Buscar personagens ativos com recovery ativo que não tiveram experiência nos últimos 10 dias
        subquery = select(CharacterSnapshot.id).where(
            and_(
                CharacterSnapshot.character_id == Character.id,
                CharacterSnapshot.exp_date >= datetime.now().date() - timedelta(days=10),
                CharacterSnapshot.experience > 0
            )
        )
        
        result = await db.execute(
            select(Character).where(
                and_(
                    Character.is_active == True,
                    Character.recovery_active == True,
                    not_(exists(subquery))
                )
            )
        )
        
        inactive_characters = result.scalars().all()
        
        if inactive_characters:
            for character in inactive_characters:
                character.recovery_active = False
                logger.info(f"⚠️ Personagem {character.name} desativado por 10 dias sem experiência")
            
            await db.commit()
            logger.info(f"🔄 {len(inactive_characters)} personagens desativados por inatividade")
            
    except Exception as e:
        logger.error(f"❌ Erro ao verificar personagens inativos: {e}")
        await db.rollback() 