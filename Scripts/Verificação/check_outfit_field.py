#!/usr/bin/env python3
"""
Script para verificar se o campo outfit_image_path existe na tabela characters
"""

import asyncio
from sqlalchemy import text
from app.db.database import engine

async def check_outfit_field():
    """Verificar se o campo outfit_image_path existe"""
    try:
        async with engine.begin() as conn:
            # Verificar se o campo existe na tabela characters
            result = await conn.execute(
                text("SELECT column_name FROM information_schema.columns "
                     "WHERE table_name = 'characters' AND column_name = 'outfit_image_path'")
            )
            characters_exists = result.rowcount > 0
            
            # Verificar se o campo existe na tabela character_snapshots
            result = await conn.execute(
                text("SELECT column_name FROM information_schema.columns "
                     "WHERE table_name = 'character_snapshots' AND column_name = 'outfit_image_path'")
            )
            snapshots_exists = result.rowcount > 0
            
            print(f"Campo outfit_image_path na tabela characters: {'EXISTE' if characters_exists else 'NÃO EXISTE'}")
            print(f"Campo outfit_image_path na tabela character_snapshots: {'EXISTE' if snapshots_exists else 'NÃO EXISTE'}")
            
            if not characters_exists or not snapshots_exists:
                print("\n⚠️  Campos não encontrados! Execute a migração:")
                print("docker exec -w /app tibia-tracker-backend python migrate-outfit-images.py")
            else:
                print("\n✅ Campos encontrados! Migração já foi executada.")
                
    except Exception as e:
        print(f"Erro ao verificar campos: {e}")

if __name__ == "__main__":
    asyncio.run(check_outfit_field()) 