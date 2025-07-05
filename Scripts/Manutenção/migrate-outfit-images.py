#!/usr/bin/env python3
"""
Script de Migração de Imagens de Outfit
=======================================

Este script:
1. Faz backup do banco atual
2. Lista todas as URLs de outfit_image_url
3. Faz download das imagens
4. Atualiza o banco com os caminhos locais
5. Relaciona os arquivos baixados aos registros

Uso:
    python Scripts/Manutenção/migrate-outfit-images.py
"""

import os
import sys
import subprocess
import logging
from pathlib import Path
from datetime import datetime
import time

# Adicionar o diretório do backend ao path
backend_path = Path(__file__).parent.parent.parent / "Backend"
sys.path.insert(0, str(backend_path))

# Configurar logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('migration_outfit_images.log'),
        logging.StreamHandler()
    ]
)

logger = logging.getLogger(__name__)

def run_backup_script():
    """Executar script de backup"""
    logger.info("🔄 Executando backup do banco de dados...")
    
    try:
        # Executar script de backup
        backup_script = Path(__file__).parent / "backup-database.sh"
        result = subprocess.run(
            [str(backup_script)],
            capture_output=True,
            text=True,
            cwd=Path(__file__).parent.parent.parent
        )
        
        if result.returncode == 0:
            logger.info("✅ Backup realizado com sucesso")
            return True
        else:
            logger.error(f"❌ Erro no backup: {result.stderr}")
            return False
            
    except Exception as e:
        logger.error(f"❌ Erro ao executar backup: {e}")
        return False

def check_database_connection():
    """Verificar conexão com o banco"""
    try:
        from app.db.database import get_db
        from app.models.character import Character
        
        db = next(get_db())
        # Testar conexão
        count = db.query(Character).count()
        logger.info(f"✅ Conexão com banco OK. Total de personagens: {count}")
        return True
        
    except Exception as e:
        logger.error(f"❌ Erro de conexão com banco: {e}")
        return False

def migrate_database_schema():
    """Migrar schema do banco para adicionar outfit_image_path"""
    logger.info("🔄 Migrando schema do banco...")
    
    try:
        from app.db.database import engine
        from app.models.character import Base
        
        # Criar tabelas (isso adicionará as novas colunas se não existirem)
        Base.metadata.create_all(bind=engine)
        logger.info("✅ Schema migrado com sucesso")
        return True
        
    except Exception as e:
        logger.error(f"❌ Erro na migração do schema: {e}")
        return False

def download_and_migrate_images():
    """Download das imagens e migração dos dados"""
    logger.info("🔄 Iniciando download e migração das imagens...")
    
    try:
        from app.db.database import get_db
        from app.models.character import Character, CharacterSnapshot
        from app.services.outfit_manager import outfit_manager
        
        db = next(get_db())
        
        # 1. Fazer download de todas as imagens
        logger.info("📥 Fazendo download das imagens...")
        download_stats = outfit_manager.download_all_outfits(db)
        
        logger.info(f"📊 Estatísticas do download:")
        logger.info(f"   - Total de URLs: {download_stats['total_urls']}")
        logger.info(f"   - Baixadas: {download_stats['downloaded']}")
        logger.info(f"   - Já existiam: {download_stats['already_exists']}")
        logger.info(f"   - Falharam: {download_stats['failed']}")
        
        if download_stats['errors']:
            logger.warning("⚠️ Erros durante download:")
            for error in download_stats['errors'][:5]:  # Mostrar apenas os primeiros 5
                logger.warning(f"   - {error}")
        
        # 2. Atualizar registros de characters
        logger.info("🔄 Atualizando registros de characters...")
        characters_updated = 0
        
        characters = db.query(Character).filter(
            Character.outfit_image_url.isnot(None)
        ).all()
        
        for character in characters:
            if character.outfit_image_url:
                local_path = outfit_manager.get_image_path(character.outfit_image_url)
                
                if local_path:
                    # Verificar se o arquivo existe
                    full_path = outfit_manager.base_path / local_path
                    if full_path.exists():
                        character.outfit_image_path = local_path
                        characters_updated += 1
                        logger.debug(f"Updated character {character.name}: {local_path}")
        
        # 3. Atualizar registros de snapshots
        logger.info("🔄 Atualizando registros de snapshots...")
        snapshots_updated = 0
        
        snapshots = db.query(CharacterSnapshot).filter(
            CharacterSnapshot.outfit_image_url.isnot(None)
        ).all()
        
        for snapshot in snapshots:
            if snapshot.outfit_image_url:
                local_path = outfit_manager.get_image_path(snapshot.outfit_image_url)
                
                if local_path:
                    # Verificar se o arquivo existe
                    full_path = outfit_manager.base_path / local_path
                    if full_path.exists():
                        snapshot.outfit_image_path = local_path
                        snapshots_updated += 1
                        logger.debug(f"Updated snapshot {snapshot.id}: {local_path}")
        
        # 4. Commit das mudanças
        db.commit()
        
        logger.info(f"✅ Migração concluída:")
        logger.info(f"   - Characters atualizados: {characters_updated}")
        logger.info(f"   - Snapshots atualizados: {snapshots_updated}")
        
        return True
        
    except Exception as e:
        logger.error(f"❌ Erro na migração: {e}")
        return False

def verify_migration():
    """Verificar se a migração foi bem-sucedida"""
    logger.info("🔍 Verificando migração...")
    
    try:
        from app.db.database import get_db
        from app.models.character import Character, CharacterSnapshot
        from app.services.outfit_manager import outfit_manager
        
        db = next(get_db())
        
        # Verificar characters com outfit_image_path
        characters_with_path = db.query(Character).filter(
            Character.outfit_image_path.isnot(None)
        ).count()
        
        snapshots_with_path = db.query(CharacterSnapshot).filter(
            CharacterSnapshot.outfit_image_path.isnot(None)
        ).count()
        
        # Verificar arquivos físicos
        storage_stats = outfit_manager.get_storage_stats()
        
        logger.info(f"📊 Resultado da verificação:")
        logger.info(f"   - Characters com path local: {characters_with_path}")
        logger.info(f"   - Snapshots com path local: {snapshots_with_path}")
        logger.info(f"   - Arquivos físicos: {storage_stats.get('total_files', 0)}")
        logger.info(f"   - Tamanho total: {storage_stats.get('total_size_mb', 0)} MB")
        
        return True
        
    except Exception as e:
        logger.error(f"❌ Erro na verificação: {e}")
        return False

def main():
    """Função principal"""
    logger.info("🚀 Iniciando migração de imagens de outfit...")
    logger.info(f"⏰ Timestamp: {datetime.now()}")
    
    # Verificar se estamos no diretório correto
    if not Path("docker-compose.yml").exists():
        logger.error("❌ Execute este script no diretório raiz do projeto")
        return False
    
    # 1. Backup do banco
    if not run_backup_script():
        logger.error("❌ Falha no backup. Abortando migração.")
        return False
    
    # 2. Verificar conexão
    if not check_database_connection():
        logger.error("❌ Falha na conexão com banco. Abortando migração.")
        return False
    
    # 3. Migrar schema
    if not migrate_database_schema():
        logger.error("❌ Falha na migração do schema. Abortando migração.")
        return False
    
    # 4. Download e migração
    if not download_and_migrate_images():
        logger.error("❌ Falha no download/migração. Abortando.")
        return False
    
    # 5. Verificar resultado
    if not verify_migration():
        logger.error("❌ Falha na verificação. Verifique os logs.")
        return False
    
    logger.info("🎉 Migração concluída com sucesso!")
    logger.info("📁 As imagens estão salvas em: /app/outfits/images/")
    logger.info("💾 Backup salvo em: ./backups/")
    
    return True

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1) 