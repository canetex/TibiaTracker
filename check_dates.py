#!/usr/bin/env python3
"""
Script para verificar datas dos snapshots
"""

import asyncio
import sys
from datetime import datetime, date

# Adicionar o diretório do projeto ao path
sys.path.append('/app')

from app.db.database import get_db
from sqlalchemy import select, func
from app.models.character import CharacterSnapshot

async def check_snapshot_dates():
    """Verificar datas dos snapshots"""
    db = await anext(get_db())
    try:
        # Buscar datas com snapshots
        result = await db.execute(
            select(
                func.date(CharacterSnapshot.scraped_at).label('date'),
                func.count().label('count')
            )
            .group_by(func.date(CharacterSnapshot.scraped_at))
            .order_by(func.date(CharacterSnapshot.scraped_at))
        )
        dates = result.all()
        
        print("=== DATAS COM SNAPSHOTS ===")
        for d in dates[-15:]:  # Últimas 15 datas
            print(f"{d.date}: {d.count} snapshots")
            
        # Verificar especificamente os dias 11, 12 e 13
        print("\n=== VERIFICAÇÃO DOS DIAS 11, 12 E 13 ===")
        for day in [11, 12, 13]:
            result = await db.execute(
                select(func.count())
                .where(func.date(CharacterSnapshot.scraped_at) == date(2025, 7, day))
            )
            count = result.scalar()
            print(f"2025-07-{day:02d}: {count} snapshots")
            
    except Exception as e:
        print(f"Erro: {e}")
    finally:
        await db.close()

if __name__ == "__main__":
    asyncio.run(check_snapshot_dates()) 