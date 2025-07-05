# Scripts de Manutenção - Tibia Tracker

Este diretório contém scripts para manutenção e migração do sistema Tibia Tracker.

## 📁 Arquivos Disponíveis

### 🔄 Migração de Imagens de Outfit

- **`migrate-outfit-images.py`** - Script principal de migração
- **`run-outfit-migration-simple.sh`** - Script de execução simplificado
- **`test-migration.py`** - Script de teste da migração

### 💾 Backup

- **`backup-database-simple.sh`** - Script de backup simplificado

## 🚀 Como Usar

### Migração de Imagens de Outfit

1. **Executar migração completa:**
   ```bash
   ./Scripts/Manutenção/run-outfit-migration-simple.sh
   ```

2. **Testar migração:**
   ```bash
   docker exec -w /app -e PYTHONPATH=/app tibia-tracker-backend python /app/Scripts/Manutenção/test-migration.py
   ```

3. **Executar migração manualmente:**
   ```bash
   # Exportar URLs do banco
   docker exec tibia-tracker-postgres psql -U tibia_user -d tibia_tracker -t -c "SELECT DISTINCT outfit_image_url FROM characters WHERE outfit_image_url IS NOT NULL AND outfit_image_url != '';" > /tmp/outfit_urls.txt
   
   # Copiar para o container
   docker cp /tmp/outfit_urls.txt tibia-tracker-backend:/tmp/outfit_urls.txt
   
   # Executar migração
   docker exec -w /app -e PYTHONPATH=/app tibia-tracker-backend python /app/Scripts/Manutenção/migrate-outfit-images.py
   ```

### Backup do Banco

```bash
./Scripts/Manutenção/backup-database-simple.sh
```

## 📊 O que a Migração Faz

1. **Backup Automático** - Faz backup completo do banco antes da migração
2. **Exportação de URLs** - Extrai todas as URLs únicas de outfit do banco
3. **Download de Imagens** - Baixa todas as imagens de outfit
4. **Organização** - Organiza por hash MD5 (evita duplicatas)
5. **Logs Detalhados** - Registra todo o processo

## 📁 Estrutura de Arquivos

```
/app/outfits/images/     # Imagens baixadas (dentro do container)
/app/logs/               # Logs da migração
/tmp/outfit_urls.txt     # URLs exportadas do banco
./backups/               # Backups do banco (no host)
```

## 🔧 Solução de Problemas

### Erro de Permissão
```bash
# Criar diretórios com permissões corretas
docker exec -u root tibia-tracker-backend mkdir -p /app/outfits/images /app/logs
docker exec -u root tibia-tracker-backend chown -R tibia:tibia /app/outfits /app/logs
```

### Erro de Conexão
```bash
# Verificar se os containers estão rodando
docker-compose ps

# Verificar logs do backend
docker-compose logs backend
```

### Verificar Progresso
```bash
# Contar imagens baixadas
docker exec tibia-tracker-backend find /app/outfits/images -type f | wc -l

# Ver tamanho total
docker exec tibia-tracker-backend du -sh /app/outfits/images
```

## 📈 Estatísticas Esperadas

- **URLs únicas:** ~630 (baseado no banco atual)
- **Tempo estimado:** 10-15 minutos
- **Tamanho total:** ~50-100 MB (dependendo das imagens)
- **Formato:** .gif

## ✅ Verificação de Sucesso

Após a migração, verifique:

1. **Arquivos baixados:**
   ```bash
   docker exec tibia-tracker-backend ls -la /app/outfits/images/ | head -10
   ```

2. **Logs da migração:**
   ```bash
   docker exec tibia-tracker-backend cat /app/logs/migration_outfit_images.log | tail -20
   ```

3. **Backup criado:**
   ```bash
   ls -la ./backups/ | tail -5
   ```

## 🔄 Restauração

Para restaurar um backup:
```bash
gunzip -c ./backups/tibia_tracker_backup_YYYYMMDD_HHMMSS.sql.gz | docker exec -i tibia-tracker-postgres psql -U tibia_user -d tibia_tracker
``` 