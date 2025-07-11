#!/usr/bin/env python3
"""
Script de Carregamento Automático de Personagens - Versão Oficial
=================================================================

Este script faz scraping de múltiplos sites do Taleon para obter listas de personagens
e automaticamente os adiciona ao sistema via API.

Usa a classe TaleonCharacterScraper oficial do backend para garantir consistência
e aproveitar todo o tratamento robusto já implementado.

Uso:
    python3 auto-load-new-chars-official.py                    # Executa todos os sites
    python3 auto-load-new-chars-official.py --deaths-only      # Apenas sites de mortes (3 dias)
    python3 auto-load-new-chars-official.py --powergamers-only # Apenas powergamers (diário)
    python3 auto-load-new-chars-official.py --online-only      # Apenas online (1h)
    python3 auto-load-new-chars-official.py --help             # Mostra ajuda
"""

import asyncio
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
import aiohttp

# Adicionar o diretório do backend ao path para importar os módulos
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', 'Backend'))

# Importar a classe oficial do scraper
from app.services.scraping.taleon import TaleonCharacterScraper

# Configuração de logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('auto-load-new-chars-official.log'),
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


class TaleonAutoLoaderOfficial:
    """Classe principal para carregamento automático de personagens (versão oficial)"""
    
    def __init__(self, api_base_url: str = "http://localhost:8000", mode: str = "all"):
        self.api_base_url = api_base_url
        self.mode = mode  # all, deaths-only, powergamers-only, online-only
        
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
    
    async def scrape_site_characters(self, site: TaleonSite) -> ScrapingResult:
        """Fazer scraping de personagens de um site específico usando aiohttp"""
        start_time = time.time()
        
        try:
            logger.info(f"🔍 Iniciando scraping de {site.name}: {site.character_list_url}")
            
            # Usar aiohttp para fazer a requisição (mesmo sistema do scraper oficial)
            timeout = aiohttp.ClientTimeout(total=site.timeout_seconds)
            headers = {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
                'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
                'Accept-Language': 'pt-BR,pt;q=0.9,en;q=0.8',
                'Accept-Encoding': 'gzip, deflate, br',
                'Connection': 'keep-alive',
                'Upgrade-Insecure-Requests': '1',
            }
            
            async with aiohttp.ClientSession(timeout=timeout, headers=headers) as session:
                async with session.get(site.character_list_url) as response:
                    if response.status != 200:
                        error_msg = f"Erro HTTP {response.status} ao acessar {site.character_list_url}"
                        logger.error(f"❌ {error_msg}")
                        return ScrapingResult(
                            site=site,
                            success=False,
                            characters_found=0,
                            characters_list=[],
                            error_message=error_msg
                        )
                    
                    html = await response.text()
                    
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
                    
        except asyncio.TimeoutError:
            error_msg = f"Timeout ao acessar {site.character_list_url}"
            logger.error(f"❌ {error_msg}")
            return ScrapingResult(
                site=site,
                success=False,
                characters_found=0,
                characters_list=[],
                error_message=error_msg
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
    
    async def add_character_via_api(self, character_name: str, world: str) -> APIResult:
        """Adicionar personagem via API usando o scraper oficial"""
        start_time = time.time()
        
        try:
            logger.info(f"🎯 Adicionando personagem: {character_name} ({world})")
            
            # Usar o scraper oficial do Taleon
            async with TaleonCharacterScraper() as scraper:
                # Fazer scraping do personagem
                result = await scraper.scrape_character(world, character_name)
                
                if result.success:
                    # Personagem foi encontrado e processado com sucesso
                    duration_ms = int((time.time() - start_time) * 1000)
                    
                    logger.info(f"✅ {character_name} ({world}): Adicionado com sucesso em {duration_ms}ms")
                    
                    return APIResult(
                        character_name=character_name,
                        success=True,
                        character_id=None,  # O scraper não retorna ID, mas sim os dados
                        duration_ms=duration_ms,
                        from_database=False  # Sempre do scraping
                    )
                else:
                    # Erro no scraping
                    duration_ms = int((time.time() - start_time) * 1000)
                    
                    logger.warning(f"⚠️ {character_name} ({world}): {result.error_message}")
                    
                    return APIResult(
                        character_name=character_name,
                        success=False,
                        error_message=result.error_message,
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
    
    async def run_auto_load(self, max_characters_per_site: int = 100) -> Dict:
        """Executar o carregamento automático de personagens"""
        self.stats['start_time'] = datetime.now()
        
        logger.info(f"🚀 Iniciando carregamento automático de personagens (modo: {self.mode})")
        logger.info(f"📊 Sites configurados: {len(self.taleon_sites)}")
        
        # Filtrar sites baseado no modo
        sites_to_process = self._filter_sites_by_mode(self.taleon_sites)
        logger.info(f"🎯 Sites para processar: {len(sites_to_process)}")
        
        # Processar cada site
        all_characters = set()  # Usar set para evitar duplicatas
        
        for site in sites_to_process:
            logger.info(f"🌐 Processando {site.name}...")
            
            # Fazer scraping do site
            scraping_result = await self.scrape_site_characters(site)
            
            if scraping_result.success:
                self.stats['sites_scraped'] += 1
                
                # Limitar número de personagens por site
                characters_to_process = scraping_result.characters_list[:max_characters_per_site]
                all_characters.update(characters_to_process)
                
                logger.info(f"✅ {site.name}: {len(characters_to_process)} personagens para processar")
                
                # Delay entre sites
                if site.delay_seconds > 0:
                    logger.debug(f"⏳ Aguardando {site.delay_seconds}s antes do próximo site...")
                    await asyncio.sleep(site.delay_seconds)
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
                api_result = await self.add_character_via_api(character_name, world)
                
                if api_result.success:
                    self.stats['characters_added'] += 1
                else:
                    self.stats['characters_failed'] += 1
            else:
                logger.warning(f"⚠️ Não foi possível determinar o mundo para {character_name}")
                self.stats['characters_failed'] += 1
            
            # Delay entre personagens para não sobrecarregar
            await asyncio.sleep(1.0)
        
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
        description="Script de carregamento automático de personagens do Taleon (versão oficial)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Exemplos de uso:
  python3 auto-load-new-chars-official.py                    # Executa todos os sites
  python3 auto-load-new-chars-official.py --deaths-only      # Apenas sites de mortes
  python3 auto-load-new-chars-official.py --powergamers-only # Apenas powergamers
  python3 auto-load-new-chars-official.py --online-only      # Apenas online
  python3 auto-load-new-chars-official.py --api-url http://localhost:8000
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


async def main():
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
    auto_loader = TaleonAutoLoaderOfficial(
        api_base_url=args.api_url,
        mode=mode
    )
    
    try:
        stats = await auto_loader.run_auto_load(max_characters_per_site=args.max_characters)
        
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
    asyncio.run(main()) 