#!/usr/bin/env python3
"""
Script para consultar dados de um personagem específico
"""

import asyncio
import sys
import os

# Adicionar o diretório do projeto ao path
sys.path.append('/app')

from app.db.database import get_db
from app.services.character import CharacterService
from app.models.character import Character

async def check_character(name: str):
    """Consultar dados de um personagem"""
    db = await anext(get_db())
    try:
        # Buscar personagem por nome
        from sqlalchemy import select
        query = select(Character).where(Character.name.ilike(name))
        result = await db.execute(query)
        character = result.scalar_one_or_none()
        
        if character:
            print(f"=== DADOS DO PERSONAGEM: {character.name} ===")
            print(f"ID: {character.id}")
            print(f"Nome: {character.name}")
            print(f"Servidor: {character.server}")
            print(f"World: {character.world}")
            print(f"Level: {character.level}")
            print(f"Vocação: {character.vocation}")
            print(f"Guild: {character.guild}")
            print(f"Residência: {character.residence}")
            print(f"URL do Perfil: {character.profile_url}")
            print(f"URL da Imagem do Outfit: {character.outfit_image_url}")
            print(f"Último Scraping: {character.last_scraped_at}")
            print(f"Ativo: {character.is_active}")
            print(f"Público: {character.is_public}")
            print(f"Criado em: {character.created_at}")
            print(f"Atualizado em: {character.updated_at}")
        else:
            print(f"Personagem '{name}' não encontrado no banco de dados")
            
    except Exception as e:
        print(f"Erro ao consultar personagem: {e}")
    finally:
        await db.close()

if __name__ == "__main__":
    character_name = "The Crusty"
    asyncio.run(check_character(character_name)) 