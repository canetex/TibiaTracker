#!/usr/bin/env python3
"""
Teste simples do Sr Burns sem SQL bruto
"""

import asyncio
import sys
import os
from datetime import datetime

# Adicionar o diretório do backend ao path
sys.path.insert(0, '/app')

from app.services.scraping.taleon import TaleonCharacterScraper
from app.db.database import get_db_session
from app.models.character import Character, CharacterSnapshot

async def test_sr_burns_simple():
    """Teste simples do Sr Burns"""
    
    print("🔍 Teste simples do Sr Burns...")
    
    # 1. Verificar personagem
    print("\n1. Verificando Sr Burns no banco:")
    async with get_db_session() as session:
        # Buscar personagem
        character = await session.get(Character, 314)
        if not character:
            print("   ❌ Sr Burns não encontrado no banco")
            return
        
        print(f"   ✅ Sr Burns encontrado: ID {character.id}, Level {character.level}")
        
        # Buscar últimos snapshots usando ORM
        from sqlalchemy import select, desc
        stmt = select(CharacterSnapshot).where(CharacterSnapshot.character_id == 314).order_by(desc(CharacterSnapshot.scraped_at)).limit(5)
        result = await session.execute(stmt)
        snapshots = result.scalars().all()
        
        print(f"   📊 Últimos {len(snapshots)} snapshots:")
        for i, snapshot in enumerate(snapshots, 1):
            print(f"   {i}. {snapshot.scraped_at.strftime('%Y-%m-%d %H:%M')} - Level: {snapshot.level}, Exp: {snapshot.experience:,}")
    
    # 2. Fazer scraping
    print("\n2. Fazendo scraping do Sr Burns...")
    scraper = TaleonCharacterScraper()
    
    try:
        async with scraper:
            result = await scraper.scrape_character('san', 'Sr Burns')
            
            if not result.success:
                print(f"   ❌ Erro no scraping: {result.error_message}")
                return
            
            data = result.data
            print(f"   ✅ Dados extraídos:")
            print(f"      Nome: {data['name']}")
            print(f"      Level: {data['level']}")
            print(f"      Experience: {data['experience']:,}")
            print(f"      World: {data['world']}")
            print(f"      Guild: {data['guild']}")
            
            # 3. Comparação de levels
            print(f"\n3. Comparação de Levels:")
            print(f"   Level no banco: {character.level}")
            print(f"   Level atual (site): {data['level']}")
            
            if data['level'] > character.level:
                print(f"   🎉 Sr Burns subiu de level! {character.level} → {data['level']}")
            elif data['level'] == character.level:
                print(f"   📊 Level permanece o mesmo: {character.level}")
            else:
                print(f"   ⚠️  Level diminuiu (estranho): {character.level} → {data['level']}")
            
            # 4. Criar novo snapshot
            print(f"\n4. Criando novo snapshot...")
            
            # Criar snapshot usando os dados do scraper
            new_snapshot = CharacterSnapshot(
                character_id=character.id,
                level=data['level'],
                experience=data['experience'],
                deaths=data['deaths'],
                charm_points=data['charm_points'],
                bosstiary_points=data['bosstiary_points'],
                achievement_points=data['achievement_points'],
                vocation=data['vocation'],
                world=data['world'],  # Agora deve estar preenchido
                residence=data['residence'],
                house=data['house'],
                guild=data['guild'],
                guild_rank=data['guild_rank'],
                is_online=data['is_online'],
                last_login=data['last_login'],
                outfit_image_url=data['outfit_image_url'],
                outfit_data=data.get('outfit_data'),
                profile_url=data['profile_url'],
                scrape_source='test',
                scrape_duration=result.duration_ms
            )
            
            async with get_db_session() as session:
                session.add(new_snapshot)
                await session.commit()
                
                print(f"   ✅ Snapshot criado com sucesso!")
                print(f"      ID: {new_snapshot.id}")
                print(f"      Level: {new_snapshot.level}")
                print(f"      World: {new_snapshot.world}")
                print(f"      Experience: {new_snapshot.experience:,}")
                
    except Exception as e:
        print(f"   ❌ Erro ao criar snapshot: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    asyncio.run(test_sr_burns_simple()) 