#!/usr/bin/env python3
"""
Script de teste para debugar o regex de extração de personagens
"""

import re
import urllib.parse

def test_regex_extraction():
    """Testar a extração de nomes de personagens com o regex atual"""
    
    # HTML de exemplo baseado no que vimos
    test_html = """
    <tr><td><a href='characterprofile.php?name=Ekzin Bate Fofo'>Ekzin Bate Fofo</a></td><td> at level 209 by an eternal guardian and a serpent spawn</td><td>10 Jul 2025, 21:20</td></tr>
    <tr><td><a href='characterprofile.php?name=Niichj'>Niichj</a></td><td> at level 923 by a gore horn </td><td>10 Jul 2025, 21:11</td></tr>
    <tr><td><a href='characterprofile.php?name=Nogz'>Nogz</a></td><td> at level 432 by an ironblight </td><td>10 Jul 2025, 21:10</td></tr>
    """
    
    print("=== TESTE DO REGEX ATUAL ===")
    
    # Regex atual do script
    pattern = r'href=[\'"]([^\'"]*characterprofile\.php\?name=[^\'"]*)[\'"]'
    matches = re.findall(pattern, test_html, re.IGNORECASE)
    
    print(f"Regex encontrou {len(matches)} matches:")
    for i, match in enumerate(matches, 1):
        print(f"  {i}. {match}")
    
    print("\n=== TESTE DE EXTRAÇÃO DE NOMES ===")
    
    def extract_character_name_from_url(href):
        """Função de extração do script"""
        try:
            match = re.search(r'characterprofile\.php\?name=([^&\'\"]+)', href)
            if match:
                from urllib.parse import unquote
                character_name = unquote(match.group(1))
                return character_name.strip()
            return None
        except Exception as e:
            print(f"Erro ao extrair nome da URL '{href}': {e}")
            return None
    
    for match in matches:
        name = extract_character_name_from_url(match)
        print(f"URL: {match} -> Nome: {name}")
    
    print("\n=== TESTE COM HTML REAL ===")
    
    # Ler o arquivo HTML salvo
    try:
        with open('/tmp/deaths_test.html', 'r', encoding='utf-8') as f:
            real_html = f.read()
        
        print(f"HTML carregado: {len(real_html)} caracteres")
        
        # Testar regex no HTML real
        matches_real = re.findall(pattern, real_html, re.IGNORECASE)
        print(f"Regex encontrou {len(matches_real)} matches no HTML real")
        
        # Mostrar primeiros 5 matches
        for i, match in enumerate(matches_real[:5], 1):
            name = extract_character_name_from_url(match)
            print(f"  {i}. {match} -> {name}")
        
        # Contar personagens únicos
        unique_names = set()
        for match in matches_real:
            name = extract_character_name_from_url(match)
            if name:
                unique_names.add(name)
        
        print(f"\nTotal de personagens únicos encontrados: {len(unique_names)}")
        
    except FileNotFoundError:
        print("Arquivo /tmp/deaths_test.html não encontrado. Execute primeiro:")
        print("curl -s 'https://san.taleon.online/deaths.php' > /tmp/deaths_test.html")

if __name__ == "__main__":
    test_regex_extraction() 