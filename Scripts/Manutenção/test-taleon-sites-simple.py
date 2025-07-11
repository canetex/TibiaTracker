#!/usr/bin/env python3
"""
Script de Teste dos Sites do Taleon (Versão Simplificada)
=========================================================

Este script testa a acessibilidade e estrutura dos sites do Taleon
para validar se o scraping automático funcionará corretamente.
Versão simplificada que usa apenas bibliotecas padrão do Python.
"""

import json
import sys
import os
import time
import re
import urllib.request
import urllib.parse
import urllib.error
from datetime import datetime
from typing import Dict, List, Optional
from dataclasses import dataclass

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
    sample_characters: Optional[List[str]] = None
    error_message: Optional[str] = None
    html_structure: Optional[Dict] = None


class TaleonSiteTester:
    """Classe para testar sites do Taleon (versão simplificada)"""
    
    def __init__(self, config_file: str = "taleon-sites-config.json"):
        self.config_file = config_file
        self.config = self._load_config()
        self.headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
            'Accept-Language': 'pt-BR,pt;q=0.9,en;q=0.8',
            'Accept-Encoding': 'gzip, deflate, br',
            'Connection': 'keep-alive',
            'Upgrade-Insecure-Requests': '1',
        }
    
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
    
    def test_site(self, site_config: Dict) -> SiteTestResult:
        """Testar um site específico"""
        
        start_time = time.time()
        
        site_id = site_config['id']
        site_name = site_config['name']
        url = site_config['character_list_url']
        
        logger.info(f"🔍 Testando site: {site_name} ({url})")
        
        try:
            # Criar requisição
            req = urllib.request.Request(url, headers=self.headers)
            
            # Fazer requisição
            with urllib.request.urlopen(req, timeout=60) as response:
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
                html = response.read().decode('utf-8', errors='ignore')
                
                # DEBUG: Salvar HTML para análise
                with open(f'debug-{site_id}.html', 'w', encoding='utf-8') as f:
                    f.write(html)
                print(f"[DEBUG] HTML salvo em debug-{site_id}.html")
                
                # Analisar estrutura
                html_structure = self._analyze_html_structure(html, site_config)
                
                # Extrair personagens de teste
                characters = self._extract_test_characters(html, site_config)

                # DEBUG: Mostrar quantidade e exemplos de personagens extraídos
                print(f"[DEBUG] {site_name}: personagens extraídos = {len(characters)}")
                print(f"[DEBUG] Exemplos: {characters[:5]}")

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
                
        except urllib.error.HTTPError as e:
            response_time_ms = int((time.time() - start_time) * 1000)
            logger.error(f"❌ Erro HTTP ao testar {site_name}: {e.code} - {e.reason}")
            
            return SiteTestResult(
                site_id=site_id,
                site_name=site_name,
                url=url,
                accessible=False,
                status_code=e.code,
                response_time_ms=response_time_ms,
                error_message=f"HTTP {e.code}: {e.reason}"
            )
            
        except urllib.error.URLError as e:
            response_time_ms = int((time.time() - start_time) * 1000)
            logger.error(f"❌ Erro de URL ao testar {site_name}: {e.reason}")
            
            return SiteTestResult(
                site_id=site_id,
                site_name=site_name,
                url=url,
                accessible=False,
                response_time_ms=response_time_ms,
                error_message=f"URL Error: {e.reason}"
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
    
    def _analyze_html_structure(self, html: str, site_config: Dict) -> Dict:
        """Analisar estrutura HTML da página"""
        
        structure = {
            'title': None,
            'tables_count': len(re.findall(r'<table', html, re.IGNORECASE)),
            'links_count': len(re.findall(r'<a\s+href', html, re.IGNORECASE)),
            'character_links_count': len(re.findall(r'characterprofile\.php\?name=', html, re.IGNORECASE)),
            'guild_links_count': len(re.findall(r'guilds\.php\?name=', html, re.IGNORECASE)),
            'house_links_count': len(re.findall(r'houses\.php\?house=', html, re.IGNORECASE)),
            'forms_count': len(re.findall(r'<form', html, re.IGNORECASE)),
            'has_navigation': bool(re.search(r'<nav|<ul[^>]*class[^>]*nav|<ul[^>]*class[^>]*menu', html, re.IGNORECASE)),
            'has_search': bool(re.search(r'<input[^>]*type[^>]*search|<input[^>]*name[^>]*search|<input[^>]*name[^>]*q', html, re.IGNORECASE)),
        }
        
        # Extrair título
        title_match = re.search(r'<title[^>]*>(.*?)</title>', html, re.IGNORECASE | re.DOTALL)
        if title_match:
            structure['title'] = title_match.group(1).strip()
        
        return structure
    
    def _extract_test_characters(self, html: str, site_config: Dict) -> List[str]:
        print(f"[DEBUG] site_config: {site_config}")
        scraping_method = site_config.get('scraping_method', 'generic')
        print(f"[DEBUG] scraping_method: {scraping_method}")
        characters = []
        try:
            if scraping_method == 'deaths':
                characters = self._extract_from_deaths_test(html)
            elif scraping_method == 'powergamers':
                characters = self._extract_from_powergamers_test(html)
            elif scraping_method == 'onlinelist':
                characters = self._extract_from_onlinelist_test(html)
            else:
                characters = self._extract_generic_test(html)
            # Remover duplicatas e limpar
            characters = list(set([c.strip() for c in characters if c.strip() and len(c.strip()) > 2]))
        except Exception as e:
            logger.warning(f"⚠️ Erro ao extrair personagens de teste: {e}")
        return characters
    
    def _extract_from_deaths_test(self, html: str) -> List[str]:
        """Extrair personagens da página de mortes"""
        characters = []
        pattern = r"href='characterprofile\.php\?name=([^']*)'"
        matches = re.findall(pattern, html, re.IGNORECASE)
        for match in matches:
            name = match.strip()
            if name:
                characters.append(name)
        return characters
    
    def _extract_from_powergamers_test(self, html: str) -> List[str]:
        """Extrair personagens da página de powergamers"""
        characters = []
        pattern = r"href='characterprofile\.php\?name=([^']*)'"
        matches = re.findall(pattern, html, re.IGNORECASE)
        for match in matches:
            name = match.strip()
            if name:
                characters.append(name)
        return characters
    
    def _extract_from_onlinelist_test(self, html: str) -> List[str]:
        """Extrair personagens da lista online"""
        characters = []
        pattern = r"href='characterprofile\.php\?name=([^']*)'"
        matches = re.findall(pattern, html, re.IGNORECASE)
        for match in matches:
            name = match.strip()
            if name:
                characters.append(name)
        return characters
    
    def _extract_generic_test(self, html: str) -> List[str]:
        """Extração genérica de personagens"""
        characters = []
        pattern = r"href='characterprofile\.php\?name=([^']*)'"
        matches = re.findall(pattern, html, re.IGNORECASE)
        for match in matches:
            name = match.strip()
            if name:
                characters.append(name)
        return characters
    
    def test_all_sites(self) -> List[SiteTestResult]:
        """Testar todos os sites configurados"""
        results = []
        
        sites = self.config.get('taleon_sites', {}).get('sites', []) or []
        logger.info(f"🚀 Iniciando testes para {len(sites)} sites")
        
        for site_config in sites:
            result = self.test_site(site_config)
            results.append(result)
            
            # Delay entre testes para não sobrecarregar
            time.sleep(2)
        
        return results
    
    def generate_report(self, results: List[SiteTestResult]) -> str:
        """Gerar relatório dos testes"""
        
        report = []
        report.append("=" * 80)
        report.append("RELATÓRIO DE TESTES DOS SITES DO TALEON")
        report.append("=" * 80)
        report.append(f"Data/Hora: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        report.append(f"Total de sites testados: {len(results)}")
        report.append("")
        
        # Resumo
        accessible_sites = [r for r in results if r.accessible]
        inaccessible_sites = [r for r in results if not r.accessible]
        
        report.append("📊 RESUMO:")
        report.append(f"  ✅ Sites acessíveis: {len(accessible_sites)}")
        report.append(f"  ❌ Sites inacessíveis: {len(inaccessible_sites)}")
        report.append(f"  📈 Taxa de sucesso: {(len(accessible_sites)/len(results)*100):.1f}%")
        report.append("")
        
        # Detalhes por site
        report.append("🔍 DETALHES POR SITE:")
        report.append("-" * 80)
        
        for result in results:
            status_icon = "✅" if result.accessible else "❌"
            report.append(f"{status_icon} {result.site_name} ({result.site_id})")
            report.append(f"   URL: {result.url}")
            
            if result.accessible:
                report.append(f"   Status: HTTP {result.status_code}")
                report.append(f"   Tempo de resposta: {result.response_time_ms}ms")
                report.append(f"   Personagens encontrados: {result.characters_found}")
                
                if result.sample_characters:
                    report.append(f"   Exemplos: {', '.join(result.sample_characters)}")
                
                if result.html_structure:
                    structure = result.html_structure
                    report.append(f"   Estrutura HTML:")
                    report.append(f"     - Título: {structure.get('title', 'N/A')}")
                    report.append(f"     - Tabelas: {structure.get('tables_count', 0)}")
                    report.append(f"     - Links: {structure.get('links_count', 0)}")
                    report.append(f"     - Links de personagens: {structure.get('character_links_count', 0)}")
                    report.append(f"     - Links de guildas: {structure.get('guild_links_count', 0)}")
                    report.append(f"     - Formulários: {structure.get('forms_count', 0)}")
            else:
                report.append(f"   Erro: {result.error_message}")
            
            report.append("")
        
        # Recomendações
        report.append("💡 RECOMENDAÇÕES:")
        report.append("-" * 80)
        
        if inaccessible_sites:
            report.append("❌ Sites com problemas:")
            for site in inaccessible_sites:
                report.append(f"  - {site.site_name}: {site.error_message}")
            report.append("")
        
        if accessible_sites:
            report.append("✅ Sites funcionando corretamente:")
            for site in accessible_sites:
                if site.characters_found > 0:
                    report.append(f"  - {site.site_name}: {site.characters_found} personagens encontrados")
                else:
                    report.append(f"  - {site.site_name}: Acessível mas sem personagens encontrados")
            report.append("")
        
        report.append("🎯 PRÓXIMOS PASSOS:")
        report.append("1. Verificar sites inacessíveis")
        report.append("2. Testar extração de personagens específicos")
        report.append("3. Configurar CRON jobs para execução automática")
        report.append("4. Monitorar logs de execução")
        
        return "\n".join(report)


def main():
    """Função principal"""
    
    # Verificar argumentos
    if len(sys.argv) > 1 and sys.argv[1] == '--test-connection':
        logger.info("🔍 Modo de teste de conexão ativado")
    
    # Inicializar tester
    tester = TaleonSiteTester()
    
    # Executar testes
    results = tester.test_all_sites()
    
    # Gerar relatório
    report = tester.generate_report(results)
    
    # Exibir relatório
    print(report)
    
    # Salvar relatório em arquivo
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    report_file = f"test-report-{timestamp}.txt"
    
    try:
        with open(report_file, 'w', encoding='utf-8') as f:
            f.write(report)
        logger.info(f"📄 Relatório salvo em: {report_file}")
    except Exception as e:
        logger.error(f"❌ Erro ao salvar relatório: {e}")
    
    # Retornar código de saída baseado no sucesso
    accessible_count = len([r for r in results if r.accessible])
    if accessible_count == len(results):
        logger.info("🎉 Todos os sites estão acessíveis!")
        return 0
    else:
        logger.warning(f"⚠️ {len(results) - accessible_count} sites com problemas")
        return 1


if __name__ == "__main__":
    sys.exit(main()) 