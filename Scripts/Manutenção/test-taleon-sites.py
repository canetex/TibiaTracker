#!/usr/bin/env python3
"""
Script de Teste dos Sites do Taleon
===================================

Este script testa a acessibilidade e estrutura dos sites do Taleon
para validar se o scraping automático funcionará corretamente.
"""

import asyncio
import aiohttp
import json
import sys
import os
from datetime import datetime
from typing import Dict, List, Optional
from dataclasses import dataclass
from urllib.parse import urljoin, unquote
import re
from bs4 import BeautifulSoup

# Configuração de logging
import logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


@dataclass
class SiteTestResult:
    """Resultado do teste de um site"""
    site_id: str
    site_name: str
    url: str
    accessible: bool
    status_code: Optional[int] = None
    response_time_ms: Optional[int] = None
    characters_found: int = 0
    sample_characters: List[str] = None
    error_message: Optional[str] = None
    html_structure: Optional[Dict] = None


class TaleonSiteTester:
    """Classe para testar sites do Taleon"""
    
    def __init__(self, config_file: str = "taleon-sites-config.json"):
        self.config_file = config_file
        self.config = self._load_config()
        self.session: Optional[aiohttp.ClientSession] = None
    
    def _load_config(self) -> Dict:
        """Carregar configuração dos sites"""
        try:
            with open(self.config_file, 'r', encoding='utf-8') as f:
                config = json.load(f)
            logger.info(f"✅ Configuração carregada: {self.config_file}")
            return config
        except FileNotFoundError:
            logger.error(f"❌ Arquivo de configuração não encontrado: {self.config_file}")
            sys.exit(1)
        except json.JSONDecodeError as e:
            logger.error(f"❌ Erro ao parsear JSON: {e}")
            sys.exit(1)
    
    async def __aenter__(self):
        """Context manager entry"""
        timeout = aiohttp.ClientTimeout(total=60)
        connector = aiohttp.TCPConnector(
            limit=10,
            ttl_dns_cache=300,
            use_dns_cache=True
        )
        
        self.session = aiohttp.ClientSession(
            timeout=timeout,
            headers={
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
                'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
                'Accept-Language': 'pt-BR,pt;q=0.9,en;q=0.8',
                'Accept-Encoding': 'gzip, deflate, br',
                'Connection': 'keep-alive',
                'Upgrade-Insecure-Requests': '1',
            },
            connector=connector
        )
        return self
    
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit"""
        if self.session:
            await self.session.close()
    
    async def test_site(self, site_config: Dict) -> SiteTestResult:
        """Testar um site específico"""
        
        import time
        start_time = time.time()
        
        site_id = site_config['id']
        site_name = site_config['name']
        url = site_config['character_list_url']
        
        logger.info(f"🔍 Testando site: {site_name} ({url})")
        
        try:
            # Fazer requisição
            async with self.session.get(url) as response:
                response_time_ms = int((time.time() - start_time) * 1000)
                
                if response.status != 200:
                    return SiteTestResult(
                        site_id=site_id,
                        site_name=site_name,
                        url=url,
                        accessible=False,
                        status_code=response.status,
                        response_time_ms=response_time_ms,
                        error_message=f"HTTP {response.status}"
                    )
                
                # Ler HTML
                html = await response.text()
                soup = BeautifulSoup(html, 'lxml')
                
                # Analisar estrutura
                html_structure = self._analyze_html_structure(soup, site_config)
                
                # Extrair personagens de teste
                characters = await self._extract_test_characters(soup, site_config)
                
                return SiteTestResult(
                    site_id=site_id,
                    site_name=site_name,
                    url=url,
                    accessible=True,
                    status_code=response.status,
                    response_time_ms=response_time_ms,
                    characters_found=len(characters),
                    sample_characters=characters[:5],  # Primeiros 5 como exemplo
                    html_structure=html_structure
                )
                
        except Exception as e:
            response_time_ms = int((time.time() - start_time) * 1000)
            logger.error(f"❌ Erro ao testar {site_name}: {e}")
            
            return SiteTestResult(
                site_id=site_id,
                site_name=site_name,
                url=url,
                accessible=False,
                response_time_ms=response_time_ms,
                error_message=str(e)
            )
    
    def _analyze_html_structure(self, soup: BeautifulSoup, site_config: Dict) -> Dict:
        """Analisar estrutura HTML da página"""
        
        structure = {
            'title': soup.find('title').get_text().strip() if soup.find('title') else None,
            'tables_count': len(soup.find_all('table')),
            'links_count': len(soup.find_all('a')),
            'character_links_count': len(soup.find_all('a', href=re.compile(r'characterprofile\.php\?name='))),
            'guild_links_count': len(soup.find_all('a', href=re.compile(r'guilds\.php\?name='))),
            'house_links_count': len(soup.find_all('a', href=re.compile(r'houses\.php\?house='))),
            'forms_count': len(soup.find_all('form')),
            'has_navigation': bool(soup.find('nav') or soup.find('ul', class_=re.compile(r'nav|menu'))),
            'has_search': bool(soup.find('input', type='search') or soup.find('input', name=re.compile(r'search|q'))),
        }
        
        return structure
    
    async def _extract_test_characters(self, soup: BeautifulSoup, site_config: Dict) -> List[str]:
        """Extrair personagens de teste baseado no método de scraping"""
        
        characters = []
        scraping_method = site_config.get('scraping_method', 'generic')
        
        try:
            if scraping_method == 'deaths':
                characters = self._extract_from_deaths_test(soup)
            elif scraping_method == 'powergamers':
                characters = self._extract_from_powergamers_test(soup)
            elif scraping_method == 'onlinelist':
                characters = self._extract_from_onlinelist_test(soup)
            else:
                characters = self._extract_generic_test(soup)
            
            # Remover duplicatas e limpar
            characters = list(set([c.strip() for c in characters if c.strip() and len(c.strip()) > 2]))
            
        except Exception as e:
            logger.warning(f"⚠️ Erro ao extrair personagens de teste: {e}")
        
        return characters
    
    def _extract_character_name_from_url_test(self, href: str) -> Optional[str]:
        """Extrair nome do personagem diretamente da URL characterprofile.php?name="""
        try:
            # Padrão: characterprofile.php?name=Nome%20do%20Personagem
            match = re.search(r'characterprofile\.php\?name=([^&]+)', href)
            if match:
                # Decodificar URL encoding (ex: %20 -> espaço)
                character_name = unquote(match.group(1))
                return character_name.strip()
        except Exception as e:
            pass
        return None
    
    def _extract_from_deaths_test(self, soup: BeautifulSoup) -> List[str]:
        """Extrair personagens das mortes (teste)"""
        characters = []
        
        # Procurar por links de personagens em tabelas
        tables = soup.find_all('table')
        for table in tables:
            links = table.find_all('a', href=re.compile(r'characterprofile\.php\?name='))
            for link in links:
                href = link.get('href', '')
                character_name = self._extract_character_name_from_url_test(href)
                if character_name:
                    characters.append(character_name)
        
        return characters
    
    def _extract_from_powergamers_test(self, soup: BeautifulSoup) -> List[str]:
        """Extrair personagens dos powergamers (teste)"""
        characters = []
        
        # Procurar por links de personagens em tabelas
        tables = soup.find_all('table')
        for table in tables:
            links = table.find_all('a', href=re.compile(r'characterprofile\.php\?name='))
            for link in links:
                href = link.get('href', '')
                character_name = self._extract_character_name_from_url_test(href)
                if character_name:
                    characters.append(character_name)
        
        return characters
    
    def _extract_from_guilds_test(self, soup: BeautifulSoup) -> List[str]:
        """Extrair personagens das guilds (teste)"""
        characters = []
        
        # Procurar por links de guilds
        guild_links = soup.find_all('a', href=re.compile(r'guilds\.php\?name='))
        for link in guild_links:
            guild_name = link.get_text().strip()
            if guild_name:
                characters.append(f"[GUILD] {guild_name}")
        
        # Procurar por links de personagens (membros)
        member_links = soup.find_all('a', href=re.compile(r'characterprofile\.php\?name='))
        for link in member_links:
            character_name = link.get_text().strip()
            if character_name:
                characters.append(character_name)
        
        return characters
    
    def _extract_from_houses_test(self, soup: BeautifulSoup) -> List[str]:
        """Extrair personagens das houses (teste)"""
        characters = []
        
        # Procurar por links de casas
        house_links = soup.find_all('a', href=re.compile(r'houses\.php\?house='))
        for link in house_links:
            house_name = link.get_text().strip()
            if house_name:
                characters.append(f"[HOUSE] {house_name}")
        
        # Procurar por proprietários
        owner_links = soup.find_all('a', href=re.compile(r'characterprofile\.php\?name='))
        for link in owner_links:
            character_name = link.get_text().strip()
            if character_name:
                characters.append(character_name)
        
        return characters
    
    def _extract_from_online_test(self, soup: BeautifulSoup) -> List[str]:
        """Extrair personagens online (teste)"""
        characters = []
        
        # Procurar por links de personagens online
        online_links = soup.find_all('a', href=re.compile(r'characterprofile\.php\?name='))
        for link in online_links:
            character_name = link.get_text().strip()
            if character_name:
                characters.append(character_name)
        
        return characters
    
    def _extract_from_onlinelist_test(self, soup: BeautifulSoup) -> List[str]:
        """Extrair personagens da lista online (teste)"""
        characters = []
        
        # Procurar por links de personagens em tabelas (primeira coluna)
        tables = soup.find_all('table')
        for table in tables:
            rows = table.find_all('tr')
            for row in rows:
                cells = row.find_all(['td', 'th'])
                if cells:
                    # Procurar na primeira coluna (nome do personagem)
                    first_cell = cells[0]
                    links = first_cell.find_all('a', href=re.compile(r'characterprofile\.php\?name='))
                    for link in links:
                        href = link.get('href', '')
                        character_name = self._extract_character_name_from_url_test(href)
                        if character_name:
                            characters.append(character_name)
        
        return characters
    
    def _extract_generic_test(self, soup: BeautifulSoup) -> List[str]:
        """Extração genérica de personagens (teste)"""
        characters = []
        
        # Procurar por qualquer link de personagem
        character_links = soup.find_all('a', href=re.compile(r'characterprofile\.php\?name='))
        for link in character_links:
            href = link.get('href', '')
            character_name = self._extract_character_name_from_url_test(href)
            if character_name:
                characters.append(character_name)
        
        return characters
    
    async def test_all_sites(self) -> List[SiteTestResult]:
        """Testar todos os sites configurados"""
        
        logger.info("🚀 Iniciando testes de todos os sites do Taleon...")
        
        sites = self.config['taleon_sites']['sites']
        results = []
        
        for site_config in sites:
            if not site_config.get('enabled', True):
                logger.info(f"⏭️ Site {site_config['name']} desabilitado, pulando...")
                continue
            
            result = await self.test_site(site_config)
            results.append(result)
            
            # Delay entre testes
            await asyncio.sleep(2.0)
        
        return results
    
    def generate_report(self, results: List[SiteTestResult]) -> str:
        """Gerar relatório dos testes"""
        
        report = []
        report.append("🎯 RELATÓRIO DE TESTES DOS SITES DO TALEON")
        report.append("=" * 60)
        report.append(f"📅 Data: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        report.append(f"🌐 Total de sites testados: {len(results)}")
        report.append("")
        
        # Estatísticas gerais
        accessible_sites = [r for r in results if r.accessible]
        failed_sites = [r for r in results if not r.accessible]
        total_characters = sum(r.characters_found for r in results)
        
        report.append("📊 ESTATÍSTICAS GERAIS:")
        report.append(f"   ✅ Sites acessíveis: {len(accessible_sites)}")
        report.append(f"   ❌ Sites com falha: {len(failed_sites)}")
        report.append(f"   👥 Total de personagens encontrados: {total_characters}")
        report.append("")
        
        # Sites por mundo
        worlds = {}
        for result in results:
            world = result.site_name.split()[-1].lower()  # Extrair mundo do nome
            if world not in worlds:
                worlds[world] = {'accessible': 0, 'failed': 0, 'characters': 0}
            
            if result.accessible:
                worlds[world]['accessible'] += 1
                worlds[world]['characters'] += result.characters_found
            else:
                worlds[world]['failed'] += 1
        
        report.append("🌍 SITES POR MUNDO:")
        for world, stats in worlds.items():
            report.append(f"   {world.upper()}: {stats['accessible']} acessíveis, {stats['failed']} falhas, {stats['characters']} personagens")
        report.append("")
        
        # Detalhes por site
        report.append("🔍 DETALHES POR SITE:")
        report.append("-" * 60)
        
        for result in results:
            status_icon = "✅" if result.accessible else "❌"
            report.append(f"{status_icon} {result.site_name}")
            report.append(f"   URL: {result.url}")
            
            if result.accessible:
                report.append(f"   Status: HTTP {result.status_code}")
                report.append(f"   Tempo de resposta: {result.response_time_ms}ms")
                report.append(f"   Personagens encontrados: {result.characters_found}")
                
                if result.sample_characters:
                    report.append(f"   Exemplos: {', '.join(result.sample_characters[:3])}")
                
                if result.html_structure:
                    structure = result.html_structure
                    report.append(f"   Estrutura: {structure['tables_count']} tabelas, {structure['links_count']} links")
            else:
                report.append(f"   Erro: {result.error_message}")
            
            report.append("")
        
        # Recomendações
        report.append("💡 RECOMENDAÇÕES:")
        if failed_sites:
            report.append("   ⚠️  Alguns sites falharam. Verificar:")
            for site in failed_sites:
                report.append(f"      - {site.site_name}: {site.error_message}")
        else:
            report.append("   ✅ Todos os sites estão acessíveis!")
        
        if total_characters > 0:
            report.append(f"   📈 Total de {total_characters} personagens encontrados - scraping deve funcionar")
        else:
            report.append("   ⚠️  Nenhum personagem encontrado - verificar seletores HTML")
        
        report.append("")
        report.append("🎉 Teste concluído!")
        
        return "\n".join(report)


async def main():
    """Função principal"""
    
    logger.info("🎯 Script de Teste dos Sites do Taleon")
    logger.info("=" * 50)
    
    try:
        async with TaleonSiteTester() as tester:
            # Testar todos os sites
            results = await tester.test_all_sites()
            
            # Gerar relatório
            report = tester.generate_report(results)
            
            # Salvar relatório
            report_file = f"taleon-sites-test-report-{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt"
            with open(report_file, 'w', encoding='utf-8') as f:
                f.write(report)
            
            # Exibir relatório
            print(report)
            
            logger.info(f"📄 Relatório salvo em: {report_file}")
            
            # Retornar código de saída baseado nos resultados
            failed_sites = [r for r in results if not r.accessible]
            if failed_sites:
                logger.warning(f"⚠️ {len(failed_sites)} sites falharam")
                return 1
            else:
                logger.info("✅ Todos os sites estão acessíveis!")
                return 0
                
    except Exception as e:
        logger.error(f"❌ Erro fatal: {e}")
        return 1


if __name__ == "__main__":
    exit_code = asyncio.run(main())
    sys.exit(exit_code) 