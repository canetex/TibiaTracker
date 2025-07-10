#!/usr/bin/env python3
import asyncio
import sys
import os

# Adicionar o diretório do backend ao path
sys.path.append('/app')

from app.db.database import get_db
from app.models.character import Character

async def main():
    try:
        db = await anext(get_db())
        chars = db.query(Character).limit(10).all()
        
        print(f"Encontrados {len(chars)} personagens:")
        for char in chars:
            print(f"ID: {char.id}, Nome: {char.name}, Servidor: {char.server}/{char.world}")
            
    except Exception as e:
        print(f"Erro: {e}")

if __name__ == "__main__":
    asyncio.run(main()) 