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


class TaleonCharacterScraper:
    """
    Scraper específico para o servidor Taleon
    Baseado na estrutura real da página: https://san.taleon.online/characterprofile.php?name=Gates
    """
    
    def __init__(self):
        self.session: Optional[aiohttp.ClientSession] = None
        self.headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
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
                "san": "https://san.taleon.online",
                "aura": "https://aura.taleon.online", 
                "gaia": "https://gaia.taleon.online",
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
        """Extrair número de uma string, removendo formatação (pontos, vírgulas)"""
        if not text:
            return 0
        
        # Remover tudo exceto dígitos (pontos e vírgulas são separadores no Taleon)
        numbers = re.sub(r'[^\d]', '', str(text))
        return int(numbers) if numbers else 0
    
    def _extract_outfit_image_url(self, soup: BeautifulSoup) -> Optional[str]:
        """Extrair URL da imagem do outfit"""
        try:
            # Procurar por imagem do outfit no padrão outfits.taleon.online
            outfit_img = soup.find('img', src=re.compile(r'outfits\.taleon\.online/outfit\.php'))
            if outfit_img and outfit_img.get('src'):
                return outfit_img['src']
            return None
        except Exception as e:
            logger.warning(f"Erro ao extrair URL do outfit: {e}")
            return None
    
    def _parse_date(self, date_text: str) -> Optional[datetime]:
        """Converter texto de data do Taleon para datetime"""
        if not date_text or date_text.lower() in ['never', 'nunca', '-', '']:
            return None
        
        try:
            # Formato do Taleon: "27 Jun 2025, 19:33 → 27 Jun 2025, 20:17"
            # Pegar apenas a primeira data (login)
            if '→' in date_text:
                date_text = date_text.split('→')[0].strip()
            
            # Formato esperado: "27 Jun 2025, 19:33"
            # Converter para formato parseável
            clean_date = date_text.strip()
            
            # Tentar parsear o formato específico do Taleon
            try:
                return datetime.strptime(clean_date, "%d %b %Y, %H:%M")
            except ValueError:
                pass
            
            # Tentar outros formatos comuns
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
    
    def _extract_taleon_character_data(self, html: str, url: str) -> Dict[str, Any]:
        """Extrair dados do personagem do HTML específico do Taleon"""
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
                            data['last_login'] = self._parse_date(value)
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
                
                # Ou procurar por h1, h2, h3 que possam conter o nome
                for tag in ['h1', 'h2', 'h3']:
                    header = soup.find(tag)
                    if header and 'character profile' in header.get_text().lower():
                        header_text = header.get_text()
                        match = re.search(r'character profile of (.+)', header_text, re.IGNORECASE)
                        if match:
                            data['name'] = match.group(1).strip()
                            break
            
            # Tentar extrair experiência e mortes das tabelas de histórico
            # Experience History table
            text_content = soup.get_text().lower()
            
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
                    
                    # Se encontrou experiência no histórico, usar como base
                    if total_exp > 0:
                        data['experience'] = total_exp
            
            # Buscar seção "death list" para contar mortes
            death_section = soup.find(text=re.compile(r'death list', re.IGNORECASE))
            if death_section:
                death_table = death_section.find_next('table')
                if death_table:
                    death_rows = death_table.find_all('tr')
                    # Contar linhas de morte (excluir header e linhas vazias)
                    death_count = 0
                    for row in death_rows[1:]:  # Pular header
                        cells = row.find_all(['td', 'th'])
                        if len(cells) >= 2:
                            death_text = cells[0].get_text().strip()
                            if death_text and 'no victims' not in death_text.lower():
                                death_count += 1
                    data['deaths'] = death_count
            
            # Validação final dos dados extraídos
            if not data['name']:
                raise ValueError("Nome do personagem não encontrado")
            
            if data['level'] < 1:
                raise ValueError("Level inválido encontrado")
            
            logger.info(f"✅ Dados extraídos do Taleon - {data['name']}: Level {data['level']}, Vocation {data['vocation']}")
            logger.debug(f"Dados completos: {data}")
            
        except Exception as e:
            logger.error(f"❌ Erro ao extrair dados do HTML do Taleon: {e}")
            raise
        
        return data
    
    async def scrape_character(self, server: str, world: str, character_name: str) -> ScrapingResult:
        """
        Fazer scraping de um personagem específico do Taleon
        """
        start_time = time.time()
        
        try:
            # Construir URL
            url = self._build_character_url(server, world, character_name)
            logger.info(f"🔍 Fazendo scraping de {character_name} em {server}/{world}: {url}")
            
            # Aguardar delay entre requests
            await asyncio.sleep(settings.SCRAPE_DELAY_SECONDS)
            
            # Fazer requisição
            async with self.session.get(url) as response:
                if response.status == 404:
                    return ScrapingResult(
                        success=False,
                        error_message="Personagem não encontrado (404)",
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
                    'does not exist', 'não existe', 'character does not exist'
                ]):
                    return ScrapingResult(
                        success=False,
                        error_message="Personagem não encontrado na página",
                        retry_after=datetime.now() + timedelta(hours=1)
                    )
                
                # Extrair dados usando o parser específico do Taleon
                data = self._extract_taleon_character_data(html, url)
                
                # Validar dados mínimos
                if not data['name'] or data['level'] < 1:
                    return ScrapingResult(
                        success=False,
                        error_message="Dados insuficientes extraídos da página",
                        retry_after=datetime.now() + timedelta(minutes=15)
                    )
                
                duration_ms = int((time.time() - start_time) * 1000)
                
                logger.info(f"✅ Scraping concluído com sucesso em {duration_ms}ms")
                
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
        
        except ValueError as e:
            return ScrapingResult(
                success=False,
                error_message=str(e),
                retry_after=datetime.now() + timedelta(hours=1)
            )
        
        except Exception as e:
            logger.error(f"❌ Erro inesperado no scraping: {e}", exc_info=True)
            return ScrapingResult(
                success=False,
                error_message=f"Erro interno: {str(e)}",
                retry_after=datetime.now() + timedelta(minutes=15)
            )


# Classe principal que unifica todos os scrapers
class TibiaCharacterScraper:
    """
    Scraper principal que unifica todos os servidores
    """
    
    def __init__(self):
        self.taleon_scraper = TaleonCharacterScraper()
    
    async def __aenter__(self):
        """Context manager entry"""
        await self.taleon_scraper.__aenter__()
        return self
    
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit"""
        await self.taleon_scraper.__aexit__(exc_type, exc_val, exc_tb)
    
    async def scrape_character(self, server: str, world: str, character_name: str) -> ScrapingResult:
        """
        Fazer scraping de um personagem baseado no servidor
        """
        if server.lower() == "taleon":
            return await self.taleon_scraper.scrape_character(server, world, character_name)
        else:
            return ScrapingResult(
                success=False,
                error_message=f"Servidor '{server}' ainda não implementado",
                retry_after=datetime.now() + timedelta(hours=24)
            )


# Função de conveniência para scraping
async def scrape_character_data(server: str, world: str, character_name: str) -> ScrapingResult:
    """
    Função de conveniência para fazer scraping de um personagem
    """
    async with TibiaCharacterScraper() as scraper:
        return await scraper.scrape_character(server, world, character_name) 