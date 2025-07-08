#!/usr/bin/env python3
"""
Teste simples para verificar se o campo 'world' está sendo preenchido corretamente
"""

import asyncio
import sys
import os

# Adicionar o diretório do backend ao path
sys.path.insert(0, '/app')

from app.services.scraping.taleon import TaleonCharacterScraper

async def test_world_field():
    """Testar se o campo world está sendo preenchido"""
    
    print("🔍 Testando campo 'world' no scraper...")
    
    # Criar instância do scraper
    scraper = TaleonCharacterScraper()
    
    # Testar com o mundo 'san'
    world = 'san'
    character_name = 'Sr Burns'
    
    print(f"📋 Parâmetros:")
    print(f"   Mundo: {world}")
    print(f"   Personagem: {character_name}")
    
    try:
        async with scraper:
            # Fazer scraping
            result = await scraper.scrape_character(world, character_name)
            
            if result.success:
                print("✅ Scraping realizado com sucesso!")
                print(f"📊 Dados extraídos:")
                print(f"   Nome: {result.data.get('name')}")
                print(f"   Level: {result.data.get('level')}")
                print(f"   World: '{result.data.get('world')}'")
                print(f"   Vocation: {result.data.get('vocation')}")
                print(f"   Experience: {result.data.get('experience')}")
                
                # Verificar se o world está preenchido
                if result.data.get('world'):
                    print(f"✅ Campo 'world' preenchido corretamente: '{result.data.get('world')}'")
                else:
                    print(f"❌ Campo 'world' está vazio ou None")
                    
            else:
                print(f"❌ Erro no scraping: {result.error_message}")
                
    except Exception as e:
        print(f"❌ Erro durante o teste: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    asyncio.run(test_world_field()) 