#!/usr/bin/env python3
"""
Script de Carregamento Automático de Personagens - Versão API
============================================================

Este script faz scraping de múltiplos sites do Taleon para obter listas de personagens
e automaticamente os adiciona ao sistema via API do backend.

Usa a mesma estratégia dos outros scripts: chama a API do backend ao invés de fazer scraping direto.
Não requer dependências extras - apenas Python padrão.

Uso:
    python3 auto-load-new-chars-api.py                    # Executa todos os sites
    python3 auto-load-new-chars-api.py --deaths-only      # Apenas sites de mortes (3 dias)
    python3 auto-load-new-chars-api.py --powergamers-only # Apenas powergamers (diário)
    python3 auto-load-new-chars-api.py --online-only      # Apenas online (1h)
    python3 auto-load-new-chars-api.py --help             # Mostra ajuda
"""

import urllib.request
import urllib.parse
import urllib.error
import logging
import sys
import os
import argparse
from datetime import datetime, timedelta
from typing import List, Dict, Set, Optional
from dataclasses import dataclass
import json
import time
import re

# Configuração de logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('auto-load-new-chars-api.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)


@dataclass
class TaleonSite:
    """Configuração de um site do Taleon"""
    name: str
    world: str
    base_url: str
    character_list_url: str
    description: str
    enabled: bool = True
    delay_seconds: float = 3.0
    timeout_seconds: int = 30


@dataclass
class ScrapingResult:
    """Resultado do scraping de um site"""
    site: TaleonSite
    success: bool
    characters_found: int
    characters_list: List[str]
    error_message: Optional[str] = None
    duration_ms: Optional[int] = None


@dataclass
class APIResult:
    """Resultado de uma chamada da API"""
    character_name: str
    success: bool
    character_id: Optional[int] = None
    error_message: Optional[str] = None
    duration_ms: Optional[int] = None
    from_database: Optional[bool] = None


class TaleonAutoLoaderAPI:
    """Classe principal para carregamento automático de personagens (versão API)"""
    
    def __init__(self, api_base_url: str = "http://localhost:8000", mode: str = "all"):
        self.api_base_url = api_base_url
        self.mode = mode  # all, deaths-only, powergamers-only, online-only
        
        # Headers HTTP para requisições aos sites do Taleon
        self.headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
            'Accept-Language': 'pt-BR,pt;q=0.9,en;q=0.8',
            'Accept-Encoding': 'gzip, deflate, br',
            'Connection': 'keep-alive',
            'Upgrade-Insecure-Requests': '1',
        }
        
        # Configuração dos sites do Taleon
        self.taleon_sites = self._configure_taleon_sites()
        
        # Estatísticas
        self.stats = {
            'sites_scraped': 0,
            'sites_failed': 0,
            'total_characters_found': 0,
            'characters_added': 0,
            'characters_failed': 0,
            'characters_already_exist': 0,
            'start_time': None,
            'end_time': None
        }
    
    def _configure_taleon_sites(self) -> List[TaleonSite]:
        """Configurar todos os sites do Taleon para scraping"""
        
        sites = [
            # ===== SITES DE MORTES =====
            TaleonSite(
                name="Latest Deaths San",
                world="san",
                base_url="https://san.taleon.online",
                character_list_url="https://san.taleon.online/deaths.php",
                description="Últimas mortes do mundo San",
                enabled=True,
                delay_seconds=3.0
            ),
            TaleonSite(
                name="Latest Deaths Aura",
                world="aura",
                base_url="https://aura.taleon.online",
                character_list_url="https://aura.taleon.online/deaths.php",
                description="Últimas mortes do mundo Aura",
                enabled=True,
                delay_seconds=3.0
            ),
            TaleonSite(
                name="Latest Deaths Gaia",
                world="gaia",
                base_url="https://gaia.taleon.online",
                character_list_url="https://gaia.taleon.online/deaths.php",
                description="Últimas mortes do mundo Gaia",
                enabled=True,
                delay_seconds=3.0
            ),
            
            # ===== SITES DE POWERGAMERS =====
            TaleonSite(
                name="Powergamers San",
                world="san",
                base_url="https://san.taleon.online",
                character_list_url="https://san.taleon.online/powergamers.php",
                description="Powergamers do mundo San",
                enabled=True,
                delay_seconds=3.5
            ),
            TaleonSite(
                name="Powergamers Aura",
                world="aura",
                base_url="https://aura.taleon.online",
                character_list_url="https://aura.taleon.online/powergamers.php",
                description="Powergamers do mundo Aura",
                enabled=True,
                delay_seconds=3.5
            ),
            TaleonSite(
                name="Powergamers Gaia",
                world="gaia",
                base_url="https://gaia.taleon.online",
                character_list_url="https://gaia.taleon.online/powergamers.php",
                description="Powergamers do mundo Gaia",
                enabled=True,
                delay_seconds=3.5
            ),
            
            # ===== SITES DE ONLINE =====
            TaleonSite(
                name="Online List San",
                world="san",
                base_url="https://san.taleon.online",
                character_list_url="https://san.taleon.online/onlinelist.php",
                description="Lista de jogadores online do mundo San",
                enabled=True,
                delay_seconds=2.5
            ),
            TaleonSite(
                name="Online List Aura",
                world="aura",
                base_url="https://aura.taleon.online",
                character_list_url="https://aura.taleon.online/onlinelist.php",
                description="Lista de jogadores online do mundo Aura",
                enabled=True,
                delay_seconds=2.5
            ),
            TaleonSite(
                name="Online List Gaia",
                world="gaia",
                base_url="https://gaia.taleon.online",
                character_list_url="https://gaia.taleon.online/onlinelist.php",
                description="Lista de jogadores online do mundo Gaia",
                enabled=True,
                delay_seconds=2.5
            ),
        ]
        
        return sites
    
    def _filter_sites_by_mode(self, sites: List[TaleonSite]) -> List[TaleonSite]:
        """Filtrar sites baseado no modo de execução"""
        if self.mode == "all":
            return [site for site in sites if site.enabled]
        elif self.mode == "deaths-only":
            return [site for site in sites if site.enabled and "deaths" in site.name.lower()]
        elif self.mode == "powergamers-only":
            return [site for site in sites if site.enabled and "powergamers" in site.name.lower()]
        elif self.mode == "online-only":
            return [site for site in sites if site.enabled and "online" in site.name.lower()]
        else:
            return []
    
    def _extract_character_name_from_url(self, href: str) -> Optional[str]:
        """Extrair nome do personagem do parâmetro 'name' da URL"""
        try:
            # Procurar por characterprofile.php?name=Nome
            match = re.search(r'characterprofile\.php\?name=([^&]+)', href)
            if match:
                # Decodificar caracteres especiais (ex: %20 -> espaço)
                from urllib.parse import unquote
                character_name = unquote(match.group(1))
                return character_name.strip()
            return None
        except Exception as e:
            logger.warning(f"Erro ao extrair nome da URL '{href}': {e}")
            return None
    
    def _make_request(self, url: str) -> Optional[str]:
        """Fazer requisição HTTP usando urllib (biblioteca padrão)"""
        try:
            req = urllib.request.Request(url, headers=self.headers)
            with urllib.request.urlopen(req, timeout=30) as response:
                # Tentar detectar e lidar com compressão
                content_encoding = response.headers.get('Content-Encoding', '').lower()
                
                if content_encoding == 'gzip':
                    import gzip
                    html = gzip.decompress(response.read()).decode('utf-8', errors='ignore')
                elif content_encoding == 'deflate':
                    import zlib
                    html = zlib.decompress(response.read()).decode('utf-8', errors='ignore')
                else:
                    html = response.read().decode('utf-8', errors='ignore')
                
                return html
                
        except urllib.error.HTTPError as e:
            logger.error(f"Erro HTTP {e.code} ao acessar {url}: {e.reason}")
            return None
        except urllib.error.URLError as e:
            logger.error(f"Erro de URL ao acessar {url}: {e.reason}")
            return None
        except Exception as e:
            logger.error(f"Erro inesperado ao acessar {url}: {e}")
            return None
    
    def scrape_site_characters(self, site: TaleonSite) -> ScrapingResult:
        """Fazer scraping de personagens de um site específico"""
        start_time = time.time()
        
        try:
            logger.info(f"🔍 Iniciando scraping de {site.name}: {site.character_list_url}")
            
            # Fazer requisição HTTP
            html = self._make_request(site.character_list_url)
            
            if html is None:
                error_msg = f"Falha ao baixar página de {site.name}"
                logger.error(f"❌ {error_msg}")
                return ScrapingResult(
                    site=site,
                    success=False,
                    characters_found=0,
                    characters_list=[],
                    error_message=error_msg
                )
            
            # Extrair personagens baseado no tipo de site
            characters = []
            if "deaths" in site.name.lower():
                characters = self._extract_from_deaths(html, site)
            elif "powergamers" in site.name.lower():
                characters = self._extract_from_powergamers(html, site)
            elif "online" in site.name.lower():
                characters = self._extract_from_onlinelist(html, site)
            else:
                characters = self._extract_generic_characters(html, site)
            
            duration_ms = int((time.time() - start_time) * 1000)
            
            logger.info(f"✅ {site.name}: {len(characters)} personagens encontrados em {duration_ms}ms")
            
            return ScrapingResult(
                site=site,
                success=True,
                characters_found=len(characters),
                characters_list=characters,
                duration_ms=duration_ms
            )
            
        except Exception as e:
            error_msg = f"Erro inesperado ao fazer scraping de {site.name}: {e}"
            logger.error(f"❌ {error_msg}")
            return ScrapingResult(
                site=site,
                success=False,
                characters_found=0,
                characters_list=[],
                error_message=error_msg
            )
    
    def _extract_from_deaths(self, html: str, site: TaleonSite) -> List[str]:
        """Extrair nomes de personagens da página de mortes"""
        characters = set()
        
        try:
            # Procurar por links que contenham characterprofile.php?name=
            pattern = r'href=["\']([^"\']*characterprofile\.php\?name=[^"\']*)["\']'
            matches = re.findall(pattern, html, re.IGNORECASE)
            
            for match in matches:
                character_name = self._extract_character_name_from_url(match)
                if character_name:
                    characters.add(character_name)
            
            logger.debug(f"📊 {site.name}: {len(characters)} personagens extraídos da página de mortes")
            
        except Exception as e:
            logger.error(f"❌ Erro ao extrair personagens de mortes de {site.name}: {e}")
        
        return list(characters)
    
    def _extract_from_powergamers(self, html: str, site: TaleonSite) -> List[str]:
        """Extrair nomes de personagens da página de powergamers"""
        characters = set()
        
        try:
            # Procurar por links que contenham characterprofile.php?name=
            pattern = r'href=["\']([^"\']*characterprofile\.php\?name=[^"\']*)["\']'
            matches = re.findall(pattern, html, re.IGNORECASE)
            
            for match in matches:
                character_name = self._extract_character_name_from_url(match)
                if character_name:
                    characters.add(character_name)
            
            logger.debug(f"📊 {site.name}: {len(characters)} personagens extraídos da página de powergamers")
            
        except Exception as e:
            logger.error(f"❌ Erro ao extrair personagens de powergamers de {site.name}: {e}")
        
        return list(characters)
    
    def _extract_from_onlinelist(self, html: str, site: TaleonSite) -> List[str]:
        """Extrair nomes de personagens da página de online"""
        characters = set()
        
        try:
            # Procurar por links que contenham characterprofile.php?name=
            pattern = r'href=["\']([^"\']*characterprofile\.php\?name=[^"\']*)["\']'
            matches = re.findall(pattern, html, re.IGNORECASE)
            
            for match in matches:
                character_name = self._extract_character_name_from_url(match)
                if character_name:
                    characters.add(character_name)
            
            logger.debug(f"📊 {site.name}: {len(characters)} personagens extraídos da página de online")
            
        except Exception as e:
            logger.error(f"❌ Erro ao extrair personagens de online de {site.name}: {e}")
        
        return list(characters)
    
    def _extract_generic_characters(self, html: str, site: TaleonSite) -> List[str]:
        """Extração genérica de personagens (fallback)"""
        characters = set()
        
        try:
            # Procurar por links que contenham characterprofile.php?name=
            pattern = r'href=["\']([^"\']*characterprofile\.php\?name=[^"\']*)["\']'
            matches = re.findall(pattern, html, re.IGNORECASE)
            
            for match in matches:
                character_name = self._extract_character_name_from_url(match)
                if character_name:
                    characters.add(character_name)
            
            logger.debug(f"📊 {site.name}: {len(characters)} personagens extraídos (método genérico)")
            
        except Exception as e:
            logger.error(f"❌ Erro ao extrair personagens de {site.name}: {e}")
        
        return list(characters)
    
    def add_character_via_api(self, character_name: str, world: str) -> APIResult:
        """Adicionar personagem via API do backend (igual aos outros scripts)"""
        start_time = time.time()
        
        try:
            logger.info(f"🎯 Adicionando personagem via API: {character_name} ({world})")
            
            # Construir URL da API (igual aos scripts bash)
            clean_server = urllib.parse.quote("taleon", safe='')
            clean_world = urllib.parse.quote(world, safe='')
            clean_name = urllib.parse.quote(character_name, safe='')
            
            api_url = f"{self.api_base_url}/api/v1/characters/scrape-and-create?server={clean_server}&world={clean_world}&character_name={clean_name}"
            
            logger.debug(f"🔍 URL da API: {api_url}")
            
            # Fazer requisição POST para a API
            req = urllib.request.Request(
                api_url,
                method='POST',
                headers={'Content-Type': 'application/json'}
            )
            
            with urllib.request.urlopen(req, timeout=30) as response:
                response_body = response.read().decode('utf-8')
                response_data = json.loads(response_body)
                
                duration_ms = int((time.time() - start_time) * 1000)
                
                if response.status in [200, 201]:
                    logger.info(f"✅ {character_name} ({world}): Adicionado com sucesso em {duration_ms}ms")
                    
                    return APIResult(
                        character_name=character_name,
                        success=True,
                        character_id=response_data.get('character', {}).get('id'),
                        duration_ms=duration_ms,
                        from_database=False
                    )
                else:
                    logger.warning(f"⚠️ {character_name} ({world}): {response_data.get('detail', 'Erro desconhecido')}")
                    
                    return APIResult(
                        character_name=character_name,
                        success=False,
                        error_message=response_data.get('detail', 'Erro desconhecido'),
                        duration_ms=duration_ms,
                        from_database=False
                    )
                    
        except urllib.error.HTTPError as e:
            duration_ms = int((time.time() - start_time) * 1000)
            
            try:
                error_body = e.read().decode('utf-8')
                error_data = json.loads(error_body)
                error_msg = error_data.get('detail', f'HTTP {e.code}')
            except:
                error_msg = f'HTTP {e.code}: {e.reason}'
            
            logger.warning(f"⚠️ {character_name} ({world}): {error_msg}")
            
            return APIResult(
                character_name=character_name,
                success=False,
                error_message=error_msg,
                duration_ms=duration_ms,
                from_database=False
            )
            
        except Exception as e:
            duration_ms = int((time.time() - start_time) * 1000)
            error_msg = f"Erro inesperado ao adicionar {character_name}: {e}"
            logger.error(f"❌ {error_msg}")
            
            return APIResult(
                character_name=character_name,
                success=False,
                error_message=error_msg,
                duration_ms=duration_ms,
                from_database=False
            )
    
    def run_auto_load(self, max_characters_per_site: int = 100) -> Dict:
        """Executar o carregamento automático de personagens"""
        self.stats['start_time'] = datetime.now()
        
        logger.info(f"🚀 Iniciando carregamento automático de personagens (modo: {self.mode})")
        logger.info(f"📊 Sites configurados: {len(self.taleon_sites)}")
        logger.info(f"🌐 API Base URL: {self.api_base_url}")
        
        # Filtrar sites baseado no modo
        sites_to_process = self._filter_sites_by_mode(self.taleon_sites)
        logger.info(f"🎯 Sites para processar: {len(sites_to_process)}")
        
        # Processar cada site
        all_characters = set()  # Usar set para evitar duplicatas
        
        for site in sites_to_process:
            logger.info(f"🌐 Processando {site.name}...")
            
            # Fazer scraping do site
            scraping_result = self.scrape_site_characters(site)
            
            if scraping_result.success:
                self.stats['sites_scraped'] += 1
                
                # Limitar número de personagens por site
                characters_to_process = scraping_result.characters_list[:max_characters_per_site]
                all_characters.update(characters_to_process)
                
                logger.info(f"✅ {site.name}: {len(characters_to_process)} personagens para processar")
                
                # Delay entre sites
                if site.delay_seconds > 0:
                    logger.debug(f"⏳ Aguardando {site.delay_seconds}s antes do próximo site...")
                    time.sleep(site.delay_seconds)
            else:
                self.stats['sites_failed'] += 1
                logger.error(f"❌ {site.name}: Falha no scraping - {scraping_result.error_message}")
        
        # Processar personagens encontrados
        logger.info(f"🎯 Total de personagens únicos encontrados: {len(all_characters)}")
        
        characters_list = list(all_characters)
        self.stats['total_characters_found'] = len(characters_list)
        
        # Adicionar personagens via API
        for i, character_name in enumerate(characters_list, 1):
            logger.info(f"👤 [{i}/{len(characters_list)}] Processando: {character_name}")
            
            # Determinar mundo baseado nos sites processados
            world = self._determine_character_world(character_name, sites_to_process)
            
            if world:
                api_result = self.add_character_via_api(character_name, world)
                
                if api_result.success:
                    self.stats['characters_added'] += 1
                else:
                    self.stats['characters_failed'] += 1
            else:
                logger.warning(f"⚠️ Não foi possível determinar o mundo para {character_name}")
                self.stats['characters_failed'] += 1
            
            # Delay entre personagens para não sobrecarregar
            time.sleep(1.0)
        
        # Finalizar estatísticas
        self.stats['end_time'] = datetime.now()
        duration = self.stats['end_time'] - self.stats['start_time']
        
        logger.info(f"🏁 Carregamento automático concluído em {duration}")
        logger.info(f"📊 Estatísticas finais:")
        logger.info(f"   - Sites processados: {self.stats['sites_scraped']}")
        logger.info(f"   - Sites com falha: {self.stats['sites_failed']}")
        logger.info(f"   - Personagens encontrados: {self.stats['total_characters_found']}")
        logger.info(f"   - Personagens adicionados: {self.stats['characters_added']}")
        logger.info(f"   - Personagens com falha: {self.stats['characters_failed']}")
        
        return self.stats
    
    def _determine_character_world(self, character_name: str, sites_processed: List[TaleonSite]) -> Optional[str]:
        """Determinar o mundo de um personagem baseado nos sites processados"""
        # Para simplificar, usar o primeiro mundo encontrado
        # Em uma implementação mais robusta, poderia fazer uma busca específica
        if sites_processed:
            return sites_processed[0].world
        return None


def parse_arguments():
    """Parser de argumentos da linha de comando"""
    parser = argparse.ArgumentParser(
        description="Script de carregamento automático de personagens do Taleon (versão API)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Exemplos de uso:
  python3 auto-load-new-chars-api.py                    # Executa todos os sites
  python3 auto-load-new-chars-api.py --deaths-only      # Apenas sites de mortes
  python3 auto-load-new-chars-api.py --powergamers-only # Apenas powergamers
  python3 auto-load-new-chars-api.py --online-only      # Apenas online
  python3 auto-load-new-chars-api.py --api-url http://localhost:8000
        """
    )
    
    parser.add_argument(
        '--deaths-only',
        action='store_true',
        help='Executar apenas sites de mortes (recomendado para CRON a cada 3 dias)'
    )
    
    parser.add_argument(
        '--powergamers-only',
        action='store_true',
        help='Executar apenas sites de powergamers (recomendado para CRON diário)'
    )
    
    parser.add_argument(
        '--online-only',
        action='store_true',
        help='Executar apenas sites de online (recomendado para CRON a cada 1h)'
    )
    
    parser.add_argument(
        '--api-url',
        default='http://localhost:8000',
        help='URL base da API (padrão: http://localhost:8000)'
    )
    
    parser.add_argument(
        '--max-characters',
        type=int,
        default=100,
        help='Número máximo de personagens por site (padrão: 100)'
    )
    
    parser.add_argument(
        '--debug',
        action='store_true',
        help='Ativar modo debug com logs mais detalhados'
    )
    
    return parser.parse_args()


def main():
    """Função principal"""
    args = parse_arguments()
    
    # Configurar logging
    if args.debug:
        logging.getLogger().setLevel(logging.DEBUG)
        logger.info("🐛 Modo debug ativado")
    
    # Determinar modo baseado nos argumentos
    mode = "all"
    if args.deaths_only:
        mode = "deaths-only"
    elif args.powergamers_only:
        mode = "powergamers-only"
    elif args.online_only:
        mode = "online-only"
    
    logger.info(f"🎯 Modo de execução: {mode}")
    logger.info(f"🌐 API URL: {args.api_url}")
    logger.info(f"📊 Máximo de personagens por site: {args.max_characters}")
    
    # Criar instância e executar
    auto_loader = TaleonAutoLoaderAPI(
        api_base_url=args.api_url,
        mode=mode
    )
    
    try:
        stats = auto_loader.run_auto_load(max_characters_per_site=args.max_characters)
        
        # Retornar código de saída baseado no sucesso
        if stats['sites_failed'] == 0 and stats['characters_failed'] == 0:
            logger.info("✅ Execução concluída com sucesso total")
            sys.exit(0)
        elif stats['characters_added'] > 0:
            logger.info("⚠️ Execução concluída com alguns problemas")
            sys.exit(1)
        else:
            logger.error("❌ Execução falhou completamente")
            sys.exit(2)
            
    except KeyboardInterrupt:
        logger.info("⏹️ Execução interrompida pelo usuário")
        sys.exit(130)
    except Exception as e:
        logger.error(f"❌ Erro fatal: {e}", exc_info=True)
        sys.exit(1)


if __name__ == "__main__":
    main() 