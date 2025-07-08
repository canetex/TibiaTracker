#!/usr/bin/env python3
"""
Script para verificar se os snapshots estão sendo salvos corretamente
Especialmente o campo level que parece estar com problemas
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

from app.db.database import get_db
from app.models.character import Character, CharacterSnapshot

async def check_snapshots():
    """Verificar snapshots no banco de dados"""
    
    print("🔍 Verificando snapshots no banco de dados...")
    
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
            # 1. Verificar personagens com mais snapshots
            print("\n1. Personagens com mais snapshots:")
            result = await db.execute(
                select(Character.id, Character.name, Character.server, Character.world, func.count(CharacterSnapshot.id).label('snapshot_count'))
                .join(CharacterSnapshot, Character.id == CharacterSnapshot.character_id)
                .group_by(Character.id, Character.name, Character.server, Character.world)
                .order_by(desc('snapshot_count'))
                .limit(10)
            )
            
            characters_with_snapshots = result.fetchall()
            for char in characters_with_snapshots:
                print(f"   {char.name} ({char.server}/{char.world}): {char.snapshot_count} snapshots")
            
            if not characters_with_snapshots:
                print("   ❌ Nenhum personagem com snapshots encontrado!")
                return
            
            # 2. Verificar snapshots de um personagem específico
            test_character = characters_with_snapshots[0]
            print(f"\n2. Verificando snapshots de {test_character.name}:")
            
            result = await db.execute(
                select(CharacterSnapshot)
                .where(CharacterSnapshot.character_id == test_character.id)
                .order_by(CharacterSnapshot.scraped_at.desc())
                .limit(10)
            )
            
            snapshots = result.scalars().all()
            
            if not snapshots:
                print(f"   ❌ Nenhum snapshot encontrado para {test_character.name}")
                return
            
            print(f"   📊 Últimos {len(snapshots)} snapshots:")
            for i, snap in enumerate(snapshots, 1):
                print(f"   {i}. {snap.scraped_at.strftime('%Y-%m-%d %H:%M')} - Level: {snap.level}, Exp: {snap.experience:,}")
            
            # 3. Verificar se há variação no level
            print(f"\n3. Análise de variação do level para {test_character.name}:")
            
            levels = [snap.level for snap in snapshots]
            unique_levels = set(levels)
            
            print(f"   📈 Levels únicos encontrados: {sorted(unique_levels)}")
            print(f"   🔢 Total de snapshots: {len(levels)}")
            print(f"   🎯 Levels únicos: {len(unique_levels)}")
            
            if len(unique_levels) == 1:
                print(f"   ⚠️  PROBLEMA: Level não está variando! Sempre {levels[0]}")
            else:
                print(f"   ✅ Level está variando corretamente")
                print(f"   📊 Variação: {min(levels)} → {max(levels)} (+{max(levels) - min(levels)})")
            
            # 4. Verificar snapshots dos últimos 7 dias
            print(f"\n4. Snapshots dos últimos 7 dias:")
            seven_days_ago = datetime.now() - timedelta(days=7)
            
            result = await db.execute(
                select(CharacterSnapshot)
                .where(CharacterSnapshot.character_id == test_character.id)
                .where(CharacterSnapshot.scraped_at >= seven_days_ago)
                .order_by(CharacterSnapshot.scraped_at.desc())
            )
            
            recent_snapshots = result.scalars().all()
            
            if recent_snapshots:
                print(f"   📅 Últimos 7 dias - {len(recent_snapshots)} snapshots:")
                for snap in recent_snapshots:
                    print(f"   {snap.scraped_at.strftime('%Y-%m-%d %H:%M')} - Level: {snap.level}, Exp: {snap.experience:,}")
            else:
                print(f"   ❌ Nenhum snapshot nos últimos 7 dias")
            
            # 5. Verificar se há snapshots duplicados no mesmo dia
            print(f"\n5. Verificando snapshots duplicados no mesmo dia:")
            
            result = await db.execute(
                select(
                    func.date(CharacterSnapshot.scraped_at).label('date'),
                    func.count(CharacterSnapshot.id).label('count')
                )
                .where(CharacterSnapshot.character_id == test_character.id)
                .group_by(func.date(CharacterSnapshot.scraped_at))
                .having(func.count(CharacterSnapshot.id) > 1)
                .order_by(desc('count'))
            )
            
            duplicate_days = result.fetchall()
            
            if duplicate_days:
                print(f"   ⚠️  Dias com múltiplos snapshots:")
                for day in duplicate_days:
                    print(f"   {day.date}: {day.count} snapshots")
            else:
                print(f"   ✅ Nenhum dia com snapshots duplicados")
            
            # 6. Verificar personagens com level 0 ou inválido
            print(f"\n6. Verificando personagens com level 0 ou inválido:")
            
            result = await db.execute(
                select(Character.id, Character.name, Character.level, func.count(CharacterSnapshot.id).label('snapshot_count'))
                .join(CharacterSnapshot, Character.id == CharacterSnapshot.character_id)
                .where(Character.level <= 0)
                .group_by(Character.id, Character.name, Character.level)
                .order_by(desc('snapshot_count'))
                .limit(5)
            )
            
            invalid_level_chars = result.fetchall()
            
            if invalid_level_chars:
                print(f"   ⚠️  Personagens com level inválido:")
                for char in invalid_level_chars:
                    print(f"   {char.name}: Level {char.level} ({char.snapshot_count} snapshots)")
            else:
                print(f"   ✅ Nenhum personagem com level inválido encontrado")
            
            print(f"\n✅ Verificação concluída!")
            
        except Exception as e:
            print(f"❌ Erro ao verificar snapshots: {e}")
            import traceback
            traceback.print_exc()

if __name__ == "__main__":
    asyncio.run(check_snapshots()) 