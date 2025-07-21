# Scripts de Manutenção - Tibia Tracker

Este diretório contém scripts para manutenção e migração do sistema Tibia Tracker.

## 📁 Arquivos Disponíveis

### 🔄 Migração de Imagens de Outfit

- **`migrate-outfit-images.py`** - Script principal de migração
- **`run-outfit-migration-simple.sh`** - Script de execução simplificado
- **`test-migration.py`** - Script de teste da migração

### 🗄️ Migração de Estrutura do Banco

- **`add_outfit_fields.sql`** - Adiciona campos de outfit nas tabelas
- **`add_missing_fields.sql`** - Adiciona campos faltantes nas tabelas
- **`apply-outfit-fields-migration.sh`** - Script para aplicar migrações de outfit

### 💾 Backup

- **`backup-database-simple.sh`** - Script de backup simplificado
- **`full-backup-production.sh`** - Script de backup completo para produção

### 🔄 Atualização de Dados

- **`update_all_guilds.sh`** - Atualiza guilds de todos os personagens

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

### Migração de Estrutura do Banco

```bash
# Aplicar migrações de outfit e campos faltantes
./Scripts/Manutenção/apply-outfit-fields-migration.sh
```

### Atualização de Guilds

```bash
# Atualizar guilds de todos os personagens
./Scripts/Manutenção/update_all_guilds.sh
```

**O que este script faz:**
1. Cria backup automático do banco
2. Aplica `add_outfit_fields.sql` (campos de outfit)
3. Aplica `add_missing_fields.sql` (campos faltantes)
4. Reinicia o backend
5. Verifica se tudo funcionou

## 📊 O que a Migração Faz

1. **Backup Automático** - Faz backup completo do banco antes da migração
2. **Exportação de URLs** - Extrai todas as URLs únicas de outfit do banco
3. **Download de Imagens** - Baixa todas as imagens de outfit
4. **Organização** - Organiza por hash MD5 (evita duplicatas)
5. **Logs Detalhados** - Registra todo o processo

## 🔄 O que o Script de Atualização de Guilds Faz

1. **Lista Personagens** - Obtém todos os personagens da API
2. **Refresh Individual** - Faz refresh de cada personagem para atualizar dados
3. **Atualiza Guilds** - Extrai e atualiza informações de guild
4. **Estatísticas** - Mostra progresso e resultados
5. **Rate Limiting** - Pausa entre requisições para não sobrecarregar

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

### Problemas com Atualização de Guilds
```bash
# Verificar se a API está funcionando
curl -s http://localhost:8000/health

# Verificar se há personagens
curl -s http://localhost:8000/api/v1/characters?limit=5

# Verificar logs do backend
docker-compose logs backend | tail -20
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

Após a atualização de guilds, verifique:

1. **Personagens com guild:**
   ```bash
   curl -s "http://localhost:8000/api/v1/characters?limit=10" | jq '.characters[] | select(.guild != null) | {name: .name, guild: .guild}' | head -10
   ```

2. **Estatísticas de guilds:**
   ```bash
   curl -s "http://localhost:8000/api/v1/characters?limit=1000" | jq '.characters | group_by(.guild) | map({guild: .[0].guild, count: length}) | sort_by(.count) | reverse'
   ```

## 🔄 Restauração

Para restaurar um backup:
```bash
gunzip -c ./backups/tibia_tracker_backup_YYYYMMDD_HHMMSS.sql.gz | docker exec -i tibia-tracker-postgres psql -U tibia_user -d tibia_tracker
``` 