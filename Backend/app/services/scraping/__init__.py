"""
Interface Unificada para Web Scraping
=====================================

Fornece uma interface simples e unificada para scraping de personagens
de diferentes servidores de Tibia.
"""

from typing import Dict, Type
import logging

from .base import BaseCharacterScraper, ScrapingResult
from .taleon import TaleonCharacterScraper
from .rubinot import RubinotCharacterScraper

logger = logging.getLogger(__name__)

# Registro de scrapers por servidor
SCRAPERS: Dict[str, Type[BaseCharacterScraper]] = {
    "taleon": TaleonCharacterScraper,
    "rubinot": RubinotCharacterScraper,
    # "rubini": RubiniCharacterScraper,    # Futuro
    # "deus_ot": DeusOTCharacterScraper,   # Futuro  
    # "tibia": TibiaOfficialScraper,       # Futuro
    # "pegasus_ot": PegasusOTScraper,      # Futuro
}


class ScrapingManager:
    """
    Gerenciador principal de scraping que unifica todos os servidores
    """
    
    @staticmethod
    def get_supported_servers() -> list[str]:
        """Retornar lista de servidores suportados"""
        return list(SCRAPERS.keys())
    
    @staticmethod
    def get_server_info(server: str) -> dict:
        """Obter informações sobre um servidor específico"""
        if server.lower() not in SCRAPERS:
            return None
        
        scraper_class = SCRAPERS[server.lower()]
        # Criar instância temporária para obter informações
        temp_scraper = scraper_class()
        
        return {
            "name": temp_scraper.server_name,
            "supported_worlds": temp_scraper.supported_worlds,
            "scraper_class": scraper_class.__name__
        }
    
    @staticmethod
    def is_server_supported(server: str) -> bool:
        """Verificar se um servidor é suportado"""
        return server.lower() in SCRAPERS
    
    @staticmethod
    def is_world_supported(server: str, world: str) -> bool:
        """Verificar se um mundo é suportado por um servidor"""
        server_info = ScrapingManager.get_server_info(server)
        if not server_info:
            return False
        
        return world.lower() in [w.lower() for w in server_info["supported_worlds"]]
    
    @staticmethod
    async def scrape_character(server: str, world: str, character_name: str) -> ScrapingResult:
        """
        Fazer scraping de um personagem automaticamente escolhendo o scraper correto
        
        Args:
            server: Nome do servidor (ex: 'taleon', 'rubini')
            world: Nome do mundo (ex: 'san', 'aura', 'gaia')
            character_name: Nome do personagem
            
        Returns:
            ScrapingResult: Resultado do scraping
        """
        # Validar servidor
        server_lower = server.lower()
        if server_lower not in SCRAPERS:
            supported = ", ".join(SCRAPERS.keys())
            return ScrapingResult(
                success=False,
                error_message=f"Servidor '{server}' não suportado. Servidores disponíveis: {supported}"
            )
        
        # Obter classe do scraper
        scraper_class = SCRAPERS[server_lower]
        
        # Fazer scraping usando o scraper específico
        async with scraper_class() as scraper:
            logger.info(f"🎯 Usando scraper {scraper_class.__name__} para {server}/{world}/{character_name}")
            return await scraper.scrape_character(world, character_name)


# Função de conveniência para compatibilidade com código existente
async def scrape_character_data(server: str, world: str, character_name: str) -> ScrapingResult:
    """
    Função de conveniência para fazer scraping de um personagem
    
    Esta função mantém compatibilidade com o código existente enquanto
    usa a nova arquitetura desacoplada internamente.
    """
    return await ScrapingManager.scrape_character(server, world, character_name)


# Funções utilitárias exportadas
def get_supported_servers() -> list[str]:
    """Obter lista de servidores suportados"""
    return ScrapingManager.get_supported_servers()


def get_server_info(server: str) -> dict:
    """Obter informações de um servidor"""
    return ScrapingManager.get_server_info(server)


def is_server_supported(server: str) -> bool:
    """Verificar se servidor é suportado"""
    return ScrapingManager.is_server_supported(server)


def is_world_supported(server: str, world: str) -> bool:
    """Verificar se mundo é suportado"""
    return ScrapingManager.is_world_supported(server, world)


# Exports principais
__all__ = [
    'ScrapingResult',
    'ScrapingManager', 
    'scrape_character_data',
    'get_supported_servers',
    'get_server_info',
    'is_server_supported',
    'is_world_supported'
] 