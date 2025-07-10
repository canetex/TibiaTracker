#!/usr/bin/env python3
"""
Script para corrigir inconsistências de timezone no código
========================================================

Substitui todas as ocorrências de datetime.utcnow() e datetime.now() 
por funções padronizadas com timezone.
"""

import os
import re
from pathlib import Path

def fix_datetime_issues():
    """Corrigir todas as inconsistências de timezone"""
    
    # Diretório do projeto
    backend_dir = Path("Backend")
    
    # Arquivos Python para processar
    python_files = [
        "app/api/routes/characters.py",
        "app/api/routes/health.py", 
        "app/services/character.py",
        "app/services/scheduler.py",
        "app/services/outfit_service.py",
        "app/main.py",
        "app/services/scraping/base.py",
        "app/services/scraping/taleon.py"
    ]
    
    # Substituições a serem feitas
    replacements = [
        # datetime.utcnow() -> get_utc_now()
        (r'datetime\.utcnow\(\)', 'get_utc_now()'),
        
        # datetime.now() -> get_utc_now() (para timestamps)
        (r'datetime\.now\(\)\.isoformat\(\)', 'get_utc_now().isoformat()'),
        (r'datetime\.now\(\)\.timestamp\(\)', 'get_utc_now().timestamp()'),
        
        # datetime.now() -> get_utc_now() (para comparações)
        (r'datetime\.now\(\)\s*-\s*timedelta', 'get_utc_now() - timedelta'),
        (r'datetime\.now\(\)\s*\+\s*timedelta', 'get_utc_now() + timedelta'),
        
        # datetime.now().date() -> get_utc_date().date()
        (r'datetime\.now\(\)\.date\(\)', 'get_utc_date().date()'),
        
        # datetime.now() -> get_utc_now() (outros casos)
        (r'datetime\.now\(\)', 'get_utc_now()'),
    ]
    
    # Imports a serem adicionados
    imports_to_add = [
        "from app.core.utils import get_utc_now, get_utc_date, normalize_datetime, days_between"
    ]
    
    for file_path in python_files:
        full_path = backend_dir / file_path
        
        if not full_path.exists():
            print(f"⚠️  Arquivo não encontrado: {full_path}")
            continue
            
        print(f"🔧 Processando: {file_path}")
        
        # Ler arquivo
        with open(full_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original_content = content
        
        # Aplicar substituições
        for pattern, replacement in replacements:
            content = re.sub(pattern, replacement, content)
        
        # Adicionar imports se necessário
        if 'get_utc_now()' in content and 'from app.core.utils import' not in content:
            # Encontrar linha após imports de datetime
            lines = content.split('\n')
            insert_index = None
            
            for i, line in enumerate(lines):
                if 'from datetime import' in line:
                    insert_index = i + 1
                    break
            
            if insert_index is not None:
                lines.insert(insert_index, imports_to_add[0])
                content = '\n'.join(lines)
        
        # Salvar se houve mudanças
        if content != original_content:
            with open(full_path, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"✅ Corrigido: {file_path}")
        else:
            print(f"ℹ️  Sem mudanças: {file_path}")

if __name__ == "__main__":
    print("🚀 Iniciando correção de inconsistências de timezone...")
    fix_datetime_issues()
    print("✅ Correção concluída!") 