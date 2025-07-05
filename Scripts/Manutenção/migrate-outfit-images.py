#!/usr/bin/env python3
import os
import sys
import logging
from pathlib import Path
from datetime import datetime
import requests
import time
import hashlib
from urllib.parse import urlparse

# Configurar logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/app/logs/migration_outfit_images.log'),
        logging.StreamHandler()
    ]
)

logger = logging.getLogger(__name__)

def get_outfit_urls_from_file():
    """Ler URLs de outfit do arquivo"""
    try:
        urls = []
        with open('/tmp/outfit_urls.txt', 'r') as f:
            for line in f:
                url = line.strip()
                if url:
                    urls.append(url)
        
        logger.info(f"📊 Encontradas {len(urls)} URLs únicas no arquivo")
        return urls
        
    except Exception as e:
        logger.error(f"❌ Erro ao ler URLs do arquivo: {e}")
        return []

def download_image(url, filepath):
    """Download de uma imagem"""
    try:
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        }
        response = requests.get(url, timeout=10, headers=headers)
        response.raise_for_status()
        
        with open(filepath, 'wb') as f:
            f.write(response.content)
        
        return True
    except Exception as e:
        logger.error(f"❌ Erro ao baixar {url}: {e}")
        return False

def main():
    logger.info("🚀 Iniciando migração de imagens de outfit...")
    logger.info(f"⏰ Timestamp: {datetime.now()}")
    
    # Criar diretório de imagens
    images_dir = Path("/app/outfits/images")
    images_dir.mkdir(parents=True, exist_ok=True)
    
    logger.info(f"📁 Diretório de imagens: {images_dir}")
    
    # Buscar URLs do arquivo
    urls = get_outfit_urls_from_file()
    
    if not urls:
        logger.warning("⚠️  Nenhuma URL encontrada no arquivo")
        return True
    
    downloaded_count = 0
    error_count = 0
    
    for i, url in enumerate(urls, 1):
        try:
            # Gerar nome do arquivo baseado na URL
            filename = hashlib.md5(url.encode()).hexdigest() + ".gif"
            filepath = images_dir / filename
            
            # Verificar se já existe
            if filepath.exists():
                logger.info(f"⏭️  [{i}/{len(urls)}] Imagem já existe: {filename}")
                continue
            
            # Download da imagem
            logger.info(f"⬇️  [{i}/{len(urls)}] Baixando: {url}")
            if download_image(url, filepath):
                downloaded_count += 1
                logger.info(f"✅ [{i}/{len(urls)}] Baixado: {filename}")
            else:
                error_count += 1
                
            # Pequena pausa para não sobrecarregar o servidor
            time.sleep(1)
            
        except Exception as e:
            logger.error(f"❌ [{i}/{len(urls)}] Erro ao processar {url}: {e}")
            error_count += 1
    
    logger.info(f"📊 Resumo da migração:")
    logger.info(f"   - URLs encontradas: {len(urls)}")
    logger.info(f"   - Baixados: {downloaded_count}")
    logger.info(f"   - Erros: {error_count}")
    logger.info(f"   - Já existiam: {len(urls) - downloaded_count - error_count}")
    logger.info("✅ Migração concluída com sucesso!")
    
    return True

if __name__ == "__main__":
    main() 