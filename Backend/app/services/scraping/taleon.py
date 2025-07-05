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
import json
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
            logger.warning(f"[TALEON-{self.current_world_config.name if self.current_world_config else 'UNKNOWN'}] Erro ao parsear data '{date_text}': {e}")
            return None
    
    def _extract_outfit_image_url(self, soup: BeautifulSoup) -> str:
        """Extrair URL da imagem do outfit do Taleon"""
        
        try:
            # Procurar por imagem do outfit no padrão outfits.taleon.online
            outfit_img = soup.find('img', src=re.compile(r'outfits\.taleon\.online/outfit\.php'))
            if outfit_img and outfit_img.get('src'):
                logger.debug(f"[TALEON-{self.current_world_config.name if self.current_world_config else 'UNKNOWN'}] Outfit image encontrada: {outfit_img['src']}")
                return outfit_img['src']
            return None
        except Exception as e:
            logger.warning(f"[TALEON-{self.current_world_config.name if self.current_world_config else 'UNKNOWN'}] Erro ao extrair URL do outfit: {e}")
            return None
    
    def _extract_experience_history_data(self, soup: BeautifulSoup) -> List[Dict[str, Any]]:
        """Extrair dados históricos de experiência de vários dias"""
        history_data = []
        
        try:
            logger.info(f"[TALEON-{self.current_world_config.name if self.current_world_config else 'UNKNOWN'}] Iniciando extração de histórico de experiência...")
            
            # Debug: Verificar todo o texto da página para encontrar padrões
            page_text = soup.get_text().lower()
            logger.debug(f"[TALEON-{self.current_world_config.name if self.current_world_config else 'UNKNOWN'}] Verificando texto da página...")
            
            # Buscar diferentes variações do texto "experience history"
            possible_phrases = [
                'experience history',
                'experience gained',
                'experience log',
                'experience tracking',
                'experience summary'
            ]
            
            found_phrase = None
            for phrase in possible_phrases:
                if phrase in page_text:
                    found_phrase = phrase
                    logger.info(f"[TALEON-{self.current_world_config.name if self.current_world_config else 'UNKNOWN'}] ✅ Encontrada frase: '{phrase}'")
                    break
            
            if not found_phrase:
                logger.warning(f"[TALEON-{self.current_world_config.name if self.current_world_config else 'UNKNOWN'}] ❌ Nenhuma das frases de experiência encontrada na página")
                logger.debug(f"[TALEON-{self.current_world_config.name if self.current_world_config else 'UNKNOWN'}] Frases procuradas: {possible_phrases}")
                return []
            
            # Buscar seção "experience history" para extrair histórico completo
            exp_section = soup.find(text=re.compile(r'experience history', re.IGNORECASE))
            if not exp_section:
                logger.warning(f"[TALEON-{self.current_world_config.name if self.current_world_config else 'UNKNOWN'}] Seção 'experience history' não encontrada")
                return []
            
            logger.info(f"[TALEON-{self.current_world_config.name if self.current_world_config else 'UNKNOWN'}] Seção 'experience history' encontrada")
            
            exp_table = exp_section.find_next('table')
            if not exp_table:
                logger.warning(f"[TALEON-{self.current_world_config.name if self.current_world_config else 'UNKNOWN'}] Tabela de experiência não encontrada após a seção")
                return []
            
            logger.info(f"[TALEON-{self.current_world_config.name if self.current_world_config else 'UNKNOWN'}] Tabela de experiência encontrada")
            
            exp_rows = exp_table.find_all('tr')
            logger.info(f"[TALEON-{self.current_world_config.name if self.current_world_config else 'UNKNOWN'}] Encontradas {len(exp_rows)} linhas na tabela de experiência")
            
            for i, row in enumerate(exp_rows[1:], 1):  # Pular header, começar contagem em 1
                cells = row.find_all(['td', 'th'])
                logger.debug(f"[TALEON-{self.current_world_config.name if self.current_world_config else 'UNKNOWN'}] Linha {i}: {len(cells)} células encontradas")
                
                if len(cells) >= 2:
                    date_text = cells[0].get_text().strip()
                    exp_text = cells[1].get_text().strip()
                    
                    logger.debug(f"[TALEON-{self.current_world_config.name if self.current_world_config else 'UNKNOWN'}] Linha {i}: Data='{date_text}', Exp='{exp_text}'")
                    
                    # Processar diferentes tipos de data
                    experience_gained = 0
                    snapshot_date = None
                    
                    if 'no experience gained' in exp_text.lower():
                        experience_gained = 0
                        logger.debug(f"[TALEON-{self.current_world_config.name if self.current_world_config else 'UNKNOWN'}] Linha {i}: Sem experiência ganha")
                    else:
                        # Extrair número e garantir que seja positivo
                        raw_experience = self._extract_number(exp_text)
                        experience_gained = max(0, raw_experience)  # Garantir que não seja negativo
                        
                        if raw_experience != experience_gained:
                            logger.warning(f"[TALEON-{self.current_world_config.name if self.current_world_config else 'UNKNOWN'}] Linha {i}: Experiência negativa corrigida: {raw_experience} → {experience_gained}")
                        
                        logger.debug(f"[TALEON-{self.current_world_config.name if self.current_world_config else 'UNKNOWN'}] Linha {i}: Experiência extraída: {experience_gained:,}")
                    
                    # Converter data
                    if date_text.lower() == 'today':
                        from datetime import datetime
                        snapshot_date = datetime.now().date()
                        logger.debug(f"[TALEON-{self.current_world_config.name if self.current_world_config else 'UNKNOWN'}] Linha {i}: Data 'today' convertida para {snapshot_date}")
                    elif date_text.lower() == 'yesterday':
                        from datetime import datetime, timedelta
                        snapshot_date = (datetime.now() - timedelta(days=1)).date()
                        logger.debug(f"[TALEON-{self.current_world_config.name if self.current_world_config else 'UNKNOWN'}] Linha {i}: Data 'yesterday' convertida para {snapshot_date}")
                    else:
                        # Tentar parsear data no formato DD/MM/YYYY
                        try:
                            from datetime import datetime
                            snapshot_date = datetime.strptime(date_text, '%d/%m/%Y').date()
                            logger.debug(f"[TALEON-{self.current_world_config.name if self.current_world_config else 'UNKNOWN'}] Linha {i}: Data '{date_text}' convertida para {snapshot_date}")
                        except ValueError:
                            logger.warning(f"[TALEON-{self.current_world_config.name if self.current_world_config else 'UNKNOWN'}] Linha {i}: Não foi possível parsear data: {date_text}")
                            continue
                    
                    if snapshot_date and experience_gained >= 0:
                        history_data.append({
                            'date': snapshot_date,
                            'experience_gained': experience_gained,
                            'date_text': date_text
                        })
                        logger.info(f"[TALEON-{self.current_world_config.name if self.current_world_config else 'UNKNOWN'}] ✅ Linha {i}: Adicionado histórico - {date_text} = {experience_gained:,}")
                    else:
                        logger.warning(f"[TALEON-{self.current_world_config.name if self.current_world_config else 'UNKNOWN'}] Linha {i}: Dados inválidos - data={snapshot_date}, exp={experience_gained}")
                else:
                    logger.warning(f"[TALEON-{self.current_world_config.name if self.current_world_config else 'UNKNOWN'}] Linha {i}: Células insuficientes ({len(cells)})")
            
            logger.info(f"[TALEON-{self.current_world_config.name if self.current_world_config else 'UNKNOWN'}] ✅ Extração concluída: {len(history_data)} registros de histórico de experiência")
            
            # Log detalhado de todos os registros extraídos
            for i, entry in enumerate(history_data, 1):
                logger.debug(f"[TALEON-{self.current_world_config.name if self.current_world_config else 'UNKNOWN'}] Registro {i}: {entry['date_text']} ({entry['date']}) = {entry['experience_gained']:,}")
            
            return history_data
            
        except Exception as e:
            logger.error(f"[TALEON-{self.current_world_config.name if self.current_world_config else 'UNKNOWN'}] ❌ Erro ao extrair histórico de experiência: {e}", exc_info=True)
            return []

    def _extract_total_experience(self, soup: BeautifulSoup) -> int:
        """Extrair experiência total atual do personagem"""
        
        try:
            # Procurar por experiência total na página
            # Pode estar em diferentes formatos: "Experience: 8,581,520" ou "8,581,520"
            experience_patterns = [
                r'experience[:\s]*([\d,]+)',
                r'exp[:\s]*([\d,]+)',
                r'([\d,]+)\s*experience',
                r'([\d,]+)\s*exp'
            ]
            
            page_text = soup.get_text().lower()
            
            for pattern in experience_patterns:
                matches = re.findall(pattern, page_text, re.IGNORECASE)
                for match in matches:
                    # Limpar e converter para número
                    exp_str = match.replace(',', '').strip()
                    if exp_str.isdigit():
                        exp_value = int(exp_str)
                        if exp_value > 1000000:  # Experiência total deve ser alta
                            logger.debug(f"[TALEON-{self.current_world_config.name if self.current_world_config else 'UNKNOWN'}] Experiência total encontrada: {exp_value:,}")
                            return exp_value
            
            # Procurar em tabelas específicas
            tables = soup.find_all('table')
            for table in tables:
                rows = table.find_all('tr')
                for row in rows:
                    cells = row.find_all(['td', 'th'])
                    if len(cells) >= 2:
                        label = cells[0].get_text().strip().lower()
                        value = cells[1].get_text().strip()
                        
                        if 'experience' in label or 'exp' in label:
                            exp_value = self._extract_number(value)
                            if exp_value > 1000000:  # Experiência total deve ser alta
                                logger.debug(f"[TALEON-{self.current_world_config.name if self.current_world_config else 'UNKNOWN'}] Experiência total encontrada na tabela: {exp_value:,}")
                                return exp_value
            
            logger.warning(f"[TALEON-{self.current_world_config.name if self.current_world_config else 'UNKNOWN'}] Experiência total não encontrada")
            return 0
            
        except Exception as e:
            logger.error(f"[TALEON-{self.current_world_config.name if self.current_world_config else 'UNKNOWN'}] Erro ao extrair experiência total: {e}")
            return 0
    
    def _extract_experience_from_history(self, soup: BeautifulSoup) -> int:
        """Extrair experiência ganha hoje do histórico (mantém compatibilidade)"""
        
        history_data = self._extract_experience_history_data(soup)
        
        # Retornar experiência de hoje para compatibilidade
        for entry in history_data:
            if entry['date_text'].lower() == 'today':
                logger.debug(f"[TALEON-{self.current_world_config.name if self.current_world_config else 'UNKNOWN'}] Experiência ganha hoje: {entry['experience_gained']:,}")
                return entry['experience_gained']
        
        logger.warning(f"[TALEON-{self.current_world_config.name if self.current_world_config else 'UNKNOWN'}] Não foi possível encontrar experiência de hoje no histórico")
        return 0
    
    def _count_deaths_from_list(self, soup: BeautifulSoup) -> int:
        """Contar mortes da death list"""
        
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
                    logger.debug(f"[TALEON-{self.current_world_config.name if self.current_world_config else 'UNKNOWN'}] Mortes contadas: {death_count}")
                    return death_count
            return 0
        except Exception as e:
            logger.warning(f"[TALEON-{self.current_world_config.name if self.current_world_config else 'UNKNOWN'}] Erro ao contar mortes: {e}")
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
            'guild_url': None,
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
            logger.info(f"[TALEON] Iniciando scraping do personagem na URL: {url}")
            # Extrair URL da imagem do outfit
            outfit_url = self._extract_outfit_image_url(soup)
            data['outfit_image_url'] = outfit_url
            
            # Processar outfit se disponível
            if outfit_url:
                try:
                    from app.services.outfit_service import OutfitService
                    outfit_service = OutfitService()
                    # Usar o mundo atual da configuração
                    current_world = self.current_world_config.name if self.current_world_config else 'UNKNOWN'
                    outfit_data = await outfit_service.process_outfit(
                        outfit_url, data['name'], self._get_server_name(), current_world
                    )
                    if outfit_data:
                        data['outfit_data'] = json.dumps(outfit_data)
                        # Usar URL local se disponível
                        if 'local_url' in outfit_data:
                            data['outfit_image_url'] = outfit_data['local_url']
                except Exception as e:
                    logger.warning(f"[TALEON-{self.current_world_config.name if self.current_world_config else 'UNKNOWN'}] Erro ao processar outfit: {e}")
            
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
                            data['name'] = re.sub(r'\s+', ' ', value).strip()
                            logger.debug(f"[TALEON] Nome extraído: {data['name']}")
                        
                        elif 'level' in label:
                            # Extrair level corretamente - pode estar em formato "Level: 1995"
                            level_value = self._extract_number(value)
                            if level_value > 0:
                                data['level'] = level_value
                                logger.debug(f"[TALEON] Level extraído: {data['level']}")
                            else:
                                # Tentar extrair de outras formas
                                level_match = re.search(r'(\d+)', value)
                                if level_match:
                                    data['level'] = int(level_match.group(1))
                        
                        elif 'vocation' in label:
                            data['vocation'] = value if value not in ['-', 'None', ''] else 'None'
                            logger.debug(f"[TALEON] Vocation extraída: {data['vocation']}")
                        
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
                            logger.info(f"[TALEON] Guild encontrada por label: {value}")
                        
                        elif 'guild rank' in label and value not in ['-', 'None', '']:
                            data['guild_rank'] = value
                            logger.info(f"[TALEON] Guild rank encontrado: {value}")
                        
                        # Verificar se é uma linha de guild (estrutura específica do Taleon)
                        elif ('leader of' in label.lower() or 
                              'vice-leader of' in label.lower() or 
                              'member of' in label.lower() or
                              'boss of' in label.lower() or
                              'general of' in label.lower()):
                            # Procurar link da guild na célula
                            guild_link = value_cell.find('a')
                            if guild_link:
                                guild_name = guild_link.get_text().strip()
                                guild_url = guild_link.get('href')
                                if guild_name and guild_name not in ['-', 'None', '']:
                                    data['guild'] = guild_name
                                    data['guild_url'] = guild_url
                                    logger.info(f"[TALEON] Guild encontrada via link: {guild_name} ({guild_url})")
                            else:
                                # Se não tem link, usar o texto da célula
                                if value and value not in ['-', 'None', '']:
                                    data['guild'] = value
                                    logger.info(f"[TALEON] Guild encontrada via texto: {value}")
            
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
            
            # Extrair experiência total atual (não apenas a ganha hoje)
            data['experience'] = self._extract_total_experience(soup)
            
            # Se não conseguiu extrair experiência total, tentar do histórico
            if data['experience'] == 0:
                data['experience'] = self._extract_experience_from_history(soup)
            
            # Extrair histórico completo de experiência
            data['experience_history'] = self._extract_experience_history_data(soup)
            
            # Contar mortes da death list
            data['deaths'] = self._count_deaths_from_list(soup)
            
            # Busca adicional por links de guild se não foi encontrada na tabela
            if not data['guild']:
                logger.warning(f"[TALEON] Nenhuma guild encontrada na tabela. Buscando links de guild na página...")
                # Procurar por todos os links que seguem o padrão guilds.php
                guild_links = soup.find_all('a', href=re.compile(r'guilds\.php\?name='))
                for link in guild_links:
                    guild_name = link.get_text().strip()
                    guild_url = link.get('href')
                    if guild_name and guild_name not in ['-', 'None', '']:
                        data['guild'] = guild_name
                        data['guild_url'] = guild_url
                        logger.info(f"[TALEON] Guild encontrada via busca de links: {guild_name} ({guild_url})")
                        break
                if not data['guild']:
                    logger.warning(f"[TALEON] Nenhuma guild encontrada nem por busca de links para {data.get('name')}")
            
            # Validação final dos dados extraídos
            
            if not data['name']:
                raise ValueError(f"[TALEON-{self.current_world_config.name if self.current_world_config else 'UNKNOWN'}] Nome do personagem não encontrado")
            
            if data['level'] < 1:
                raise ValueError(f"[TALEON-{self.current_world_config.name if self.current_world_config else 'UNKNOWN'}] Level inválido encontrado: {data['level']}")
            
            logger.info(f"✅ [TALEON-{self.current_world_config.name if self.current_world_config else 'UNKNOWN'}] Dados extraídos - {data['name']}: Level {data['level']}, Vocation {data['vocation']}")
            logger.debug(f"[TALEON-{self.current_world_config.name if self.current_world_config else 'UNKNOWN'}] Dados completos: {data}")
            logger.info(f"[TALEON] Dados finais extraídos: {data}")
        except Exception as e:
            logger.error(f"❌ [TALEON] Erro ao extrair dados do HTML: {e}")
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
