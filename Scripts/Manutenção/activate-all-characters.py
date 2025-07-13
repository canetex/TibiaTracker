#!/usr/bin/env python3
"""
Script para ativar todos os personagens inativos
"""

import asyncio
import sys
import os
from sqlalchemy import text
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker

# Adicionar o diretório do projeto ao path
sys.path.append('/app')

from app.core.config import settings
from app.db.database import get_db_session

async def activate_all_characters():
    """Ativar todos os personagens inativos"""
    
    print("🔄 Ativando todos os personagens inativos...")
    print("=" * 50)
    
    try:
        # Criar conexão com o banco
        engine = create_async_engine(settings.DATABASE_URL)
        
        async with engine.begin() as conn:
            # Verificar estatísticas atuais
            result = await conn.execute(text("""
                SELECT 
                    COUNT(*) as total,
                    COUNT(CASE WHEN is_active = true THEN 1 END) as ativos,
                    COUNT(CASE WHEN is_active = false THEN 1 END) as inativos
                FROM characters
            """))
            
            stats = result.fetchone()
            total, ativos, inativos = stats
            
            print(f"📊 Estatísticas atuais:")
            print(f"   📋 Total de personagens: {total}")
            print(f"   ✅ Ativos: {ativos}")
            print(f"   ❌ Inativos: {inativos}")
            
            if inativos == 0:
                print("✅ Todos os personagens já estão ativos!")
                return
            
            # Confirmar antes de prosseguir
            print("")
            print(f"⚠️  ATENÇÃO: Esta operação irá ativar TODOS os {inativos} personagens inativos!")
            print("   - Isso fará com que todos sejam incluídos nas atualizações automáticas")
            print("   - O próximo update automático será mais demorado")
            print("")
            
            confirm = input("🤔 Continuar? (s/N): ").strip().lower()
            if confirm != 's':
                print("❌ Operação cancelada pelo usuário")
                return
            
            # Ativar todos os personagens inativos
            print("🚀 Ativando todos os personagens...")
            print("=" * 50)
            
            result = await conn.execute(text("""
                UPDATE characters 
                SET is_active = true, updated_at = CURRENT_TIMESTAMP
                WHERE is_active = false
            """))
            
            activated_count = result.rowcount
            
            print(f"✅ Sucesso! {activated_count} personagens foram ativados")
            
            # Verificar resultado
            print("")
            print("📊 Verificando resultado...")
            
            result = await conn.execute(text("""
                SELECT 
                    COUNT(*) as total,
                    COUNT(CASE WHEN is_active = true THEN 1 END) as ativos,
                    COUNT(CASE WHEN is_active = false THEN 1 END) as inativos
                FROM characters
            """))
            
            stats = result.fetchone()
            total, ativos, inativos = stats
            
            print(f"📈 Novas estatísticas:")
            print(f"   📋 Total de personagens: {total}")
            print(f"   ✅ Ativos: {ativos}")
            print(f"   ❌ Inativos: {inativos}")
            
            print("")
            print("🎉 Todos os personagens estão agora ativos!")
            print(f"⚠️  Próximo update automático incluirá todos os {ativos} personagens")
            
    except Exception as e:
        print(f"❌ Erro: {e}")
        return False
    
    finally:
        await engine.dispose()
    
    return True

if __name__ == "__main__":
    asyncio.run(activate_all_characters()) 