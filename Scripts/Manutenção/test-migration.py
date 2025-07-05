#!/usr/bin/env python3
"""
Script de Teste da Migração de Imagens de Outfit
================================================

Este script testa se a migração está funcionando corretamente:
1. Verifica se o arquivo de URLs existe
2. Testa download de algumas imagens
3. Verifica organização dos arquivos
4. Mostra estatísticas

Uso:
    python Scripts/Manutenção/test-migration.py
"""

import os
import sys
import logging
from pathlib import Path
from datetime import datetime
import requests
import hashlib
from urllib.parse import urlparse

# Configurar logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler()
    ]
)

logger = logging.getLogger(__name__)

def test_url_file():
    """Testar se o arquivo de URLs existe e é válido"""
    logger.info("🔍 Testando arquivo de URLs...")
    
    try:
        with open('/tmp/outfit_urls.txt', 'r') as f:
            urls = [line.strip() for line in f if line.strip()]
        
        logger.info(f"✅ Arquivo de URLs encontrado com {len(urls)} URLs")
        
        # Mostrar algumas URLs de exemplo
        logger.info("📋 Exemplos de URLs:")
        for i, url in enumerate(urls[:3], 1):
            logger.info(f"   {i}. {url}")
        
        return urls
        
    except FileNotFoundError:
        logger.error("❌ Arquivo /tmp/outfit_urls.txt não encontrado")
        logger.info("💡 Execute primeiro: ./Scripts/Manutenção/run-outfit-migration-simple.sh")
        return []
    except Exception as e:
        logger.error(f"❌ Erro ao ler arquivo de URLs: {e}")
        return []

def test_download(url, test_dir):
    """Testar download de uma imagem"""
    try:
        # Gerar nome do arquivo
        filename = hashlib.md5(url.encode()).hexdigest() + ".gif"
        filepath = test_dir / filename
        
        # Download
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        }
        response = requests.get(url, timeout=10, headers=headers)
        response.raise_for_status()
        
        # Salvar arquivo
        with open(filepath, 'wb') as f:
            f.write(response.content)
        
        # Verificar tamanho
        file_size = filepath.stat().st_size
        logger.info(f"✅ Download OK: {filename} ({file_size} bytes)")
        
        return True, file_size
        
    except Exception as e:
        logger.error(f"❌ Erro no download: {e}")
        return False, 0

def test_directory_structure():
    """Testar estrutura de diretórios"""
    logger.info("📁 Testando estrutura de diretórios...")
    
    # Verificar diretório de imagens
    images_dir = Path("/app/outfits/images")
    if images_dir.exists():
        image_count = len(list(images_dir.glob("*.gif")))
        total_size = sum(f.stat().st_size for f in images_dir.glob("*.gif"))
        logger.info(f"✅ Diretório de imagens: {image_count} arquivos, {total_size/1024/1024:.1f} MB")
    else:
        logger.warning("⚠️  Diretório de imagens não existe")
    
    # Verificar diretório de logs
    logs_dir = Path("/app/logs")
    if logs_dir.exists():
        log_files = list(logs_dir.glob("*.log"))
        logger.info(f"✅ Diretório de logs: {len(log_files)} arquivos")
    else:
        logger.warning("⚠️  Diretório de logs não existe")

def main():
    logger.info("🧪 Iniciando testes da migração...")
    logger.info(f"⏰ Timestamp: {datetime.now()}")
    
    # Teste 1: Arquivo de URLs
    urls = test_url_file()
    if not urls:
        return False
    
    # Teste 2: Estrutura de diretórios
    test_directory_structure()
    
    # Teste 3: Download de teste
    logger.info("⬇️  Testando download de imagens...")
    
    test_dir = Path("/tmp/test_images")
    test_dir.mkdir(exist_ok=True)
    
    success_count = 0
    total_size = 0
    
    for i, url in enumerate(urls[:5], 1):  # Testar apenas 5 URLs
        logger.info(f"   [{i}/5] Testando: {url}")
        success, size = test_download(url, test_dir)
        if success:
            success_count += 1
            total_size += size
    
    # Limpar arquivos de teste
    for file in test_dir.glob("*.gif"):
        file.unlink()
    test_dir.rmdir()
    
    # Resultados
    logger.info(f"📊 Resultados dos testes:")
    logger.info(f"   - URLs testadas: 5")
    logger.info(f"   - Downloads bem-sucedidos: {success_count}")
    logger.info(f"   - Tamanho total baixado: {total_size/1024:.1f} KB")
    
    if success_count >= 3:
        logger.info("✅ Testes passaram! Migração está funcionando.")
        return True
    else:
        logger.warning("⚠️  Alguns testes falharam. Verifique a conectividade.")
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1) 