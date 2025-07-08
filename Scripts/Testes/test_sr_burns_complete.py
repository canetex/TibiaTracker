#!/usr/bin/env python3
"""
Script completo para testar Sr Burns: verificar snapshots, fazer scraping e verificar novamente
"""

import asyncio
import sys
import os
from datetime import datetime, timedelta
from sqlalchemy import select, func, desc
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker

# Adicionar o diretório do backend ao path
sys.path.append(os.path.join(os.path.dirname(__file__), 'Backend'))

from app.models.character import Character, CharacterSnapshot
from app.services.scraping.taleon import TaleonCharacterScraper
from app.services.character import CharacterService

async def test_sr_burns_complete():
    """Teste completo do Sr Burns"""
    
    print("🔍 Teste completo do Sr Burns...")
    
    # Criar conexão com o banco
    engine = create_async_engine(
        "postgresql+asyncpg://tibia_user:taleondb@postgres:5432/tibia_tracker",
        echo=False
    )
    
    async_session = sessionmaker(
        engine, class_=AsyncSession, expire_on_commit=False
    )
    
    async with async_session() as db:
        try:
            # 1. Verificar snapshots atuais do Sr Burns
            print("\n1. Verificando snapshots atuais do Sr Burns:")
            
            result = await db.execute(
                select(Character)
                .where(Character.name.ilike('Sr Burns'))
            )
            character = result.scalar_one_or_none()
            
            if not character:
                print("   ❌ Sr Burns não encontrado no banco!")
                return
            
            print(f"   ✅ Sr Burns encontrado: ID {character.id}, Level {character.level}")
            
            # Verificar snapshots recentes
            result = await db.execute(
                select(CharacterSnapshot)
                .where(CharacterSnapshot.character_id == character.id)
                .order_by(CharacterSnapshot.scraped_at.desc())
                .limit(5)
            )
            
            snapshots = result.scalars().all()
            
            if snapshots:
                print(f"   📊 Últimos {len(snapshots)} snapshots:")
                for i, snap in enumerate(snapshots, 1):
                    print(f"   {i}. {snap.scraped_at.strftime('%Y-%m-%d %H:%M')} - Level: {snap.level}, Exp: {snap.experience:,}")
            else:
                print(f"   ❌ Nenhum snapshot encontrado para Sr Burns")
            
            # 2. Fazer scraping do Sr Burns
            print(f"\n2. Fazendo scraping do Sr Burns...")
            
            async with TaleonCharacterScraper() as scraper:
                scraping_result = await scraper.scrape_character("san", "Sr Burns")
                
                if not scraping_result.success:
                    print(f"   ❌ Erro no scraping: {scraping_result.error_message}")
                    return
                
                character_data = scraping_result.data
                
                print(f"   ✅ Dados extraídos:")
                print(f"      Nome: {character_data.get('name', 'N/A')}")
                print(f"      Level: {character_data.get('level', 'N/A')}")
                print(f"      Experience: {character_data.get('experience', 0):,}")
                print(f"      Guild: {character_data.get('guild', 'N/A')}")
                
                # 3. Comparar level atual vs level do banco
                current_level = character_data.get('level', 0)
                db_level = character.level
                
                print(f"\n3. Comparação de Levels:")
                print(f"   Level no banco: {db_level}")
                print(f"   Level atual (site): {current_level}")
                
                if current_level > db_level:
                    print(f"   🎉 Sr Burns subiu de level! {db_level} → {current_level}")
                elif current_level == db_level:
                    print(f"   ✅ Level está igual")
                else:
                    print(f"   ⚠️  Level diminuiu (estranho)")
                
                # 4. Criar novo snapshot
                print(f"\n4. Criando novo snapshot...")
                
                character_service = CharacterService(db)
                
                # Preparar dados do snapshot
                snapshot_data = {
                    'level': current_level,
                    'experience': character_data.get('experience', 0),
                    'vocation': character_data.get('vocation', 'None'),
                    'residence': character_data.get('residence', ''),
                    'guild': character_data.get('guild'),
                    'guild_rank': character_data.get('guild_rank'),
                    'is_online': character_data.get('is_online', False),
                    'last_login': character_data.get('last_login'),
                    'profile_url': character_data.get('profile_url', ''),
                    'outfit_image_url': character_data.get('outfit_image_url'),
                }
                
                try:
                    new_snapshot = await character_service.create_snapshot(
                        character.id, 
                        snapshot_data, 
                        source="test"
                    )
                    print(f"   ✅ Novo snapshot criado: ID {new_snapshot.id}")
                    print(f"      Level: {new_snapshot.level}, Exp: {new_snapshot.experience:,}")
                    print(f"      Data: {new_snapshot.scraped_at}")
                except Exception as e:
                    print(f"   ❌ Erro ao criar snapshot: {e}")
                    return
            
            # 5. Verificar snapshots após criação
            print(f"\n5. Verificando snapshots após criação:")
            
            result = await db.execute(
                select(CharacterSnapshot)
                .where(CharacterSnapshot.character_id == character.id)
                .order_by(CharacterSnapshot.scraped_at.desc())
                .limit(5)
            )
            
            new_snapshots = result.scalars().all()
            
            if new_snapshots:
                print(f"   📊 Últimos {len(new_snapshots)} snapshots:")
                for i, snap in enumerate(new_snapshots, 1):
                    print(f"   {i}. {snap.scraped_at.strftime('%Y-%m-%d %H:%M')} - Level: {snap.level}, Exp: {snap.experience:,}")
            else:
                print(f"   ❌ Nenhum snapshot encontrado")
            
            # 6. Verificar se o level do personagem foi atualizado
            print(f"\n6. Verificando se o level do personagem foi atualizado:")
            
            result = await db.execute(
                select(Character.level)
                .where(Character.id == character.id)
            )
            updated_level = result.scalar_one_or_none()
            
            print(f"   Level anterior: {db_level}")
            print(f"   Level atual: {updated_level}")
            
            if updated_level == current_level:
                print(f"   ✅ Level do personagem foi atualizado corretamente!")
            else:
                print(f"   ❌ Level do personagem não foi atualizado")
            
            print(f"\n✅ Teste completo concluído!")
            
        except Exception as e:
            print(f"❌ Erro no teste: {e}")
            import traceback
            traceback.print_exc()

if __name__ == "__main__":
    asyncio.run(test_sr_burns_complete()) 