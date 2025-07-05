"""
Gerenciador de Outfits - Download e Armazenamento Local
======================================================

Serviço para baixar e gerenciar imagens de outfits localmente.
"""

import os
import hashlib
import requests
from pathlib import Path
from typing import Optional, Dict, List
import logging
from urllib.parse import urlparse
import mimetypes
from datetime import datetime

logger = logging.getLogger(__name__)


class OutfitManager:
    """Gerenciador de outfits para download e armazenamento local"""
    
    def __init__(self, base_path: str = "/app/outfits"):
        """
        Inicializar o gerenciador de outfits
        
        Args:
            base_path: Caminho base para armazenar as imagens
        """
        self.base_path = Path(base_path)
        self.base_path.mkdir(parents=True, exist_ok=True)
        
        # Criar subdiretórios para organização
        self.images_path = self.base_path / "images"
        self.images_path.mkdir(exist_ok=True)
        
        self.temp_path = self.base_path / "temp"
        self.temp_path.mkdir(exist_ok=True)
        
        logger.info(f"OutfitManager inicializado em: {self.base_path}")
    
    def get_image_path(self, image_url: str, character_name: str = None) -> str:
        """
        Gerar caminho local para uma imagem baseado na variação do outfit
        
        Args:
            image_url: URL da imagem
            character_name: Nome do personagem (opcional, para organização)
            
        Returns:
            Caminho local relativo da imagem
        """
        if not image_url:
            return None
        
        # Tentar extrair dados do outfit da URL
        outfit_data = self._extract_outfit_data_from_url(image_url)
        
        if outfit_data:
            # Organizar por variação do outfit
            filename = self._generate_outfit_filename(outfit_data)
            relative_path = f"images/{filename}"
        else:
            # Fallback: usar hash da URL (para URLs que não seguem o padrão)
            url_hash = hashlib.md5(image_url.encode()).hexdigest()[:8]
            extension = self._detect_extension_from_url(image_url)
            filename = f"outfit_{url_hash}{extension}"
            relative_path = f"images/{filename}"
        
        return relative_path
    
    def _extract_outfit_data_from_url(self, image_url: str) -> Optional[Dict[str, int]]:
        """
        Extrair dados do outfit da URL do Taleon
        
        Args:
            image_url: URL do outfit (ex: https://outfits.taleon.online/outfit.php?id=128&addons=0&head=2&body=86&legs=95&feet=0&mount=0&direction=3)
            
        Returns:
            Dict com dados do outfit ou None se não conseguir extrair
        """
        try:
            from urllib.parse import parse_qs, urlparse
            
            parsed = urlparse(image_url)
            if 'outfit.php' not in parsed.path:
                return None
            
            # Extrair parâmetros da query string
            params = parse_qs(parsed.query)
            
            outfit_data = {
                'outfit_id': int(params.get('id', [0])[0]),
                'addons': int(params.get('addons', [0])[0]),
                'head': int(params.get('head', [0])[0]),
                'body': int(params.get('body', [0])[0]),
                'legs': int(params.get('legs', [0])[0]),
                'feet': int(params.get('feet', [0])[0]),
                'mount': int(params.get('mount', [0])[0]),
                'direction': int(params.get('direction', [3])[0])
            }
            
            return outfit_data
            
        except Exception as e:
            logger.debug(f"Erro ao extrair dados do outfit da URL {image_url}: {e}")
            return None
    
    def _generate_outfit_filename(self, outfit_data: Dict[str, int]) -> str:
        """
        Gerar nome de arquivo baseado na variação do outfit
        
        Args:
            outfit_data: Dicionário com dados do outfit
            
        Returns:
            Nome do arquivo
        """
        # Formato: outfit_{id}_{addons}_{head}_{body}_{legs}_{feet}_{mount}_{direction}.gif
        filename = (
            f"outfit_{outfit_data['outfit_id']:03d}_"
            f"{outfit_data['addons']}_{outfit_data['head']:03d}_"
            f"{outfit_data['body']:03d}_{outfit_data['legs']:03d}_"
            f"{outfit_data['feet']:03d}_{outfit_data['mount']:03d}_"
            f"{outfit_data['direction']}.gif"
        )
        
        return filename
    
    def _detect_extension_from_url(self, url: str) -> str:
        """Detectar extensão baseado na URL"""
        # Mapeamento comum de URLs para extensões
        url_lower = url.lower()
        
        if 'gif' in url_lower:
            return '.gif'
        elif 'png' in url_lower:
            return '.png'
        elif 'jpg' in url_lower or 'jpeg' in url_lower:
            return '.jpg'
        elif 'webp' in url_lower:
            return '.webp'
        else:
            # Padrão para URLs do Taleon
            if 'taleon' in url_lower:
                return '.gif'  # Taleon usa GIFs
            else:
                return '.jpg'  # Padrão
    
    def download_image(self, image_url: str) -> Optional[str]:
        """
        Baixar imagem e salvar localmente
        
        Args:
            image_url: URL da imagem para baixar
            
        Returns:
            Caminho local da imagem salva ou None se falhar
        """
        if not image_url:
            return None
        
        try:
            # Gerar caminho local baseado na variação do outfit
            local_path = self.get_image_path(image_url)
            if not local_path:
                return None
            
            full_path = self.base_path / local_path
            
            # Verificar se já existe
            if full_path.exists():
                logger.info(f"Imagem já existe: {local_path}")
                return local_path
            
            # Baixar imagem
            logger.info(f"Baixando imagem: {image_url}")
            response = requests.get(
                image_url,
                timeout=30,
                headers={
                    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
                }
            )
            response.raise_for_status()
            
            # Verificar content-type
            content_type = response.headers.get('content-type', '')
            if not content_type.startswith('image/'):
                logger.warning(f"URL não retornou imagem: {content_type}")
                return None
            
            # Salvar arquivo
            full_path.parent.mkdir(parents=True, exist_ok=True)
            with open(full_path, 'wb') as f:
                f.write(response.content)
            
            file_size = len(response.content)
            logger.info(f"Imagem salva: {local_path} ({file_size} bytes)")
            
            return local_path
            
        except Exception as e:
            logger.error(f"Erro ao baixar imagem {image_url}: {e}")
            return None
    
    def get_all_outfit_urls(self, db_session) -> List[Dict]:
        """
        Buscar todas as URLs de outfit no banco de dados
        
        Args:
            db_session: Sessão do banco de dados
            
        Returns:
            Lista de dicionários com informações das imagens
        """
        try:
            from app.models.character import Character, CharacterSnapshot
            
            # Buscar URLs únicas de characters
            characters = db_session.query(Character).filter(
                Character.outfit_image_url.isnot(None)
            ).all()
            
            # Buscar URLs únicas de snapshots
            snapshots = db_session.query(CharacterSnapshot).filter(
                CharacterSnapshot.outfit_image_url.isnot(None)
            ).all()
            
            # Consolidar URLs únicas
            unique_urls = {}
            
            # Adicionar URLs dos characters
            for char in characters:
                if char.outfit_image_url:
                    unique_urls[char.outfit_image_url] = {
                        'url': char.outfit_image_url,
                        'character_name': char.name,
                        'source': 'character',
                        'character_id': char.id
                    }
            
            # Adicionar URLs dos snapshots
            for snap in snapshots:
                if snap.outfit_image_url:
                    unique_urls[snap.outfit_image_url] = {
                        'url': snap.outfit_image_url,
                        'character_name': snap.character.name if snap.character else None,
                        'source': 'snapshot',
                        'character_id': snap.character_id
                    }
            
            return list(unique_urls.values())
            
        except Exception as e:
            logger.error(f"Erro ao buscar URLs de outfit: {e}")
            return []
    
    def download_all_outfits(self, db_session) -> Dict:
        """
        Baixar todas as imagens de outfit do banco de dados
        
        Args:
            db_session: Sessão do banco de dados
            
        Returns:
            Dicionário com estatísticas do download
        """
        stats = {
            'total_urls': 0,
            'downloaded': 0,
            'failed': 0,
            'already_exists': 0,
            'errors': []
        }
        
        try:
            outfit_urls = self.get_all_outfit_urls(db_session)
            stats['total_urls'] = len(outfit_urls)
            
            logger.info(f"Iniciando download de {len(outfit_urls)} imagens de outfit...")
            
            for outfit_info in outfit_urls:
                try:
                    url = outfit_info['url']
                    
                    # Verificar se já existe
                    local_path = self.get_image_path(url)
                    full_path = self.base_path / local_path
                    
                    if full_path.exists():
                        stats['already_exists'] += 1
                        logger.debug(f"Imagem já existe: {local_path}")
                        continue
                    
                    # Baixar imagem
                    downloaded_path = self.download_image(url)
                    if downloaded_path:
                        stats['downloaded'] += 1
                        logger.info(f"Downloaded: {downloaded_path}")
                    else:
                        stats['failed'] += 1
                        stats['errors'].append(f"Falha ao baixar: {url}")
                        
                except Exception as e:
                    stats['failed'] += 1
                    error_msg = f"Erro ao processar {outfit_info.get('url', 'unknown')}: {e}"
                    stats['errors'].append(error_msg)
                    logger.error(error_msg)
            
            logger.info(f"Download concluído: {stats['downloaded']} baixadas, "
                       f"{stats['already_exists']} já existiam, {stats['failed']} falharam")
            
        except Exception as e:
            logger.error(f"Erro geral no download de outfits: {e}")
            stats['errors'].append(f"Erro geral: {e}")
        
        return stats
    
    def cleanup_temp_files(self) -> int:
        """
        Limpar arquivos temporários
        
        Returns:
            Número de arquivos removidos
        """
        try:
            removed_count = 0
            for temp_file in self.temp_path.glob("*"):
                if temp_file.is_file():
                    temp_file.unlink()
                    removed_count += 1
            
            logger.info(f"Removidos {removed_count} arquivos temporários")
            return removed_count
            
        except Exception as e:
            logger.error(f"Erro ao limpar arquivos temporários: {e}")
            return 0
    
    def get_storage_stats(self) -> Dict:
        """
        Obter estatísticas de armazenamento
        
        Returns:
            Dicionário com estatísticas
        """
        try:
            total_files = 0
            total_size = 0
            
            for image_file in self.images_path.rglob("*"):
                if image_file.is_file():
                    total_files += 1
                    total_size += image_file.stat().st_size
            
            return {
                'total_files': total_files,
                'total_size_bytes': total_size,
                'total_size_mb': round(total_size / (1024 * 1024), 2),
                'base_path': str(self.base_path),
                'images_path': str(self.images_path)
            }
            
        except Exception as e:
            logger.error(f"Erro ao obter estatísticas: {e}")
            return {}


# Instância global
outfit_manager = OutfitManager() 