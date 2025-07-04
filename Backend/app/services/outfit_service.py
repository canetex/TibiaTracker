"""
Serviço para gerenciamento de outfits
====================================

Responsável por download, armazenamento e gerenciamento de imagens de outfit.
"""

import os
import aiohttp
import aiofiles
import hashlib
from typing import Optional, Dict, Any
from datetime import datetime
import logging
from urllib.parse import urlparse
import json

logger = logging.getLogger(__name__)


class OutfitService:
    """Serviço para gerenciamento de outfits"""
    
    def __init__(self, storage_path: str = "outfits"):
        """
        Inicializar serviço de outfit
        
        Args:
            storage_path: Caminho para armazenar as imagens de outfit
        """
        self.storage_path = storage_path
        self._ensure_storage_directory()
    
    def _ensure_storage_directory(self):
        """Garantir que o diretório de armazenamento existe"""
        os.makedirs(self.storage_path, exist_ok=True)
        logger.info(f"Diretório de outfits configurado: {self.storage_path}")
    
    def _generate_filename(self, character_name: str, server: str, world: str, outfit_url: str) -> str:
        """Gerar nome de arquivo único para a imagem do outfit"""
        # Criar hash da URL para evitar conflitos
        url_hash = hashlib.md5(outfit_url.encode()).hexdigest()[:8]
        
        # Nome do arquivo: character_server_world_hash.png
        safe_name = character_name.replace(' ', '_').replace('/', '_').replace('\\', '_')
        filename = f"{safe_name}_{server}_{world}_{url_hash}.png"
        
        return filename
    
    async def download_outfit_image(
        self, 
        outfit_url: str, 
        character_name: str, 
        server: str, 
        world: str
    ) -> Optional[Dict[str, Any]]:
        """
        Download e salvar imagem do outfit
        
        Returns:
            Dict com informações do outfit salvo ou None se falhar
        """
        if not outfit_url:
            return None
        
        try:
            filename = self._generate_filename(character_name, server, world, outfit_url)
            filepath = os.path.join(self.storage_path, filename)
            
            # Verificar se já existe
            if os.path.exists(filepath):
                logger.info(f"Outfit já existe: {filepath}")
                return {
                    'filename': filename,
                    'filepath': filepath,
                    'url': outfit_url,
                    'local_url': f"/outfits/{filename}",
                    'cached': True
                }
            
            # Download da imagem
            async with aiohttp.ClientSession() as session:
                async with session.get(outfit_url) as response:
                    if response.status == 200:
                        content = await response.read()
                        
                        # Salvar arquivo
                        async with aiofiles.open(filepath, 'wb') as f:
                            await f.write(content)
                        
                        # Obter informações do arquivo
                        file_size = len(content)
                        
                        outfit_info = {
                            'filename': filename,
                            'filepath': filepath,
                            'url': outfit_url,
                            'local_url': f"/outfits/{filename}",
                            'file_size': file_size,
                            'downloaded_at': datetime.now().isoformat(),
                            'cached': False
                        }
                        
                        logger.info(f"Outfit baixado com sucesso: {filename} ({file_size} bytes)")
                        return outfit_info
                    else:
                        logger.error(f"Erro ao baixar outfit: HTTP {response.status}")
                        return None
                        
        except Exception as e:
            logger.error(f"Erro ao processar outfit para {character_name}: {e}")
            return None
    
    def get_outfit_data(self, outfit_url: str) -> Optional[Dict[str, Any]]:
        """
        Extrair dados do outfit da URL
        
        Args:
            outfit_url: URL do outfit (ex: https://outfits.taleon.online/outfit.php?id=128&addons=0&head=2&body=86&legs=95&feet=0&mount=0&direction=3)
        
        Returns:
            Dict com dados do outfit ou None se não conseguir extrair
        """
        if not outfit_url:
            return None
        
        try:
            # Parsear URL para extrair parâmetros
            parsed = urlparse(outfit_url)
            if 'outfit.php' not in parsed.path:
                return None
            
            # Extrair parâmetros da query string
            from urllib.parse import parse_qs
            params = parse_qs(parsed.query)
            
            outfit_data = {
                'outfit_id': int(params.get('id', [0])[0]),
                'addons': int(params.get('addons', [0])[0]),
                'head': int(params.get('head', [0])[0]),
                'body': int(params.get('body', [0])[0]),
                'legs': int(params.get('legs', [0])[0]),
                'feet': int(params.get('feet', [0])[0]),
                'mount': int(params.get('mount', [0])[0]),
                'direction': int(params.get('direction', [3])[0]),
                'original_url': outfit_url
            }
            
            return outfit_data
            
        except Exception as e:
            logger.error(f"Erro ao extrair dados do outfit: {e}")
            return None
    
    async def process_outfit(
        self, 
        outfit_url: str, 
        character_name: str, 
        server: str, 
        world: str
    ) -> Optional[Dict[str, Any]]:
        """
        Processar outfit completo: download + extrair dados
        
        Returns:
            Dict com todas as informações do outfit processado
        """
        if not outfit_url:
            return None
        
        try:
            # Extrair dados do outfit
            outfit_data = self.get_outfit_data(outfit_url)
            if not outfit_data:
                return None
            
            # Download da imagem
            download_result = await self.download_outfit_image(outfit_url, character_name, server, world)
            if not download_result:
                return None
            
            # Combinar dados
            result = {
                **outfit_data,
                **download_result,
                'processed_at': datetime.now().isoformat()
            }
            
            return result
            
        except Exception as e:
            logger.error(f"Erro ao processar outfit para {character_name}: {e}")
            return None
    
    def cleanup_old_outfits(self, days_old: int = 30) -> int:
        """
        Limpar outfits antigos
        
        Args:
            days_old: Idade em dias para considerar como antigo
            
        Returns:
            Número de arquivos removidos
        """
        try:
            import time
            current_time = time.time()
            cutoff_time = current_time - (days_old * 24 * 60 * 60)
            
            removed_count = 0
            
            for filename in os.listdir(self.storage_path):
                filepath = os.path.join(self.storage_path, filename)
                if os.path.isfile(filepath):
                    file_time = os.path.getmtime(filepath)
                    if file_time < cutoff_time:
                        os.remove(filepath)
                        removed_count += 1
                        logger.info(f"Outfit antigo removido: {filename}")
            
            logger.info(f"Limpeza concluída: {removed_count} outfits removidos")
            return removed_count
            
        except Exception as e:
            logger.error(f"Erro na limpeza de outfits: {e}")
            return 0 