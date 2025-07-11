#!/usr/bin/env python3
"""
Script de Teste para a Versão Oficial do Auto Loader
====================================================

Testa se a nova versão que usa TaleonCharacterScraper funciona corretamente.
"""

import sys
import os
import asyncio
import logging

# Adicionar o diretório do backend ao path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', 'Backend'))

# Configurar logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


async def test_imports():
    """Testar se os imports funcionam corretamente"""
    try:
        logger.info("🔍 Testando imports...")
        
        # Testar import do aiohttp
        import aiohttp
        logger.info("✅ aiohttp importado com sucesso")
        
        # Testar import do scraper oficial
        from app.services.scraping.taleon import TaleonCharacterScraper
        logger.info("✅ TaleonCharacterScraper importado com sucesso")
        
        return True
        
    except ImportError as e:
        logger.error(f"❌ Erro de import: {e}")
        return False
    except Exception as e:
        logger.error(f"❌ Erro inesperado: {e}")
        return False


async def test_scraper_creation():
    """Testar se consegue criar uma instância do scraper"""
    try:
        logger.info("🔍 Testando criação do scraper...")
        
        from app.services.scraping.taleon import TaleonCharacterScraper
        
        # Criar instância
        scraper = TaleonCharacterScraper()
        logger.info("✅ Instância do scraper criada com sucesso")
        
        # Verificar mundos suportados
        worlds = scraper._get_supported_worlds()
        logger.info(f"✅ Mundos suportados: {worlds}")
        
        return True
        
    except Exception as e:
        logger.error(f"❌ Erro ao criar scraper: {e}")
        return False


async def test_scraper_context():
    """Testar se o scraper funciona com context manager"""
    try:
        logger.info("🔍 Testando context manager do scraper...")
        
        from app.services.scraping.taleon import TaleonCharacterScraper
        
        # Usar context manager
        async with TaleonCharacterScraper() as scraper:
            logger.info("✅ Context manager funcionando")
            
            # Testar configuração de mundos
            world_config = scraper._get_world_config("san")
            logger.info(f"✅ Configuração do mundo San: {world_config.name}")
            
        return True
        
    except Exception as e:
        logger.error(f"❌ Erro no context manager: {e}")
        return False


async def test_simple_scraping():
    """Testar scraping simples de um personagem conhecido"""
    try:
        logger.info("🔍 Testando scraping simples...")
        
        from app.services.scraping.taleon import TaleonCharacterScraper
        
        # Usar context manager
        async with TaleonCharacterScraper() as scraper:
            # Tentar fazer scraping de um personagem conhecido
            result = await scraper.scrape_character("san", "Gates")
            
            if result.success:
                logger.info(f"✅ Scraping bem-sucedido: {result.data.get('name', 'N/A')} - Level {result.data.get('level', 'N/A')}")
                logger.info(f"   Duração: {result.duration_ms}ms")
                return True
            else:
                logger.warning(f"⚠️ Scraping falhou: {result.error_message}")
                return False
                
    except Exception as e:
        logger.error(f"❌ Erro no scraping: {e}")
        return False


async def main():
    """Função principal de teste"""
    logger.info("🚀 Iniciando testes da versão oficial...")
    
    tests = [
        ("Imports", test_imports),
        ("Criação do Scraper", test_scraper_creation),
        ("Context Manager", test_scraper_context),
        ("Scraping Simples", test_simple_scraping),
    ]
    
    passed = 0
    total = len(tests)
    
    for test_name, test_func in tests:
        logger.info(f"\n{'='*50}")
        logger.info(f"🧪 Executando teste: {test_name}")
        logger.info(f"{'='*50}")
        
        try:
            result = await test_func()
            if result:
                logger.info(f"✅ Teste '{test_name}' PASSOU")
                passed += 1
            else:
                logger.error(f"❌ Teste '{test_name}' FALHOU")
        except Exception as e:
            logger.error(f"❌ Teste '{test_name}' FALHOU com exceção: {e}")
    
    logger.info(f"\n{'='*50}")
    logger.info(f"📊 RESULTADO DOS TESTES")
    logger.info(f"{'='*50}")
    logger.info(f"Passou: {passed}/{total}")
    logger.info(f"Taxa de sucesso: {(passed/total)*100:.1f}%")
    
    if passed == total:
        logger.info("🎉 TODOS OS TESTES PASSARAM!")
        return True
    else:
        logger.error("💥 ALGUNS TESTES FALHARAM!")
        return False


if __name__ == "__main__":
    success = asyncio.run(main())
    sys.exit(0 if success else 1) 