#!/usr/bin/env python3
"""
Script para testar o filtro de atividade
"""

import asyncio
import sys
import os
from datetime import datetime, timedelta

# Adicionar o diretório do projeto ao path
sys.path.append('/app')

from sqlalchemy import select, and_, func
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.database import get_db
from app.models.character import Character, CharacterSnapshot

async def test_activity_filter():
    """Testar o filtro de atividade"""
    print("🧪 Testando filtro de atividade...\n")
    
    async for db in get_db():
        try:
            # Testar filtro "active_today"
            print("1. Testando filtro 'active_today':")
            
            today = datetime.utcnow().date()
            print(f"   Data de hoje: {today}")
            
            # Buscar snapshots de hoje com experiência > 0
            today_query = select(CharacterSnapshot.character_id).where(
                and_(
                    CharacterSnapshot.scraped_at >= today,
                    CharacterSnapshot.scraped_at < today + timedelta(days=1),
                    CharacterSnapshot.experience > 0
                )
            ).distinct()
            
            result = await db.execute(today_query)
            active_today_ids = result.scalars().all()
            
            print(f"   Personagens ativos hoje: {len(active_today_ids)}")
            print(f"   IDs: {active_today_ids}")
            
            # Buscar todos os personagens
            all_chars_query = select(Character)
            result = await db.execute(all_chars_query)
            all_chars = result.scalars().all()
            
            print(f"   Total de personagens: {len(all_chars)}")
            
            # Verificar snapshots de hoje para cada personagem
            print("\n2. Verificando snapshots de hoje para cada personagem:")
            for char in all_chars[:5]:  # Primeiros 5 personagens
                snapshot_query = select(CharacterSnapshot).where(
                    and_(
                        CharacterSnapshot.character_id == char.id,
                        CharacterSnapshot.scraped_at >= today,
                        CharacterSnapshot.scraped_at < today + timedelta(days=1)
                    )
                ).order_by(CharacterSnapshot.scraped_at.desc())
                
                result = await db.execute(snapshot_query)
                snapshots = result.scalars().all()
                
                if snapshots:
                    latest = snapshots[0]
                    print(f"   {char.name}: Exp={latest.experience}, Data={latest.scraped_at}")
                else:
                    print(f"   {char.name}: Nenhum snapshot hoje")
            
            # Testar filtro "active_yesterday"
            print("\n3. Testando filtro 'active_yesterday':")
            yesterday = today - timedelta(days=1)
            print(f"   Data de ontem: {yesterday}")
            
            yesterday_query = select(CharacterSnapshot.character_id).where(
                and_(
                    CharacterSnapshot.scraped_at >= yesterday,
                    CharacterSnapshot.scraped_at < yesterday + timedelta(days=1),
                    CharacterSnapshot.experience > 0
                )
            ).distinct()
            
            result = await db.execute(yesterday_query)
            active_yesterday_ids = result.scalars().all()
            
            print(f"   Personagens ativos ontem: {len(active_yesterday_ids)}")
            print(f"   IDs: {active_yesterday_ids}")
            
            # Verificar alguns snapshots de ontem
            print("\n4. Verificando snapshots de ontem:")
            for char in all_chars[:3]:  # Primeiros 3 personagens
                snapshot_query = select(CharacterSnapshot).where(
                    and_(
                        CharacterSnapshot.character_id == char.id,
                        CharacterSnapshot.scraped_at >= yesterday,
                        CharacterSnapshot.scraped_at < yesterday + timedelta(days=1)
                    )
                ).order_by(CharacterSnapshot.scraped_at.desc())
                
                result = await db.execute(snapshot_query)
                snapshots = result.scalars().all()
                
                if snapshots:
                    latest = snapshots[0]
                    print(f"   {char.name}: Exp={latest.experience}, Data={latest.scraped_at}")
                else:
                    print(f"   {char.name}: Nenhum snapshot ontem")
            
            print("\n✅ Teste concluído!")
            
        except Exception as e:
            print(f"❌ Erro no teste: {e}")
        finally:
            break

if __name__ == "__main__":
    asyncio.run(test_activity_filter()) 