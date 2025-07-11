#!/usr/bin/env python3
"""
Script para verificar dados de experiência no banco de dados
===========================================================

Verifica se os snapshots têm dados de experiência e identifica possíveis problemas.
"""

import asyncio
import sys
import os
from datetime import datetime, timedelta

# Adicionar o diretório do projeto ao path
sys.path.insert(0, '/app')

from app.db.database import get_db_session
from app.models.character import Character, CharacterSnapshot
from sqlalchemy import select, func, desc, and_

async def check_experience_data():
    """Verificar dados de experiência no banco"""
    
    print("🔍 VERIFICANDO DADOS DE EXPERIÊNCIA NO BANCO")
    print("=" * 50)
    
    async with get_db_session() as db:
        # 1. Estatísticas gerais
        print("\n📊 ESTATÍSTICAS GERAIS:")
        print("-" * 30)
        
        result = await db.execute(select(func.count(Character.id)))
        total_chars = result.scalar()
        print(f"Total de personagens: {total_chars}")
        
        result = await db.execute(select(func.count(CharacterSnapshot.id)))
        total_snapshots = result.scalar()
        print(f"Total de snapshots: {total_snapshots}")
        
        # 2. Snapshots com experiência > 0
        print("\n📈 SNAPSHOTS COM EXPERIÊNCIA > 0:")
        print("-" * 40)
        
        result = await db.execute(
            select(CharacterSnapshot)
            .where(CharacterSnapshot.experience > 0)
            .order_by(desc(CharacterSnapshot.scraped_at))
            .limit(10)
        )
        snapshots_with_exp = result.scalars().all()
        
        print(f"Snapshots com experiência > 0: {len(snapshots_with_exp)}")
        
        for snap in snapshots_with_exp:
            char_result = await db.execute(
                select(Character.name).where(Character.id == snap.character_id)
            )
            char_name = char_result.scalar()
            print(f"  - {char_name} (ID: {snap.character_id}): {snap.experience:,} exp em {snap.scraped_at}")
        
        # 3. Snapshots recentes (últimas 24h)
        print("\n🕒 SNAPSHOTS DAS ÚLTIMAS 24H:")
        print("-" * 35)
        
        yesterday = datetime.utcnow() - timedelta(days=1)
        result = await db.execute(
            select(CharacterSnapshot)
            .where(CharacterSnapshot.scraped_at >= yesterday)
            .order_by(desc(CharacterSnapshot.scraped_at))
            .limit(10)
        )
        recent_snapshots = result.scalars().all()
        
        print(f"Snapshots das últimas 24h: {len(recent_snapshots)}")
        
        for snap in recent_snapshots:
            char_result = await db.execute(
                select(Character.name).where(Character.id == snap.character_id)
            )
            char_name = char_result.scalar()
            print(f"  - {char_name}: {snap.experience:,} exp em {snap.scraped_at} (source: {snap.scrape_source})")
        
        # 4. Verificar personagens sem experiência
        print("\n❌ PERSONAGENS SEM EXPERIÊNCIA:")
        print("-" * 35)
        
        # Subquery para encontrar personagens sem snapshots com experiência > 0
        subquery = select(CharacterSnapshot.character_id).where(CharacterSnapshot.experience > 0).distinct()
        
        result = await db.execute(
            select(Character)
            .where(Character.id.notin_(subquery))
            .limit(10)
        )
        chars_without_exp = result.scalars().all()
        
        print(f"Personagens sem experiência > 0: {len(chars_without_exp)}")
        
        for char in chars_without_exp:
            # Contar snapshots deste personagem
            snap_count_result = await db.execute(
                select(func.count(CharacterSnapshot.id))
                .where(CharacterSnapshot.character_id == char.id)
            )
            snap_count = snap_count_result.scalar()
            print(f"  - {char.name}: {snap_count} snapshots, último scraping: {char.last_scraped_at}")
        
        # 5. Verificar campos específicos
        print("\n🔍 VERIFICANDO CAMPOS ESPECÍFICOS:")
        print("-" * 35)
        
        # Verificar se há snapshots com exp_date
        result = await db.execute(
            select(func.count(CharacterSnapshot.id))
            .where(CharacterSnapshot.exp_date.isnot(None))
        )
        snapshots_with_exp_date = result.scalar()
        print(f"Snapshots com exp_date: {snapshots_with_exp_date}")
        
        # Verificar se há snapshots com experience_history
        result = await db.execute(
            select(CharacterSnapshot)
            .where(CharacterSnapshot.experience > 0)
            .limit(1)
        )
        sample_snapshot = result.scalar_one_or_none()
        
        if sample_snapshot:
            print(f"Exemplo de snapshot com experiência:")
            print(f"  - ID: {sample_snapshot.id}")
            print(f"  - Character ID: {sample_snapshot.character_id}")
            print(f"  - Experience: {sample_snapshot.experience}")
            print(f"  - Exp Date: {sample_snapshot.exp_date}")
            print(f"  - Scraped At: {sample_snapshot.scraped_at}")
            print(f"  - Scrape Source: {sample_snapshot.scrape_source}")
        else:
            print("❌ Nenhum snapshot com experiência encontrado!")

if __name__ == "__main__":
    asyncio.run(check_experience_data()) 