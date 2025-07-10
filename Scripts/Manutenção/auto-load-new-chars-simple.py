#!/usr/bin/env python3
"""
Script de Carregamento Automático de Personagens - Versão Simplificada
======================================================================

Este script faz scraping de múltiplos sites do Taleon para obter listas de personagens
e automaticamente os adiciona ao sistema via API.

Usa apenas bibliotecas padrão do Python (urllib, re) sem dependências externas.

Uso:
    python3 auto-load-new-chars-simple.py                    # Executa todos os sites
    python3 auto-load-new-chars-simple.py --deaths-only      # Apenas sites de mortes (3 dias)
    python3 auto-load-new-chars-simple.py --powergamers-only # Apenas powergamers (diário)
    python3 auto-load-new-chars-simple.py --online-only      # Apenas online (1h)
    python3 auto-load-new-chars-simple.py --help             # Mostra ajuda
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
        logging.FileHandler('auto-load-new-chars-simple.log'),
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


class TaleonAutoLoaderSimple:
    """Classe principal para carregamento automático de personagens (versão simplificada)"""
    
    def __init__(self, api_base_url: str = "http://localhost:8000", mode: str = "all"):
        self.api_base_url = api_base_url
        self.mode = mode  # all, deaths-only, powergamers-only, online-only
        
        # Headers HTTP
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
        
        logger.info(f"🎯 Configurados {len(sites)} sites do Taleon para scraping")
        return sites
    
    def _filter_sites_by_mode(self, sites: List[TaleonSite]) -> List[TaleonSite]:
        """Filtrar sites baseado no modo de execução"""
        
        if self.mode == "all":
            return sites
        
        filtered_sites = []
        
        for site in sites:
            if self.mode == "deaths-only" and "deaths" in site.character_list_url:
                filtered_sites.append(site)
            elif self.mode == "powergamers-only" and "powergamers" in site.character_list_url:
                filtered_sites.append(site)
            elif self.mode == "online-only" and "onlinelist" in site.character_list_url:
                filtered_sites.append(site)
        
        logger.info(f"🎯 Modo '{self.mode}': {len(filtered_sites)} sites selecionados")
        return filtered_sites
    
    def _extract_character_name_from_url(self, href: str) -> Optional[str]:
        """Extrair nome do personagem diretamente da URL characterprofile.php?name="""
        try:
            # Padrão: characterprofile.php?name=Nome%20do%20Personagem
            match = re.search(r'characterprofile\.php\?name=([^&]+)', href)
            if match:
                # Decodificar URL encoding (ex: %20 -> espaço)
                character_name = urllib.parse.unquote(match.group(1))
                return character_name.strip()
        except Exception as e:
            logger.debug(f"Erro ao extrair nome da URL {href}: {e}")
        return None
    
    def _make_request(self, url: str) -> Optional[str]:
        """Fazer requisição HTTP usando urllib"""
        try:
            req = urllib.request.Request(url, headers=self.headers)
            with urllib.request.urlopen(req, timeout=self.timeout_seconds) as response:
                return response.read().decode('utf-8')
        except urllib.error.HTTPError as e:
            logger.error(f"❌ HTTP Error {e.code}: {url}")
            return None
        except urllib.error.URLError as e:
            logger.error(f"❌ URL Error: {e.reason}")
            return None
        except Exception as e:
            logger.error(f"❌ Request Error: {e}")
            return None
    
    def scrape_site_characters(self, site: TaleonSite) -> ScrapingResult:
        """Fazer scraping de personagens de um site específico"""
        
        start_time = time.time()
        characters = []
        
        try:
            logger.info(f"🔍 [{site.name}] Iniciando scraping: {site.character_list_url}")
            
            # Fazer requisição
            html = self._make_request(site.character_list_url)
            if not html:
                return ScrapingResult(
                    site=site,
                    success=False,
                    characters_found=0,
                    characters_list=[],
                    error_message="Falha na requisição HTTP",
                    duration_ms=int((time.time() - start_time) * 1000)
                )
            
            # Extrair personagens baseado no tipo de site
            if "deaths" in site.character_list_url:
                characters = self._extract_from_deaths(html, site)
            elif "powergamers" in site.character_list_url:
                characters = self._extract_from_powergamers(html, site)
            elif "onlinelist" in site.character_list_url:
                characters = self._extract_from_onlinelist(html, site)
            else:
                characters = self._extract_generic_characters(html, site)
            
            duration_ms = int((time.time() - start_time) * 1000)
            
            logger.info(f"✅ [{site.name}] Scraping concluído: {len(characters)} personagens encontrados em {duration_ms}ms")
            
            return ScrapingResult(
                site=site,
                success=True,
                characters_found=len(characters),
                characters_list=characters,
                duration_ms=duration_ms
            )
                
        except Exception as e:
            duration_ms = int((time.time() - start_time) * 1000)
            logger.error(f"❌ [{site.name}] Erro no scraping: {e}")
            
            return ScrapingResult(
                site=site,
                success=False,
                characters_found=0,
                characters_list=[],
                error_message=str(e),
                duration_ms=duration_ms
            )
    
    def _extract_from_deaths(self, html: str, site: TaleonSite) -> List[str]:
        """Extrair personagens da página de últimas mortes"""
        characters = []
        
        try:
            # Procurar por links de personagens usando regex
            pattern = r'href="([^"]*characterprofile\.php\?name=[^"]*)"'
            matches = re.findall(pattern, html)
            
            for href in matches:
                character_name = self._extract_character_name_from_url(href)
                if character_name and len(character_name) > 2:
                    characters.append(character_name)
            
            # Remover duplicatas
            characters = list(set(characters))
            logger.debug(f"📊 [{site.name}] Extraídos {len(characters)} personagens das mortes")
            
        except Exception as e:
            logger.error(f"❌ [{site.name}] Erro ao extrair mortes: {e}")
        
        return characters
    
    def _extract_from_powergamers(self, html: str, site: TaleonSite) -> List[str]:
        """Extrair personagens da página de powergamers"""
        characters = []
        
        try:
            # Procurar por links de personagens usando regex
            pattern = r'href="([^"]*characterprofile\.php\?name=[^"]*)"'
            matches = re.findall(pattern, html)
            
            for href in matches:
                character_name = self._extract_character_name_from_url(href)
                if character_name and len(character_name) > 2:
                    characters.append(character_name)
            
            # Remover duplicatas
            characters = list(set(characters))
            logger.debug(f"📊 [{site.name}] Extraídos {len(characters)} personagens dos powergamers")
            
        except Exception as e:
            logger.error(f"❌ [{site.name}] Erro ao extrair powergamers: {e}")
        
        return characters
    
    def _extract_from_onlinelist(self, html: str, site: TaleonSite) -> List[str]:
        """Extrair personagens da lista de jogadores online"""
        characters = []
        
        try:
            # Procurar por links de personagens usando regex
            pattern = r'href="([^"]*characterprofile\.php\?name=[^"]*)"'
            matches = re.findall(pattern, html)
            
            for href in matches:
                character_name = self._extract_character_name_from_url(href)
                if character_name and len(character_name) > 2:
                    characters.append(character_name)
            
            # Remover duplicatas
            characters = list(set(characters))
            logger.debug(f"📊 [{site.name}] Extraídos {len(characters)} personagens da lista online")
            
        except Exception as e:
            logger.error(f"❌ [{site.name}] Erro ao extrair lista online: {e}")
        
        return characters
    
    def _extract_generic_characters(self, html: str, site: TaleonSite) -> List[str]:
        """Extração genérica de personagens"""
        characters = []
        
        try:
            # Procurar por qualquer link de personagem
            pattern = r'href="([^"]*characterprofile\.php\?name=[^"]*)"'
            matches = re.findall(pattern, html)
            
            for href in matches:
                character_name = self._extract_character_name_from_url(href)
                if character_name and len(character_name) > 2:
                    characters.append(character_name)
            
            # Remover duplicatas
            characters = list(set(characters))
            logger.debug(f"📊 [{site.name}] Extraídos {len(characters)} personagens (método genérico)")
            
        except Exception as e:
            logger.error(f"❌ [{site.name}] Erro na extração genérica: {e}")
        
        return characters
    
    def add_character_via_api(self, character_name: str, world: str) -> APIResult:
        """Adicionar personagem via API"""
        
        start_time = time.time()
        
        try:
            # URL da API
            api_url = f"{self.api_base_url}/api/v1/characters/search"
            params = {
                'name': character_name,
                'server': 'taleon',
                'world': world
            }
            
            # Construir URL com parâmetros
            query_string = urllib.parse.urlencode(params)
            full_url = f"{api_url}?{query_string}"
            
            logger.debug(f"🌐 Adicionando personagem via API: {character_name} ({world})")
            
            # Fazer requisição
            req = urllib.request.Request(full_url, headers=self.headers)
            with urllib.request.urlopen(req, timeout=30) as response:
                duration_ms = int((time.time() - start_time) * 1000)
                
                if response.status == 200:
                    data = json.loads(response.read().decode('utf-8'))
                    
                    if data.get('success'):
                        character_id = data['character']['id']
                        from_database = data.get('from_database', False)
                        
                        if from_database:
                            logger.debug(f"ℹ️ {character_name} já existe no banco (ID: {character_id})")
                        else:
                            logger.info(f"✅ {character_name} adicionado com sucesso (ID: {character_id})")
                        
                        return APIResult(
                            character_name=character_name,
                            success=True,
                            character_id=character_id,
                            duration_ms=duration_ms,
                            from_database=from_database
                        )
                    else:
                        logger.warning(f"⚠️ API retornou erro para {character_name}: {data.get('message', 'Erro desconhecido')}")
                        return APIResult(
                            character_name=character_name,
                            success=False,
                            error_message=data.get('message', 'Erro desconhecido'),
                            duration_ms=duration_ms
                        )
                else:
                    error_text = response.read().decode('utf-8')
                    logger.error(f"❌ HTTP {response.status} para {character_name}: {error_text}")
                    return APIResult(
                        character_name=character_name,
                        success=False,
                        error_message=f"HTTP {response.status}: {error_text}",
                        duration_ms=duration_ms
                    )
        
        except Exception as e:
            duration_ms = int((time.time() - start_time) * 1000)
            logger.error(f"❌ Erro ao adicionar {character_name}: {e}")
            return APIResult(
                character_name=character_name,
                success=False,
                error_message=str(e),
                duration_ms=duration_ms
            )
    
    def run_auto_load(self, max_characters_per_site: int = 100) -> Dict:
        """Executar o carregamento automático completo"""
        
        self.stats['start_time'] = datetime.now()
        logger.info("🚀 Iniciando carregamento automático de personagens...")
        
        all_characters: Set[str] = set()
        scraping_results = []
        api_results = []
        
        try:
            # 1. Filtrar sites baseado no modo
            sites_to_process = self._filter_sites_by_mode(self.taleon_sites)
            
            # 2. Fazer scraping dos sites selecionados
            for site in sites_to_process:
                if not site.enabled:
                    logger.info(f"⏭️ [{site.name}] Site desabilitado, pulando...")
                    continue
                
                logger.info(f"🌐 [{site.name}] Processando site...")
                
                # Fazer scraping
                result = self.scrape_site_characters(site)
                scraping_results.append(result)
                
                if result.success:
                    self.stats['sites_scraped'] += 1
                    
                    # Adicionar personagens à lista geral (limitando por site)
                    site_characters = result.characters_list[:max_characters_per_site]
                    all_characters.update(site_characters)
                    
                    logger.info(f"📊 [{site.name}] {len(site_characters)} personagens adicionados à lista geral")
                else:
                    self.stats['sites_failed'] += 1
                    logger.error(f"❌ [{site.name}] Falha no scraping: {result.error_message}")
                
                # Delay entre sites
                time.sleep(site.delay_seconds)
            
            # 3. Adicionar personagens via API
            logger.info(f"🎯 Total de {len(all_characters)} personagens únicos encontrados")
            self.stats['total_characters_found'] = len(all_characters)
            
            # Agrupar por mundo
            characters_by_world = {}
            for character in all_characters:
                # Determinar mundo baseado no contexto (simplificado por enquanto)
                # TODO: Implementar lógica mais sofisticada para determinar o mundo
                world = "san"  # Default - será melhorado
                if world not in characters_by_world:
                    characters_by_world[world] = []
                characters_by_world[world].append(character)
            
            # Adicionar personagens por mundo
            for world, characters in characters_by_world.items():
                logger.info(f"🌍 Processando {len(characters)} personagens do mundo {world}")
                
                for i, character_name in enumerate(characters):
                    # Adicionar via API
                    api_result = self.add_character_via_api(character_name, world)
                    api_results.append(api_result)
                    
                    # Atualizar estatísticas
                    if api_result.success:
                        if api_result.from_database:
                            self.stats['characters_already_exist'] += 1
                        else:
                            self.stats['characters_added'] += 1
                    else:
                        self.stats['characters_failed'] += 1
                    
                    # Log de progresso
                    if (i + 1) % 10 == 0:
                        logger.info(f"📈 Progresso {world}: {i + 1}/{len(characters)} personagens processados")
                    
                    # Delay entre personagens para não sobrecarregar a API
                    time.sleep(1.0)
            
            # 4. Gerar relatório final
            self.stats['end_time'] = datetime.now()
            duration = self.stats['end_time'] - self.stats['start_time']
            
            logger.info("🎉 Carregamento automático concluído!")
            logger.info(f"📊 Relatório Final:")
            logger.info(f"   ⏱️  Duração total: {duration}")
            logger.info(f"   🌐 Sites processados: {self.stats['sites_scraped']}")
            logger.info(f"   ❌ Sites com falha: {self.stats['sites_failed']}")
            logger.info(f"   👥 Personagens encontrados: {self.stats['total_characters_found']}")
            logger.info(f"   ✅ Personagens adicionados: {self.stats['characters_added']}")
            logger.info(f"   ℹ️  Personagens já existentes: {self.stats['characters_already_exist']}")
            logger.info(f"   ❌ Personagens com falha: {self.stats['characters_failed']}")
            
            return {
                'success': True,
                'stats': self.stats,
                'scraping_results': [r.__dict__ for r in scraping_results],
                'api_results': [r.__dict__ for r in api_results]
            }
            
        except Exception as e:
            logger.error(f"❌ Erro fatal no carregamento automático: {e}")
            return {
                'success': False,
                'error': str(e),
                'stats': self.stats
            }


def parse_arguments():
    """Processar argumentos de linha de comando"""
    parser = argparse.ArgumentParser(
        description="Script de Carregamento Automático de Personagens - Versão Simplificada",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Exemplos de uso:
  python3 auto-load-new-chars-simple.py                    # Executa todos os sites
  python3 auto-load-new-chars-simple.py --deaths-only      # Apenas sites de mortes (3 dias)
  python3 auto-load-new-chars-simple.py --powergamers-only # Apenas powergamers (diário)
  python3 auto-load-new-chars-simple.py --online-only      # Apenas online (1h)
        """
    )
    
    # Argumentos exclusivos (apenas um pode ser usado)
    group = parser.add_mutually_exclusive_group()
    group.add_argument(
        '--deaths-only',
        action='store_true',
        help='Executar apenas sites de mortes (recomendado: a cada 3 dias)'
    )
    group.add_argument(
        '--powergamers-only',
        action='store_true',
        help='Executar apenas sites de powergamers (recomendado: diário)'
    )
    group.add_argument(
        '--online-only',
        action='store_true',
        help='Executar apenas sites de online (recomendado: a cada 1h)'
    )
    
    # Argumentos opcionais
    parser.add_argument(
        '--api-url',
        default='http://localhost:8000',
        help='URL base da API (padrão: http://localhost:8000)'
    )
    parser.add_argument(
        '--max-chars',
        type=int,
        default=50,
        help='Máximo de personagens por site (padrão: 50)'
    )
    
    return parser.parse_args()


def main():
    """Função principal"""
    
    # Processar argumentos
    args = parse_arguments()
    
    # Determinar modo baseado nos argumentos
    mode = "all"
    if args.deaths_only:
        mode = "deaths-only"
    elif args.powergamers_only:
        mode = "powergamers-only"
    elif args.online_only:
        mode = "online-only"
    
    logger.info("🎯 Script de Carregamento Automático de Personagens - Versão Simplificada")
    logger.info("=" * 80)
    logger.info(f"🔧 Modo de execução: {mode}")
    logger.info(f"🌐 API URL: {args.api_url}")
    logger.info(f"📊 Máximo de personagens por site: {args.max_chars}")
    logger.info("=" * 80)
    
    try:
        loader = TaleonAutoLoaderSimple(api_base_url=args.api_url, mode=mode)
        result = loader.run_auto_load(max_characters_per_site=args.max_chars)
        
        if result['success']:
            logger.info("✅ Script executado com sucesso!")
            return 0
        else:
            logger.error(f"❌ Script falhou: {result['error']}")
            return 1
            
    except Exception as e:
        logger.error(f"❌ Erro fatal: {e}")
        return 1


if __name__ == "__main__":
    exit_code = main()
    sys.exit(exit_code) 