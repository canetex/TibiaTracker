"""
Scraper Específico para Servidor Taleon
=======================================

Implementa scraping específico para o servidor Taleon Online.
Cada mundo tem seu próprio subdomínio e configurações específicas.

Estrutura de URLs por mundo:
- San:  https://san.taleon.online/characterprofile.php?name=Gates
- Aura: https://aura.taleon.online/characterprofile.php?name=Galado  
- Gaia: https://gaia.taleon.online/characterprofile.php?name=Wild%20Warior
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
class TaleonWorldConfig:
    """Configuração específica para cada mundo do Taleon"""
    name: str
    subdomain: str
    base_url: str
    request_delay: float = 2.5
    timeout_seconds: int = 30
    max_retries: int = 3
    
    # Configurações específicas de parsing se necessário
    date_format_variations: List[str] = None
    special_selectors: Dict[str, str] = None
    
    def __post_init__(self):
        if self.date_format_variations is None:
            self.date_format_variations = ["%d %b %Y, %H:%M"]
        if self.special_selectors is None:
            self.special_selectors = {}


# Configurações específicas por mundo do Taleon
TALEON_WORLDS = {
    "san": TaleonWorldConfig(
        name="San",
        subdomain="san",
        base_url="https://san.taleon.online",
        request_delay=2.5,  # Mundo principal - delay padrão
        timeout_seconds=30,
        max_retries=3
    ),
    "aura": TaleonWorldConfig(
        name="Aura", 
        subdomain="aura",
        base_url="https://aura.taleon.online",
        request_delay=2.0,  # Mundo secundário - ligeiramente mais rápido
        timeout_seconds=25,
        max_retries=2
    ),
    "gaia": TaleonWorldConfig(
        name="Gaia",
        subdomain="gaia", 
        base_url="https://gaia.taleon.online",
        request_delay=3.0,  # Mundo PvP - mais conservador
        timeout_seconds=35,
        max_retries=4,
        # Exemplo: se Gaia tivesse formatos de data diferentes
        date_format_variations=["%d %b %Y, %H:%M", "%d/%m/%Y %H:%M"],
        # Exemplo: se Gaia tivesse seletores CSS específicos
        special_selectors={
            "level_selector": ".pvp-level",
            "vocation_selector": ".pvp-vocation"
        }
    )
}


class TaleonCharacterScraper(BaseCharacterScraper):
    """
    Scraper específico para o servidor Taleon Online
    
    Cada mundo tem configuração específica definida em TALEON_WORLDS.
    Suporta configurações granulares por mundo incluindo delays e timeouts específicos.
    """
    
    def __init__(self):
        super().__init__()
        self.current_world_config: Optional[TaleonWorldConfig] = None
    
    def _get_server_name(self) -> str:
        """Nome do servidor"""
        return "taleon"
    
    def _get_supported_worlds(self) -> List[str]:
        """Mundos suportados pelo Taleon (baseado nas configurações)"""
        return list(TALEON_WORLDS.keys())
    
    def _get_world_config(self, world: str) -> TaleonWorldConfig:
        """Obter configuração específica do mundo"""
        world_lower = world.lower()
        if world_lower not in TALEON_WORLDS:
            raise ValueError(f"Mundo '{world}' não configurado para Taleon. Mundos disponíveis: {list(TALEON_WORLDS.keys())}")
        return TALEON_WORLDS[world_lower]
    
    def _build_character_url(self, world: str, character_name: str) -> str:
        """Construir URL específica usando configuração do mundo"""
        world_config = self._get_world_config(world)
        self.current_world_config = world_config  # Armazenar para uso posterior
        
        encoded_name = quote(character_name, safe='')
        url = f"{world_config.base_url}/characterprofile.php?name={encoded_name}"
        
        logger.debug(f"[TALEON-{world_config.name.upper()}] URL construída: {url}")
        return url
    
    def _get_request_delay(self) -> float:
        """Delay específico baseado na configuração do mundo atual"""
        if self.current_world_config:
            return self.current_world_config.request_delay
        return 2.5  # Fallback padrão
    
    def _parse_taleon_date(self, date_text: str) -> datetime:
        """Parser específico para datas do Taleon com suporte a configurações por mundo"""
        if not date_text or date_text.lower() in ['never', 'nunca', '-', '']:
            return None
        
        world_name = self.current_world_config.name if self.current_world_config else "UNKNOWN"
        
        try:
            # Formato do Taleon: "27 Jun 2025, 19:33 → 27 Jun 2025, 20:17"
            # Pegar apenas a primeira data (login)
            if '→' in date_text:
                date_text = date_text.split('→')[0].strip()
            
            # Formato esperado: "27 Jun 2025, 19:33"
            clean_date = date_text.strip()
            
            # Usar formatos específicos do mundo se configurado
            date_formats = ["%d %b %Y, %H:%M"]  # Formato padrão do Taleon
            if self.current_world_config and self.current_world_config.date_format_variations:
                date_formats = self.current_world_config.date_format_variations + date_formats
            
            # Tentar parsear com formatos específicos do mundo
            for fmt in date_formats:
                try:
                    return datetime.strptime(clean_date, fmt)
                except ValueError:
                    continue
            
            # Fallback para método base se nenhum formato específico funcionou
            return self._parse_date(date_text)
                
        except Exception as e:
            logger.warning(f"[TALEON-{world_name}] Erro ao parsear data '{date_text}': {e}")
            return None
    
    def _extract_outfit_image_url(self, soup: BeautifulSoup) -> str:
        """Extrair URL da imagem do outfit do Taleon"""
        world_name = self.current_world_config.name if self.current_world_config else "UNKNOWN"
        
        try:
            # Procurar por imagem do outfit no padrão outfits.taleon.online
            outfit_img = soup.find('img', src=re.compile(r'outfits\.taleon\.online/outfit\.php'))
            if outfit_img and outfit_img.get('src'):
                logger.debug(f"[TALEON-{world_name}] Outfit image encontrada: {outfit_img['src']}")
                return outfit_img['src']
            return None
        except Exception as e:
            logger.warning(f"[TALEON-{world_name}] Erro ao extrair URL do outfit: {e}")
            return None
    
    def _extract_experience_from_history(self, soup: BeautifulSoup) -> int:
        """Extrair experiência total do histórico de experiência"""
        world_name = self.current_world_config.name if self.current_world_config else "UNKNOWN"
        
        try:
            # Buscar seção "experience history" para calcular experiência total
            exp_section = soup.find(text=re.compile(r'experience history', re.IGNORECASE))
            if exp_section:
                exp_table = exp_section.find_next('table')
                if exp_table:
                    exp_rows = exp_table.find_all('tr')
                    total_exp = 0
                    for row in exp_rows[1:]:  # Pular header
                        cells = row.find_all(['td', 'th'])
                        if len(cells) >= 2:
                            exp_text = cells[1].get_text().strip()
                            if 'no experience gained' not in exp_text.lower():
                                exp_value = self._extract_number(exp_text)
                                if exp_value > 0:
                                    total_exp += exp_value
                    
                    logger.debug(f"[TALEON-{world_name}] Experiência total calculada: {total_exp:,}")
                    return total_exp if total_exp > 0 else 0
            return 0
        except Exception as e:
            logger.warning(f"[TALEON-{world_name}] Erro ao extrair experiência do histórico: {e}")
            return 0
    
    def _count_deaths_from_list(self, soup: BeautifulSoup) -> int:
        """Contar mortes da death list"""
        world_name = self.current_world_config.name if self.current_world_config else "UNKNOWN"
        
        try:
            # Buscar seção "death list" para contar mortes
            death_section = soup.find(text=re.compile(r'death list', re.IGNORECASE))
            if death_section:
                death_table = death_section.find_next('table')
                if death_table:
                    death_rows = death_table.find_all('tr')
                    death_count = 0
                    for row in death_rows[1:]:  # Pular header
                        cells = row.find_all(['td', 'th'])
                        if len(cells) >= 1:
                            death_text = cells[0].get_text().strip()
                            if death_text and 'no victims' not in death_text.lower():
                                death_count += 1
                    logger.debug(f"[TALEON-{world_name}] Mortes contadas: {death_count}")
                    return death_count
            return 0
        except Exception as e:
            logger.warning(f"[TALEON-{world_name}] Erro ao contar mortes: {e}")
            return 0
    
    async def _extract_character_data(self, html: str, url: str) -> Dict[str, Any]:
        """Extrair dados específicos do HTML do Taleon"""
        soup = BeautifulSoup(html, 'lxml')
        
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
            # Extrair URL da imagem do outfit
            data['outfit_image_url'] = self._extract_outfit_image_url(soup)
            
            # Procurar pela tabela principal com informações do personagem
            # A estrutura do Taleon usa tabelas com duas colunas: label | valor
            tables = soup.find_all('table')
            
            for table in tables:
                rows = table.find_all('tr')
                for row in rows:
                    cells = row.find_all(['td', 'th'])
                    if len(cells) >= 2:
                        # Primeira célula é o label, segunda é o valor
                        label = cells[0].get_text().strip().lower().replace(':', '')
                        value_cell = cells[1]
                        value = value_cell.get_text().strip()
                        
                        # Mapear campos baseado na estrutura real do Taleon
                        if 'name' in label:
                            # Nome pode estar na segunda célula, extrair apenas o texto
                            data['name'] = re.sub(r'\s+', ' ', value).strip()
                        
                        elif 'level' in label:
                            data['level'] = self._extract_number(value)
                        
                        elif 'vocation' in label:
                            data['vocation'] = value if value not in ['-', 'None', ''] else 'None'
                        
                        elif 'achievement points' in label:
                            data['achievement_points'] = self._extract_number(value) or None
                        
                        elif 'bosstiary points' in label:
                            data['bosstiary_points'] = self._extract_number(value) or None
                        
                        elif 'charm points' in label:
                            data['charm_points'] = self._extract_number(value) or None
                        
                        elif 'last login' in label:
                            data['last_login'] = self._parse_taleon_date(value)
                            # Se tem login recente, pode estar online
                            if data['last_login']:
                                # Considerar online se último login foi nas últimas 2 horas
                                time_diff = datetime.now() - data['last_login']
                                data['is_online'] = time_diff.total_seconds() < 7200
                        
                        elif 'residence' in label:
                            data['residence'] = value if value not in ['-', 'None', ''] else ''
                        
                        elif 'house' in label and value not in ['-', 'None', '', 'No house']:
                            data['house'] = value
                        
                        elif 'guild' in label and 'rank' not in label and value not in ['-', 'None', '']:
                            data['guild'] = value
                        
                        elif 'guild rank' in label and value not in ['-', 'None', '']:
                            data['guild_rank'] = value
            
            # Se não encontrou o nome na tabela, tentar extrair do título da página
            if not data['name']:
                title = soup.find('title')
                if title:
                    title_text = title.get_text()
                    # Procurar padrão "Character profile of NOME"
                    match = re.search(r'character profile of (.+)', title_text, re.IGNORECASE)
                    if match:
                        data['name'] = match.group(1).strip()
                
                # Procurar por headers que possam conter o nome
                for tag in ['h1', 'h2', 'h3']:
                    header = soup.find(tag)
                    if header and 'character profile' in header.get_text().lower():
                        header_text = header.get_text()
                        match = re.search(r'character profile of (.+)', header_text, re.IGNORECASE)
                        if match:
                            data['name'] = match.group(1).strip()
                            break
            
            # Extrair experiência do histórico
            data['experience'] = self._extract_experience_from_history(soup)
            
            # Contar mortes da death list
            data['deaths'] = self._count_deaths_from_list(soup)
            
            # Validação final dos dados extraídos
            world_name = self.current_world_config.name if self.current_world_config else "UNKNOWN"
            
            if not data['name']:
                raise ValueError(f"[TALEON-{world_name}] Nome do personagem não encontrado")
            
            if data['level'] < 1:
                raise ValueError(f"[TALEON-{world_name}] Level inválido encontrado: {data['level']}")
            
            logger.info(f"✅ [TALEON-{world_name}] Dados extraídos - {data['name']}: Level {data['level']}, Vocation {data['vocation']}")
            logger.debug(f"[TALEON-{world_name}] Dados completos: {data}")
            
        except Exception as e:
            world_name = self.current_world_config.name if self.current_world_config else "UNKNOWN"
            logger.error(f"❌ [TALEON-{world_name}] Erro ao extrair dados do HTML: {e}")
            raise
        
        return data
    
    def get_world_details(self) -> Dict[str, Any]:
        """Obter detalhes de todos os mundos configurados do Taleon"""
        world_details = {}
        for world_key, config in TALEON_WORLDS.items():
            world_details[world_key] = {
                "name": config.name,
                "subdomain": config.subdomain,
                "base_url": config.base_url,
                "request_delay": config.request_delay,
                "timeout_seconds": config.timeout_seconds,
                "max_retries": config.max_retries,
                "example_url": f"{config.base_url}/characterprofile.php?name=ExampleCharacter"
            }
        return world_details
    
    def get_world_config_info(self, world: str) -> Dict[str, Any]:
        """Obter informações de configuração de um mundo específico"""
        try:
            config = self._get_world_config(world)
            return {
                "world": world,
                "name": config.name,
                "subdomain": config.subdomain,
                "base_url": config.base_url,
                "request_delay": config.request_delay,
                "timeout_seconds": config.timeout_seconds,
                "max_retries": config.max_retries,
                "date_formats": config.date_format_variations,
                "special_selectors": config.special_selectors,
                "example_url": f"{config.base_url}/characterprofile.php?name=ExampleCharacter"
            }
        except ValueError as e:
            return {"error": str(e)}
    
    def _is_character_not_found(self, html: str) -> bool:
        """Verificações específicas do Taleon para personagem não encontrado"""
        # Usar método base + verificações específicas do Taleon
        if super()._is_character_not_found(html):
            return True
        
        # Verificações específicas do Taleon
        taleon_not_found_phrases = [
            'character profile of', # Se não tem esse padrão, provavelmente não encontrou
            'name:', # Se não tem campo name, não encontrou
        ]
        
        html_lower = html.lower()
        
        # Se não tem os elementos básicos esperados, consideramos não encontrado
        has_expected_elements = any(phrase in html_lower for phrase in taleon_not_found_phrases)
        return not has_expected_elements 