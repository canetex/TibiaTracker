"""
TEMPLATE: Scraper para Servidor Rubini
======================================

Este é um template/exemplo de como implementar um novo scraper
para um servidor específico usando a arquitetura desacoplada.

Para ativar este scraper:
1. Implemente todos os métodos abstratos
2. Teste o scraping 
3. Adicione a classe no __init__.py
4. Remove "_template" do nome do arquivo
"""

import re
from typing import Dict, Any, List, Optional
from datetime import datetime
from urllib.parse import quote
from bs4 import BeautifulSoup
import logging
from dataclasses import dataclass

from .base import BaseCharacterScraper

logger = logging.getLogger(__name__)


@dataclass
class RubiniWorldConfig:
    """Configuração específica para cada mundo do Rubini"""
    name: str
    subdomain: str
    base_url: str
    request_delay: float = 3.0
    timeout_seconds: int = 30
    max_retries: int = 3
    
    # Configurações específicas de parsing se necessário
    date_format_variations: List[str] = None
    special_selectors: Dict[str, str] = None
    
    def __post_init__(self):
        if self.date_format_variations is None:
            # TODO: Descobrir formatos de data específicos do Rubini
            self.date_format_variations = ["%d/%m/%Y %H:%M:%S"]
        if self.special_selectors is None:
            self.special_selectors = {}


# TODO: Configurar mundos reais do Rubini
RUBINI_WORLDS = {
    "world1": RubiniWorldConfig(
        name="World1",
        subdomain="world1",
        base_url="https://world1.rubini.com",  # TODO: URL real
        request_delay=3.0,
        timeout_seconds=30,
        max_retries=3
    ),
    "world2": RubiniWorldConfig(
        name="World2",
        subdomain="world2", 
        base_url="https://world2.rubini.com",  # TODO: URL real
        request_delay=2.5,  # Exemplo: mundo mais rápido
        timeout_seconds=25,
        max_retries=2
    )
}


class RubiniCharacterScraper(BaseCharacterScraper):
    """
    Scraper para o servidor Rubini
    
    Cada mundo tem configuração específica definida em RUBINI_WORLDS.
    TODO: Adaptar para estrutura real do site do Rubini
    """
    
    def __init__(self):
        super().__init__()
        self.current_world_config: Optional[RubiniWorldConfig] = None
    
    def _get_server_name(self) -> str:
        """Nome do servidor"""
        return "rubini"
    
    def _get_supported_worlds(self) -> List[str]:
        """Mundos suportados pelo Rubini (baseado nas configurações)"""
        return list(RUBINI_WORLDS.keys())
    
    def _get_world_config(self, world: str) -> RubiniWorldConfig:
        """Obter configuração específica do mundo"""
        world_lower = world.lower()
        if world_lower not in RUBINI_WORLDS:
            raise ValueError(f"Mundo '{world}' não configurado para Rubini. Mundos disponíveis: {list(RUBINI_WORLDS.keys())}")
        return RUBINI_WORLDS[world_lower]
    
    def _build_character_url(self, world: str, character_name: str) -> str:
        """Construir URL específica usando configuração do mundo"""
        world_config = self._get_world_config(world)
        self.current_world_config = world_config  # Armazenar para uso posterior
        
        # TODO: Descobrir estrutura real das URLs do Rubini
        encoded_name = quote(character_name, safe='')
        url = f"{world_config.base_url}/character/{encoded_name}"  # Exemplo hipotético
        
        logger.debug(f"[RUBINI-{world_config.name.upper()}] URL construída: {url}")
        return url
    
    def _get_request_delay(self) -> float:
        """Delay específico baseado na configuração do mundo atual"""
        if self.current_world_config:
            return self.current_world_config.request_delay
        return 3.0  # Fallback padrão
    
    async def _extract_character_data(self, html: str, url: str) -> Dict[str, Any]:
        """
        Extrair dados específicos do HTML do Rubini
        
        TODO: Implementar parsing específico para estrutura do Rubini
        """
        soup = BeautifulSoup(html, 'lxml')
        
        # Estrutura padrão de retorno
        data = {
            'name': '',
            'level': 0,
            'vocation': 'None',
            'residence': '',
            'house': None,
            'guild': None,
            'guild_rank': None,
            'experience': 0,
            'deaths': 0,
            'charm_points': None,
            'bosstiary_points': None,
            'achievement_points': None,
            'is_online': False,
            'last_login': None,
            'profile_url': url,
            'outfit_image_url': None
        }
        
        try:
            # TODO: Implementar lógica específica de extração do Rubini
            # 
            # Exemplos de como fazer:
            #
            # 1. Extrair nome
            # name_element = soup.find('h1', class_='character-name')
            # if name_element:
            #     data['name'] = name_element.get_text().strip()
            #
            # 2. Extrair level
            # level_element = soup.find('span', class_='level')
            # if level_element:
            #     data['level'] = self._extract_number(level_element.get_text())
            #
            # 3. Procurar por tabelas estruturadas
            # tables = soup.find_all('table', class_='character-info')
            # for table in tables:
            #     rows = table.find_all('tr')
            #     for row in rows:
            #         cells = row.find_all(['td', 'th'])
            #         if len(cells) >= 2:
            #             label = cells[0].get_text().strip().lower()
            #             value = cells[1].get_text().strip()
            #             # Mapear campos...
            
            # PLACEHOLDER: Implementação básica para evitar erros
            # Remove this when implementing real extraction
            title = soup.find('title')
            if title and 'character' in title.get_text().lower():
                # Assume que a página foi carregada corretamente
                data['name'] = "Template Character"  # Placeholder
                data['level'] = 1  # Placeholder
                data['vocation'] = "Knight"  # Placeholder
            else:
                raise ValueError("[RUBINI] Página de personagem não reconhecida")
            
            logger.info(f"✅ [RUBINI] Dados extraídos - {data['name']}: Level {data['level']}")
            
        except Exception as e:
            logger.error(f"❌ [RUBINI] Erro ao extrair dados do HTML: {e}")
            raise
        
        return data
    
    def _is_character_not_found(self, html: str) -> bool:
        """Verificações específicas do Rubini para personagem não encontrado"""
        # Usar método base + verificações específicas do Rubini
        if super()._is_character_not_found(html):
            return True
        
        # TODO: Adicionar verificações específicas do Rubini
        # Exemplo:
        # rubini_not_found_phrases = [
        #     'character not found',
        #     'invalid character name',
        # ]
        # html_lower = html.lower()
        # return any(phrase in html_lower for phrase in rubini_not_found_phrases)
        
        return False


# INSTRUÇÕES PARA ATIVAÇÃO:
#
# 1. Renomeie este arquivo de "rubini_template.py" para "rubini.py"
# 2. Implemente todos os TODOs acima
# 3. Teste o scraping manualmente
# 4. No arquivo __init__.py, descomente a linha:
#    # "rubini": RubiniCharacterScraper,
# 5. Adicione o import:
#    from .rubini import RubiniCharacterScraper 