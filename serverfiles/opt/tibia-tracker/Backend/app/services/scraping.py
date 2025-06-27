"""
Serviço de Web Scraping para Tibia
==================================

Módulo responsável por extrair dados de personagens dos sites dos servidores.
Implementa scraping robusto com tratamento de erros e retry automático.
"""

import asyncio
import aiohttp
import re
from bs4 import BeautifulSoup
from urllib.parse import quote, urljoin
from typing import Dict, Optional, Any, Tuple
from datetime import datetime, timedelta
import logging
from dataclasses import dataclass
import time

from app.core.config import settings

logger = logging.getLogger(__name__)


@dataclass
class ScrapingResult:
    """Resultado do scraping de um personagem"""
    success: bool
    data: Optional[Dict[str, Any]] = None
    error_message: Optional[str] = None
    retry_after: Optional[datetime] = None
    duration_ms: Optional[int] = None


class TibiaCharacterScraper:
    """
    Scraper principal para coleta de dados de personagens do Tibia
    """
    
    def __init__(self):
        self.session: Optional[aiohttp.ClientSession] = None
        self.headers = {
            'User-Agent': settings.USER_AGENT,
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
            'Accept-Language': 'pt-BR,pt;q=0.9,en;q=0.8',
            'Accept-Encoding': 'gzip, deflate, br',
            'Connection': 'keep-alive',
            'Upgrade-Insecure-Requests': '1',
        }
    
    async def __aenter__(self):
        """Context manager entry"""
        timeout = aiohttp.ClientTimeout(total=settings.SCRAPE_TIMEOUT_SECONDS)
        connector = aiohttp.TCPConnector(limit=10, ttl_dns_cache=300, use_dns_cache=True)
        
        self.session = aiohttp.ClientSession(
            timeout=timeout,
            headers=self.headers,
            connector=connector
        )
        return self
    
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit"""
        if self.session:
            await self.session.close()
    
    def _build_character_url(self, server: str, world: str, character_name: str) -> str:
        """Construir URL do personagem baseado no servidor e mundo"""
        base_urls = {
            "taleon": {
                "san": settings.TALEON_SAN_URL,
                "aura": settings.TALEON_AURA_URL,
                "gaia": settings.TALEON_GAIA_URL,
            }
        }
        
        if server not in base_urls:
            raise ValueError(f"Servidor '{server}' não suportado")
        
        if world not in base_urls[server]:
            raise ValueError(f"Mundo '{world}' não suportado para servidor '{server}'")
        
        base_url = base_urls[server][world]
        encoded_name = quote(character_name, safe='')
        
        return f"{base_url}/characterprofile.php?name={encoded_name}"
    
    def _extract_number(self, text: str) -> int:
        """Extrair número de uma string, removendo formatação"""
        if not text:
            return 0
        
        # Remover tudo exceto dígitos
        numbers = re.sub(r'[^\d]', '', str(text))
        return int(numbers) if numbers else 0
    
    def _extract_vocation(self, text: str) -> str:
        """Extrair vocação do texto"""
        if not text:
            return "None"
        
        vocations = [
            "Elite Knight", "Royal Paladin", "Elder Druid", "Master Sorcerer",
            "Knight", "Paladin", "Druid", "Sorcerer"
        ]
        
        text_clean = text.strip()
        for vocation in vocations:
            if vocation.lower() in text_clean.lower():
                return vocation
        
        return "None"
    
    def _parse_date(self, date_text: str) -> Optional[datetime]:
        """Converter texto de data para datetime"""
        if not date_text or date_text.lower() in ['never', 'nunca', '-', '']:
            return None
        
        try:
            # Formato comum: "Dec 25 2023, 15:30:45 CET"
            # Remover timezone se presente
            clean_date = re.sub(r'\s+[A-Z]{3,4}$', '', date_text.strip())
            
            # Tentar diferentes formatos
            formats = [
                "%b %d %Y, %H:%M:%S",
                "%d %b %Y, %H:%M:%S",
                "%Y-%m-%d %H:%M:%S",
                "%d/%m/%Y %H:%M:%S",
                "%m/%d/%Y %H:%M:%S",
            ]
            
            for fmt in formats:
                try:
                    return datetime.strptime(clean_date, fmt)
                except ValueError:
                    continue
            
            logger.warning(f"Não foi possível parsear data: {date_text}")
            return None
            
        except Exception as e:
            logger.warning(f"Erro ao parsear data '{date_text}': {e}")
            return None
    
    def _extract_character_data(self, html: str, url: str) -> Dict[str, Any]:
        """Extrair dados do personagem do HTML"""
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
            'profile_url': url
        }
        
        try:
            # Extrair nome do personagem
            name_element = soup.find('h1') or soup.find('title')
            if name_element:
                data['name'] = name_element.get_text().strip()
            
            # Procurar informações em tabelas ou divs
            # Este é um exemplo genérico - precisa ser adaptado para cada site
            
            # Procurar por padrões comuns de informações
            text_content = soup.get_text().lower()
            
            # Extrair level
            level_match = re.search(r'level:?\s*(\d+)', text_content)
            if level_match:
                data['level'] = int(level_match.group(1))
            
            # Extrair experience
            exp_match = re.search(r'experience:?\s*([\d,]+)', text_content)
            if exp_match:
                data['experience'] = self._extract_number(exp_match.group(1))
            
            # Extrair deaths
            deaths_match = re.search(r'deaths?:?\s*(\d+)', text_content)
            if deaths_match:
                data['deaths'] = int(deaths_match.group(1))
            
            # Extrair vocação
            vocation_match = re.search(r'vocation:?\s*([^,\n]+)', text_content)
            if vocation_match:
                data['vocation'] = self._extract_vocation(vocation_match.group(1))
            
            # Extrair residence
            residence_match = re.search(r'residence:?\s*([^,\n]+)', text_content)
            if residence_match:
                data['residence'] = residence_match.group(1).strip()
            
            # Verificar se está online
            data['is_online'] = 'online' in text_content
            
            # Tentar extrair informações de tabelas estruturadas
            tables = soup.find_all('table')
            for table in tables:
                rows = table.find_all('tr')
                for row in rows:
                    cells = row.find_all(['td', 'th'])
                    if len(cells) >= 2:
                        key = cells[0].get_text().strip().lower()
                        value = cells[1].get_text().strip()
                        
                        if 'level' in key:
                            data['level'] = self._extract_number(value)
                        elif 'experience' in key:
                            data['experience'] = self._extract_number(value)
                        elif 'vocation' in key:
                            data['vocation'] = self._extract_vocation(value)
                        elif 'residence' in key:
                            data['residence'] = value
                        elif 'house' in key and value not in ['-', 'None', '']:
                            data['house'] = value
                        elif 'guild' in key and value not in ['-', 'None', '']:
                            data['guild'] = value
                        elif 'death' in key:
                            data['deaths'] = self._extract_number(value)
                        elif 'charm' in key:
                            data['charm_points'] = self._extract_number(value) or None
                        elif 'boss' in key:
                            data['bosstiary_points'] = self._extract_number(value) or None
                        elif 'achievement' in key:
                            data['achievement_points'] = self._extract_number(value) or None
                        elif 'last login' in key:
                            data['last_login'] = self._parse_date(value)
            
            logger.info(f"Dados extraídos para {data['name']}: Level {data['level']}, Exp {data['experience']}")
            
        except Exception as e:
            logger.error(f"Erro ao extrair dados do HTML: {e}")
            raise
        
        return data
    
    async def scrape_character(self, server: str, world: str, character_name: str) -> ScrapingResult:
        """
        Fazer scraping de um personagem específico
        """
        start_time = time.time()
        
        try:
            # Construir URL
            url = self._build_character_url(server, world, character_name)
            logger.info(f"Fazendo scraping de {character_name} em {server}/{world}: {url}")
            
            # Aguardar delay entre requests
            await asyncio.sleep(settings.SCRAPE_DELAY_SECONDS)
            
            # Fazer requisição
            async with self.session.get(url) as response:
                if response.status == 404:
                    return ScrapingResult(
                        success=False,
                        error_message="Personagem não encontrado",
                        retry_after=datetime.now() + timedelta(hours=1)
                    )
                
                if response.status != 200:
                    return ScrapingResult(
                        success=False,
                        error_message=f"Erro HTTP {response.status}",
                        retry_after=datetime.now() + timedelta(minutes=5)
                    )
                
                html = await response.text()
                
                # Verificar se a página indica personagem não encontrado
                if any(phrase in html.lower() for phrase in [
                    'character not found', 'personagem não encontrado',
                    'does not exist', 'não existe'
                ]):
                    return ScrapingResult(
                        success=False,
                        error_message="Personagem não encontrado na página",
                        retry_after=datetime.now() + timedelta(hours=1)
                    )
                
                # Extrair dados
                data = self._extract_character_data(html, url)
                
                # Validar dados mínimos
                if not data['name'] or data['level'] < 1:
                    return ScrapingResult(
                        success=False,
                        error_message="Dados insuficientes extraídos da página",
                        retry_after=datetime.now() + timedelta(minutes=15)
                    )
                
                duration_ms = int((time.time() - start_time) * 1000)
                
                return ScrapingResult(
                    success=True,
                    data=data,
                    duration_ms=duration_ms
                )
                
        except asyncio.TimeoutError:
            return ScrapingResult(
                success=False,
                error_message="Timeout na requisição",
                retry_after=datetime.now() + timedelta(minutes=5)
            )
        
        except aiohttp.ClientError as e:
            return ScrapingResult(
                success=False,
                error_message=f"Erro de rede: {str(e)}",
                retry_after=datetime.now() + timedelta(minutes=5)
            )
        
        except Exception as e:
            logger.error(f"Erro inesperado no scraping: {e}", exc_info=True)
            return ScrapingResult(
                success=False,
                error_message=f"Erro interno: {str(e)}",
                retry_after=datetime.now() + timedelta(minutes=15)
            )


# Instância global do scraper
async def get_scraper() -> TibiaCharacterScraper:
    """Obter instância do scraper"""
    return TibiaCharacterScraper()


# Função de conveniência para scraping
async def scrape_character_data(server: str, world: str, character_name: str) -> ScrapingResult:
    """
    Função de conveniência para fazer scraping de um personagem
    """
    async with TibiaCharacterScraper() as scraper:
        return await scraper.scrape_character(server, world, character_name) 