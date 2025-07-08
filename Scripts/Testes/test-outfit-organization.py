#!/usr/bin/env python3
"""
Script de Teste - Organização por Variação de Outfit
===================================================

Este script demonstra como as imagens serão organizadas por variação de outfit
em vez de por nome do personagem, economizando espaço em disco.
"""

import sys
from pathlib import Path

# Adicionar o diretório do backend ao path
backend_path = Path(__file__).parent.parent.parent / "Backend"
sys.path.insert(0, str(backend_path))

from app.services.outfit_manager import OutfitManager

def test_outfit_organization():
    """Testar a organização por variação de outfit"""
    
    print("🧪 Testando organização por variação de outfit...")
    print("=" * 60)
    
    # URLs de exemplo do Taleon
    test_urls = [
        "https://outfits.taleon.online/outfit.php?id=128&addons=0&head=2&body=86&legs=95&feet=0&mount=0&direction=3",
        "https://outfits.taleon.online/outfit.php?id=128&addons=0&head=2&body=86&legs=95&feet=0&mount=0&direction=3",  # Duplicada
        "https://outfits.taleon.online/outfit.php?id=128&addons=1&head=2&body=86&legs=95&feet=0&mount=0&direction=3",
        "https://outfits.taleon.online/outfit.php?id=128&addons=2&head=2&body=86&legs=95&feet=0&mount=0&direction=3",
        "https://outfits.taleon.online/outfit.php?id=129&addons=0&head=5&body=90&legs=100&feet=10&mount=0&direction=2",
        "https://outfits.taleon.online/outfit.php?id=130&addons=3&head=0&body=0&legs=0&feet=0&mount=1&direction=1",
        "https://outfits.taleon.online/outfit.php?id=128&addons=0&head=2&body=86&legs=95&feet=0&mount=0&direction=0",
        "https://outfits.taleon.online/outfit.php?id=128&addons=0&head=2&body=86&legs=95&feet=0&mount=0&direction=1",
        "https://outfits.taleon.online/outfit.php?id=128&addons=0&head=2&body=86&legs=95&feet=0&mount=0&direction=2",
        "https://outfits.taleon.online/outfit.php?id=128&addons=0&head=2&body=86&legs=95&feet=0&mount=0&direction=3",
    ]
    
    # URLs que não seguem o padrão (fallback)
    fallback_urls = [
        "https://example.com/outfit.jpg",
        "https://other-server.com/character.png",
        "https://taleon.com.br/outfit.gif",
    ]
    
    outfit_manager = OutfitManager()
    
    print("📋 URLs do Taleon (organização por variação):")
    print("-" * 40)
    
    unique_paths = set()
    total_urls = len(test_urls)
    
    for i, url in enumerate(test_urls, 1):
        path = outfit_manager.get_image_path(url)
        unique_paths.add(path)
        
        # Extrair dados do outfit
        outfit_data = outfit_manager._extract_outfit_data_from_url(url)
        
        print(f"{i:2d}. {path}")
        if outfit_data:
            print(f"    ID: {outfit_data['outfit_id']}, Addons: {outfit_data['addons']}, "
                  f"Head: {outfit_data['head']}, Body: {outfit_data['body']}, "
                  f"Legs: {outfit_data['legs']}, Feet: {outfit_data['feet']}, "
                  f"Mount: {outfit_data['mount']}, Direction: {outfit_data['direction']}")
        print()
    
    print("📋 URLs com fallback (organização por hash):")
    print("-" * 40)
    
    for i, url in enumerate(fallback_urls, 1):
        path = outfit_manager.get_image_path(url)
        unique_paths.add(path)
        print(f"{i:2d}. {path}")
        print()
    
    print("📊 Estatísticas:")
    print("-" * 40)
    print(f"Total de URLs testadas: {total_urls + len(fallback_urls)}")
    print(f"Arquivos únicos gerados: {len(unique_paths)}")
    print(f"Economia de espaço: {((total_urls + len(fallback_urls)) - len(unique_paths))} arquivos")
    print(f"Taxa de deduplicação: {((total_urls + len(fallback_urls)) - len(unique_paths)) / (total_urls + len(fallback_urls)) * 100:.1f}%")
    
    print("\n🎯 Benefícios da nova organização:")
    print("-" * 40)
    print("✅ Economia de espaço em disco")
    print("✅ Deduplicação automática de outfits idênticos")
    print("✅ Organização lógica por variação do outfit")
    print("✅ Facilita busca e cache de outfits")
    print("✅ Suporte a múltiplos personagens com mesmo outfit")
    
    print("\n📁 Estrutura de arquivos gerada:")
    print("-" * 40)
    for path in sorted(unique_paths):
        print(f"  {path}")
    
    return True

if __name__ == "__main__":
    success = test_outfit_organization()
    sys.exit(0 if success else 1) 