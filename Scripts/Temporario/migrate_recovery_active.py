#!/usr/bin/env python3
"""
Script de Migração: Adicionar campo recovery_active na tabela characters
========================================================================

Este script executa a migração para adicionar o campo recovery_active
e configurar os valores iniciais baseados na atividade dos personagens.

Uso: docker-compose exec backend python3 /tmp/migrate_recovery_active.py
"""

import asyncio
import sys
import os
from datetime import datetime, timedelta

# Adicionar o diretório do backend ao path
sys.path.insert(0, '/app')

from sqlalchemy import text
from app.db.database import get_db_session

async def run_migration():
    """Executar migração do campo recovery_active"""
    print("🔄 Iniciando migração do campo recovery_active...")
    
    async with get_db_session() as db:
        try:
            # 1. Adicionar coluna recovery_active
            print("📝 Adicionando coluna recovery_active...")
            await db.execute(text("ALTER TABLE characters ADD COLUMN IF NOT EXISTS recovery_active BOOLEAN DEFAULT TRUE"))
            
            # 2. Criar índice para performance
            print("🔍 Criando índice para performance...")
            await db.execute(text("CREATE INDEX IF NOT EXISTS idx_characters_recovery_active ON characters(recovery_active)"))
            
            # 3. Atualizar personagens que não tiveram experiência nos últimos 10 dias
            print("📊 Verificando personagens inativos (10 dias sem experiência)...")
            result = await db.execute(text("""
                UPDATE characters 
                SET recovery_active = FALSE 
                WHERE id IN (
                    SELECT DISTINCT c.id 
                    FROM characters c
                    LEFT JOIN character_snapshots cs ON c.id = cs.character_id 
                        AND cs.exp_date >= CURRENT_DATE - INTERVAL '10 days'
                        AND cs.experience > 0
                    WHERE cs.id IS NULL
                )
                RETURNING id, name
            """))
            
            inactive_chars = result.fetchall()
            print(f"⚠️ {len(inactive_chars)} personagens marcados como inativos por 10 dias sem experiência")
            
            # 4. Atualizar personagens com erro por 3 dias consecutivos
            print("❌ Verificando personagens com erros consecutivos...")
            result = await db.execute(text("""
                UPDATE characters 
                SET recovery_active = FALSE 
                WHERE scrape_error_count >= 3
                RETURNING id, name, scrape_error_count
            """))
            
            error_chars = result.fetchall()
            print(f"⚠️ {len(error_chars)} personagens marcados como inativos por 3+ erros consecutivos")
            
            # 5. Verificar resultado final
            print("📈 Obtendo estatísticas finais...")
            result = await db.execute(text("""
                SELECT 
                    COUNT(*) as total_characters,
                    COUNT(CASE WHEN recovery_active = TRUE THEN 1 END) as recovery_active,
                    COUNT(CASE WHEN recovery_active = FALSE THEN 1 END) as recovery_inactive
                FROM characters
            """))
            
            stats = result.fetchone()
            
            # 6. Commit das alterações
            await db.commit()
            
            # 7. Relatório final
            print("\n" + "="*60)
            print("🎉 MIGRAÇÃO CONCLUÍDA COM SUCESSO!")
            print("="*60)
            print(f"📊 Total de personagens: {stats[0]}")
            print(f"🟢 Recovery ativo: {stats[1]}")
            print(f"🔴 Recovery inativo: {stats[2]}")
            print(f"📈 Taxa de ativos: {(stats[1]/stats[0]*100):.1f}%")
            
            if inactive_chars:
                print(f"\n⚠️ Personagens inativos por 10 dias sem experiência:")
                for char in inactive_chars[:5]:  # Mostrar apenas os primeiros 5
                    print(f"   - {char[1]} (ID: {char[0]})")
                if len(inactive_chars) > 5:
                    print(f"   ... e mais {len(inactive_chars) - 5} personagens")
            
            if error_chars:
                print(f"\n❌ Personagens inativos por erros consecutivos:")
                for char in error_chars[:5]:  # Mostrar apenas os primeiros 5
                    print(f"   - {char[1]} (ID: {char[0]}, Erros: {char[2]})")
                if len(error_chars) > 5:
                    print(f"   ... e mais {len(error_chars) - 5} personagens")
            
            print("\n✅ Migração concluída! O sistema está pronto para usar recovery_active.")
            
        except Exception as e:
            print(f"❌ Erro na migração: {e}")
            await db.rollback()
            raise

if __name__ == "__main__":
    asyncio.run(run_migration()) 