#!/usr/bin/env python3
"""
Script para testar o scraping do Gates especificamente
"""

import asyncio
import sys
import os
from datetime import datetime

# Adicionar o diretório do backend ao path
sys.path.append(os.path.join(os.path.dirname(__file__), 'Backend'))

from app.services.scraping.taleon import TaleonCharacterScraper

async def test_gates_scraping():
    """Testar scraping do Gates"""
    
    print("🔍 Testando scraping do Gates...")
    
    async with TaleonCharacterScraper() as scraper:
        try:
            # Fazer scraping do Gates
            print("📡 Fazendo scraping do Gates (taleon/san)...")
            
            scraping_result = await scraper.scrape_character("san", "Gates")
            
            if not scraping_result.success:
                print(f"❌ Erro no scraping: {scraping_result.error_message}")
                return
            
            character_data = scraping_result.data
            
            print(f"\n✅ Dados extraídos do Gates:")
            print(f"   Nome: {character_data.get('name', 'N/A')}")
            print(f"   Level: {character_data.get('level', 'N/A')}")
            print(f"   Vocation: {character_data.get('vocation', 'N/A')}")
            print(f"   Experience: {character_data.get('experience', 0):,}")
            print(f"   Guild: {character_data.get('guild', 'N/A')}")
            print(f"   Residence: {character_data.get('residence', 'N/A')}")
            print(f"   Last Login: {character_data.get('last_login', 'N/A')}")
            print(f"   Is Online: {character_data.get('is_online', False)}")
            
            # Verificar se o level está correto
            expected_level = 1225  # Baseado nos snapshots
            actual_level = character_data.get('level', 0)
            
            print(f"\n🔍 Análise do Level:")
            print(f"   Level esperado (baseado nos snapshots): {expected_level}")
            print(f"   Level extraído do site: {actual_level}")
            
            if actual_level == expected_level:
                print(f"   ✅ Level está correto!")
            elif actual_level > expected_level:
                print(f"   🎉 Level aumentou! Gates subiu de {expected_level} para {actual_level}")
            else:
                print(f"   ⚠️  Level está menor que o esperado. Possível problema no scraping.")
            
            # Verificar experiência
            experience = character_data.get('experience', 0)
            print(f"\n💰 Análise da Experiência:")
            print(f"   Experiência total: {experience:,}")
            
            if experience > 0:
                print(f"   ✅ Experiência extraída corretamente")
            else:
                print(f"   ❌ Problema na extração da experiência")
            
            # Verificar se há dados de histórico
            history = character_data.get('experience_history', [])
            print(f"\n📊 Histórico de Experiência:")
            print(f"   Entradas no histórico: {len(history)}")
            
            if history:
                print(f"   Últimas 3 entradas:")
                for i, entry in enumerate(history[-3:], 1):
                    print(f"   {i}. {entry}")
            
            print(f"\n✅ Teste concluído!")
            
        except Exception as e:
            print(f"❌ Erro no teste: {e}")
            import traceback
            traceback.print_exc()

if __name__ == "__main__":
    asyncio.run(test_gates_scraping()) 