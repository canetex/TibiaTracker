"""
Scraper Específico para Servidor Rubinot
========================================

Implementa scraping específico para o servidor Rubinot.
URL única: https://rubinot.com.br/?subtopic=characters&name=CharacterName

Características:
- Scraping apenas de level (não experiência)
- Imagem padrão de outfit
- Detecção automática do mundo
- Preparado para volume alto (+10.000 chars)
- Interpolação de level para dias sem dados
"""

import re
import json
from typing import Dict, Any, List, Optional
from datetime import datetime, timedelta, date
from urllib.parse import quote
from bs4 import BeautifulSoup
import logging
from dataclasses import dataclass
from app.core.utils import normalize_datetime

from .base import BaseCharacterScraper

logger = logging.getLogger(__name__)


class RubinotCharacterScraper(BaseCharacterScraper):
    """
    Scraper específico para o servidor Rubinot
    """
    
    def __init__(self):
        super().__init__()
        # URL padrão do outfit para todos os personagens
        self.default_outfit_url = "http://217.196.63.249:3000/outfits/_taleon_Aura_ecef549e.png"
    
    def _get_server_name(self) -> str:
        return "rubinot"
    
    def _get_supported_worlds(self) -> List[str]:
        """Mundos suportados do Rubinot - serão detectados automaticamente"""
        return [
            'auroria', 'belaria', 'elysian', 'bellum', 'harmonian',
            'vesperia', 'spectrum', 'kalarian', 'lunarian', 'solarian'
        ]
    
    def _get_request_delay(self) -> float:
        """Delay específico do Rubinot entre requests"""
        return 1.0  # Delay reduzido para volume alto
    
    def _build_character_url(self, world: str, character_name: str) -> str:
        """Construir URL específica do personagem para o Rubinot"""
        # URL única do Rubinot: https://rubinot.com.br/?subtopic=characters&name=CharacterName
        encoded_name = quote(character_name)
        return f"https://rubinot.com.br/?subtopic=characters&name={encoded_name}"
    
    def _extract_world_from_page(self, soup: BeautifulSoup) -> str:
        """Extrair mundo automaticamente da página"""
        try:
            # Procurar por informações do mundo na página
            page_text = soup.get_text().lower()
            
            # Padrões para detectar o mundo
            world_patterns = {
                'auroria': ['auroria', 'aur'],
                'belaria': ['belaria', 'bel'],
                'elysian': ['elysian', 'ely'],
                'bellum': ['bellum', 'bell'],
                'harmonian': ['harmonian', 'harm'],
                'vesperia': ['vesperia', 'vesp'],
                'spectrum': ['spectrum', 'spec'],
                'kalarian': ['kalarian', 'kal'],
                'lunarian': ['lunarian', 'lun'],
                'solarian': ['solarian', 'sol']
            }
            
            for world, patterns in world_patterns.items():
                for pattern in patterns:
                    if pattern in page_text:
                        logger.debug(f"[RUBINOT] Mundo detectado: {world}")
                        return world
            
            # Se não encontrou, procurar em elementos específicos
            for tag in ['title', 'h1', 'h2', 'h3']:
                elements = soup.find_all(tag)
                for element in elements:
                    if hasattr(element, 'get_text'):
                        element_text = element.get_text().lower()
                        for world, patterns in world_patterns.items():
                            for pattern in patterns:
                                if pattern in element_text:
                                    logger.debug(f"[RUBINOT] Mundo detectado em {tag}: {world}")
                                    return world
            
            logger.warning("[RUBINOT] Mundo não detectado, usando 'auroria' como padrão")
            return 'auroria'  # Mundo padrão
            
        except Exception as e:
            logger.error(f"[RUBINOT] Erro ao detectar mundo: {e}")
            return 'auroria'  # Mundo padrão
    
    def _extract_level_data(self, soup: BeautifulSoup) -> Dict[str, Any]:
        """Extrair dados de level do personagem"""
        try:
            level_data = {
                'current_level': 0,
                'level_history': []  # Histórico de levels por data
            }
            
            # Procurar por level na página
            page_text = soup.get_text()
            
            # Padrões para encontrar level
            level_patterns = [
                r'level[:\s]*(\d+)',
                r'(\d+)\s*level',
                r'lvl[:\s]*(\d+)',
                r'(\d+)\s*lvl'
            ]
            
            for pattern in level_patterns:
                matches = re.findall(pattern, page_text, re.IGNORECASE)
                for match in matches:
                    if match.isdigit():
                        level = int(match)
                        if 1 <= level <= 9999:  # Level válido
                            level_data['current_level'] = level
                            logger.debug(f"[RUBINOT] Level atual encontrado: {level}")
                            break
                if level_data['current_level'] > 0:
                    break
            
            # Procurar em tabelas específicas
            if level_data['current_level'] == 0:
                tables = soup.find_all('table')
                for table in tables:
                    if hasattr(table, 'find_all'):
                        rows = table.find_all('tr')
                        for row in rows:
                            if hasattr(row, 'find_all'):
                                cells = row.find_all(['td', 'th'])
                                if len(cells) >= 2:
                                    label = cells[0].get_text().strip().lower()
                                    value = cells[1].get_text().strip()
                                    
                                    if 'level' in label:
                                        level = self._extract_number(value)
                                        if 1 <= level <= 9999:
                                            level_data['current_level'] = level
                                            logger.debug(f"[RUBINOT] Level encontrado na tabela: {level}")
                                            break
                            if level_data['current_level'] > 0:
                                break
                        if level_data['current_level'] > 0:
                            break
            
            # Se encontrou level, criar entrada para hoje
            if level_data['current_level'] > 0:
                today = datetime.now().date()
                level_data['level_history'].append({
                    'date': today,
                    'level': level_data['current_level']
                })
            
            return level_data
            
        except Exception as e:
            logger.error(f"[RUBINOT] Erro ao extrair dados de level: {e}")
            return {'current_level': 0, 'level_history': []}
    
    def _interpolate_missing_levels(self, level_history: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """
        Interpolar levels para dias sem dados
        
        Exemplo: dia 10 = level 1000, dia 12 = level 1500
        Resultado: dia 11 = level 1250
        """
        if len(level_history) < 2:
            return level_history
        
        # Ordenar por data
        sorted_history = sorted(level_history, key=lambda x: x['date'])
        interpolated_history = []
        
        for i in range(len(sorted_history)):
            current_entry = sorted_history[i]
            interpolated_history.append(current_entry)
            
            # Se há próximo item, verificar se há gaps
            if i < len(sorted_history) - 1:
                next_entry = sorted_history[i + 1]
                current_date = current_entry['date']
                next_date = next_entry['date']
                
                # Calcular diferença em dias
                days_diff = (next_date - current_date).days
                
                if days_diff > 1:
                    # Há dias sem dados, interpolar
                    current_level = current_entry['level']
                    next_level = next_entry['level']
                    level_diff = next_level - current_level
                    
                    for day in range(1, days_diff):
                        interpolated_date = current_date + timedelta(days=day)
                        interpolated_level = current_level + int((level_diff * day) / days_diff)
                        
                        interpolated_history.append({
                            'date': interpolated_date,
                            'level': interpolated_level,
                            'interpolated': True
                        })
                        
                        logger.debug(f"[RUBINOT] Level interpolado: {interpolated_date} = {interpolated_level}")
        
        return interpolated_history
    
    async def _extract_character_data(self, html: str, url: str) -> Dict[str, Any]:
        """Extrair dados específicos do HTML do Rubinot"""
        soup = BeautifulSoup(html, 'lxml')
        
        data = {
            'name': '',
            'level': 0,
            'vocation': 'None',
            'world': '',
            'residence': '',
            'house': None,
            'guild': None,
            'guild_rank': None,
            'guild_url': None,
            'experience': 0,  # Sempre 0 para Rubinot
            'deaths': 0,
            'charm_points': None,
            'bosstiary_points': None,
            'achievement_points': None,
            'is_online': False,
            'last_login': None,
            'profile_url': url,
            'outfit_image_url': self.default_outfit_url,  # URL padrão
            'level_history': []  # Histórico de levels
        }
        
        try:
            logger.info(f"[RUBINOT] Iniciando scraping do personagem na URL: {url}")
            
            # Detectar mundo automaticamente
            detected_world = self._extract_world_from_page(soup)
            data['world'] = detected_world
            
            # Extrair dados de level
            level_data = self._extract_level_data(soup)
            data['level'] = level_data['current_level']
            data['level_history'] = level_data['level_history']
            
            # Interpolar levels para dias sem dados
            if data['level_history']:
                data['level_history'] = self._interpolate_missing_levels(data['level_history'])
            
            # Procurar pela tabela principal com informações do personagem
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
                        
                        # Mapear campos baseado na estrutura real do Rubinot
                        if 'name' in label:
                            data['name'] = re.sub(r'\s+', ' ', value).strip()
                            logger.debug(f"[RUBINOT] Nome extraído: {data['name']}")
                        
                        elif 'vocation' in label:
                            data['vocation'] = value if value not in ['-', 'None', ''] else 'None'
                            logger.debug(f"[RUBINOT] Vocation extraída: {data['vocation']}")
                        
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
                                time_diff = normalize_datetime(datetime.now()) - normalize_datetime(data['last_login'])
                                if time_diff:
                                    data['is_online'] = time_diff.total_seconds() < 7200
                        
                        elif 'residence' in label:
                            data['residence'] = value if value not in ['-', 'None', ''] else ''
                        
                        elif 'house' in label and value not in ['-', 'None', '', 'No house']:
                            data['house'] = value
                        
                        elif 'guild' in label and 'rank' not in label and value not in ['-', 'None', '']:
                            data['guild'] = value
                            logger.info(f"[RUBINOT] Guild encontrada por label: {value}")
                        
                        elif 'guild rank' in label and value not in ['-', 'None', '']:
                            data['guild_rank'] = value
                            logger.info(f"[RUBINOT] Guild rank encontrado: {value}")
            
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
            
            # Extrair mortes (pode estar em diferentes formatos)
            deaths_patterns = [
                r'deaths[:\s]*(\d+)',
                r'death[:\s]*(\d+)',
                r'(\d+)\s*deaths',
                r'(\d+)\s*death'
            ]
            
            page_text = soup.get_text().lower()
            for pattern in deaths_patterns:
                matches = re.findall(pattern, page_text, re.IGNORECASE)
                for match in matches:
                    if match.isdigit():
                        data['deaths'] = int(match)
                        logger.debug(f"[RUBINOT] Mortes extraídas: {data['deaths']}")
                        break
                if data['deaths'] > 0:
                    break
            
            # Definir exp_date baseado no histórico de level
            if data['level_history']:
                # Usar a data mais recente do histórico
                latest_entry = data['level_history'][0]  # Primeiro item é o mais recente
                data['exp_date'] = latest_entry['date']
            else:
                # Se não tem histórico, usar data atual
                data['exp_date'] = datetime.now().date()
            
            logger.debug(f"[RUBINOT] Dados completos: {data}")
            logger.info(f"[RUBINOT] Dados finais extraídos: {data}")
            
        except Exception as e:
            logger.error(f"❌ [RUBINOT] Erro ao extrair dados do HTML: {e}")
            raise
        
        return data
    
    def get_world_details(self) -> Dict[str, Any]:
        """Obter detalhes de todos os mundos configurados do Rubinot"""
        worlds = self._get_supported_worlds()
        world_details = {}
        
        for world in worlds:
            world_details[world] = {
                "name": world.title(),
                "base_url": "https://rubinot.com.br",
                "request_delay": 1.0,
                "timeout_seconds": 30,
                "max_retries": 3,
                "example_url": f"https://rubinot.com.br/?subtopic=characters&name=ExampleCharacter"
            }
        
        return world_details
    
    def get_world_config_info(self, world: str) -> Dict[str, Any]:
        """Obter informações de configuração de um mundo específico"""
        try:
            if world.lower() not in self._get_supported_worlds():
                raise ValueError(f"Mundo '{world}' não suportado pelo Rubinot")
            
            return {
                "world": world,
                "name": world.title(),
                "base_url": "https://rubinot.com.br",
                "request_delay": 1.0,
                "timeout_seconds": 30,
                "max_retries": 3,
                "example_url": f"https://rubinot.com.br/?subtopic=characters&name=ExampleCharacter"
            }
        except ValueError as e:
            return {"error": str(e)} 