"""
Classe Base Abstrata para Web Scrapers
======================================

Define a interface padrão que todos os scrapers de servidores devem implementar.
"""

from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import Dict, Optional, Any, List
from datetime import datetime
import aiohttp
import logging

logger = logging.getLogger(__name__)


@dataclass
class ScrapingResult:
    """Resultado padronizado do scraping de um personagem"""
    success: bool
    data: Optional[Dict[str, Any]] = None
    error_message: Optional[str] = None
    retry_after: Optional[datetime] = None
    duration_ms: Optional[int] = None
    
    def __post_init__(self):
        """Validar dados após inicialização"""
        if self.success and not self.data:
            raise ValueError("ScrapingResult com success=True deve conter dados")
        if not self.success and not self.error_message:
            raise ValueError("ScrapingResult com success=False deve conter error_message")


class BaseCharacterScraper(ABC):
    """
    Classe base abstrata para scrapers de personagens
    
    Cada servidor deve implementar esta interface para garantir
    consistência e facilitar manutenção.
    """
    
    def __init__(self):
        self.session: Optional[aiohttp.ClientSession] = None
        self.server_name = self._get_server_name()
        self.supported_worlds = self._get_supported_worlds()
        self.base_headers = self._get_default_headers()
    
    async def __aenter__(self):
        """Context manager entry - configurar sessão HTTP"""
        timeout = aiohttp.ClientTimeout(total=30)
        connector = aiohttp.TCPConnector(
            limit=10, 
            ttl_dns_cache=300, 
            use_dns_cache=True
        )
        
        self.session = aiohttp.ClientSession(
            timeout=timeout,
            headers=self.base_headers,
            connector=connector
        )
        return self
    
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit - fechar sessão HTTP"""
        if self.session:
            await self.session.close()
    
    # === MÉTODOS ABSTRATOS (devem ser implementados por cada servidor) ===
    
    @abstractmethod
    def _get_server_name(self) -> str:
        """Retornar nome do servidor (ex: 'taleon', 'rubini')"""
        pass
    
    @abstractmethod
    def _get_supported_worlds(self) -> List[str]:
        """Retornar lista de mundos suportados pelo servidor"""
        pass
    
    @abstractmethod
    def _build_character_url(self, world: str, character_name: str) -> str:
        """Construir URL específica do personagem para este servidor"""
        pass
    
    @abstractmethod
    async def _extract_character_data(self, html: str, url: str) -> Dict[str, Any]:
        """Extrair dados do personagem do HTML específico deste servidor"""
        pass
    
    # === MÉTODOS PADRÃO (podem ser sobrescritos se necessário) ===
    
    def _get_default_headers(self) -> Dict[str, str]:
        """Headers padrão para requisições HTTP"""
        return {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
            'Accept-Language': 'pt-BR,pt;q=0.9,en;q=0.8',
            'Accept-Encoding': 'gzip, deflate, br',
            'Connection': 'keep-alive',
            'Upgrade-Insecure-Requests': '1',
        }
    
    def _validate_world(self, world: str) -> bool:
        """Validar se o mundo é suportado por este servidor"""
        return world.lower() in [w.lower() for w in self.supported_worlds]
    
    def _extract_number(self, text: str) -> int:
        """Extrair número de uma string, removendo formatação"""
        if not text:
            return 0
        
        import re
        # Remover tudo exceto dígitos
        numbers = re.sub(r'[^\d]', '', str(text))
        return int(numbers) if numbers else 0
    
    def _parse_date(self, date_text: str) -> Optional[datetime]:
        """Método base para parsing de datas - pode ser sobrescrito"""
        if not date_text or date_text.lower() in ['never', 'nunca', '-', '']:
            return None
        
        # Implementação básica - servers específicos podem sobrescrever
        try:
            from datetime import datetime
            import re
            
            # Remover timezone se presente
            clean_date = re.sub(r'\s+[A-Z]{3,4}$', '', date_text.strip())
            
            # Tentar formatos comuns
            formats = [
                "%d %b %Y, %H:%M",
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
    
    def _standardize_character_data(self, raw_data: Dict[str, Any]) -> Dict[str, Any]:
        """Padronizar dados extraídos para formato comum"""
        return {
            'name': raw_data.get('name', ''),
            'level': int(raw_data.get('level', 0)),
            'vocation': raw_data.get('vocation', 'None'),
            'residence': raw_data.get('residence', ''),
            'house': raw_data.get('house'),
            'guild': raw_data.get('guild'),
            'guild_rank': raw_data.get('guild_rank'),
            'experience': int(raw_data.get('experience', 0)),
            'deaths': int(raw_data.get('deaths', 0)),
            'charm_points': raw_data.get('charm_points'),
            'bosstiary_points': raw_data.get('bosstiary_points'),
            'achievement_points': raw_data.get('achievement_points'),
            'is_online': bool(raw_data.get('is_online', False)),
            'last_login': raw_data.get('last_login'),
            'profile_url': raw_data.get('profile_url', ''),
            'outfit_image_url': raw_data.get('outfit_image_url'),
            'experience_history': raw_data.get('experience_history', [])
        }
    
    # === MÉTODO PRINCIPAL (implementação padrão) ===
    
    async def scrape_character(self, world: str, character_name: str) -> ScrapingResult:
        """
        Método principal para scraping de personagem
        Implementação padrão que pode ser sobrescrita se necessário
        """
        import time
        import asyncio
        from datetime import datetime, timedelta
        
        start_time = time.time()
        
        try:
            # Validar mundo
            if not self._validate_world(world):
                return ScrapingResult(
                    success=False,
                    error_message=f"Mundo '{world}' não suportado pelo servidor {self.server_name}. Mundos disponíveis: {self.supported_worlds}",
                    retry_after=datetime.now() + timedelta(hours=1)
                )
            
            # Construir URL
            url = self._build_character_url(world, character_name)
            logger.info(f"🔍 [{self.server_name.upper()}] Fazendo scraping de {character_name} em {world}: {url}")
            
            # Delay entre requests (configurável por servidor)
            await asyncio.sleep(self._get_request_delay())
            
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
                if self._is_character_not_found(html):
                    return ScrapingResult(
                        success=False,
                        error_message="Personagem não encontrado na página",
                        retry_after=datetime.now() + timedelta(hours=1)
                    )
                
                # Extrair dados usando implementação específica do servidor
                raw_data = await self._extract_character_data(html, url)
                
                # Padronizar dados
                data = self._standardize_character_data(raw_data)
                
                # Validar dados mínimos
                if not data['name'] or data['level'] < 1:
                    return ScrapingResult(
                        success=False,
                        error_message="Dados insuficientes extraídos da página",
                        retry_after=datetime.now() + timedelta(minutes=15)
                    )
                
                duration_ms = int((time.time() - start_time) * 1000)
                
                logger.info(f"✅ [{self.server_name.upper()}] Scraping concluído com sucesso em {duration_ms}ms")
                
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
            logger.error(f"❌ [{self.server_name.upper()}] Erro inesperado no scraping: {e}", exc_info=True)
            return ScrapingResult(
                success=False,
                error_message=f"Erro interno: {str(e)}",
                retry_after=datetime.now() + timedelta(minutes=15)
            )
    
    # === MÉTODOS AUXILIARES (podem ser sobrescritos) ===
    
    def _get_request_delay(self) -> float:
        """Delay entre requests em segundos - pode ser sobrescrito"""
        return 2.0
    
    def _is_character_not_found(self, html: str) -> bool:
        """Verificar se HTML indica personagem não encontrado"""
        not_found_phrases = [
            'character not found', 'personagem não encontrado',
            'does not exist', 'não existe', 'character does not exist'
        ]
        html_lower = html.lower()
        return any(phrase in html_lower for phrase in not_found_phrases) 