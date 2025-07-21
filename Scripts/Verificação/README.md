# Scripts de Verificação - Tibia Tracker

Este diretório contém scripts para verificação e diagnóstico do sistema Tibia Tracker.

## 📁 Arquivos Disponíveis

### 🔍 Verificação de Dados

- **`check_character.py`** - Consultar dados de um personagem específico
- **`check_dates.py`** - Verificar datas dos snapshots
- **`check_experience_data.py`** - Verificar dados de experiência no banco
- **`check_character_ids.py`** - Verificar IDs dos personagens
- **`check_snapshots_debug.py`** - Debug detalhado dos snapshots

### 🎨 Verificação de Outfits

- **`check_outfit_field.py`** - Verificar campos de outfit nas tabelas
- **`check_outfit_field_simple.py`** - Versão simplificada da verificação de outfits

### 🏥 Verificação de Saúde do Sistema

- **`health-check.sh`** - Verificação completa de saúde do sistema
- **`network-test.sh`** - Teste de conectividade de rede

## 🚀 Como Usar

### Verificação de Personagens

```bash
# Consultar dados de um personagem específico
docker exec -w /app -e PYTHONPATH=/app tibia-tracker-backend python /app/Scripts/Verificação/check_character.py

# Verificar datas dos snapshots
docker exec -w /app -e PYTHONPATH=/app tibia-tracker-backend python /app/Scripts/Verificação/check_dates.py

# Verificar dados de experiência
docker exec -w /app -e PYTHONPATH=/app tibia-tracker-backend python /app/Scripts/Verificação/check_experience_data.py
```

### Verificação de Outfits

```bash
# Verificar campos de outfit
docker exec -w /app -e PYTHONPATH=/app tibia-tracker-backend python /app/Scripts/Verificação/check_outfit_field.py

# Versão simplificada
docker exec -w /app -e PYTHONPATH=/app tibia-tracker-backend python /app/Scripts/Verificação/check_outfit_field_simple.py
```

### Verificação de Saúde do Sistema

```bash
# Verificação completa de saúde
sudo ./Scripts/Verificação/health-check.sh

# Teste de conectividade de rede
sudo ./Scripts/Verificação/network-test.sh
```

## 📊 O que Cada Script Faz

### **check_character.py**
- Consulta dados completos de um personagem específico
- Mostra informações como ID, nome, servidor, world, level, vocação, etc.
- Útil para verificar se um personagem está no banco

### **check_dates.py**
- Verifica as datas dos snapshots no banco
- Mostra as últimas 15 datas com snapshots
- Verifica especificamente os dias 11, 12 e 13 de julho de 2025
- Útil para debug de problemas de data

### **check_experience_data.py**
- Verifica dados de experiência no banco
- Mostra estatísticas gerais
- Identifica snapshots com experiência > 0
- Verifica personagens sem experiência
- Analisa campos específicos como exp_date

### **check_outfit_field.py**
- Verifica se os campos de outfit existem nas tabelas
- Confirma se a migração de outfits foi executada
- Mostra status dos campos outfit_image_path

### **health-check.sh**
- Verificação completa do sistema
- Testa containers, conectividade, banco de dados
- Verifica segurança e performance
- Gera relatório detalhado

### **network-test.sh**
- Testa conectividade externa e interna
- Verifica portas e comunicação entre containers
- Testa latência e performance
- Analisa rotas e endpoints

## 🔧 Solução de Problemas

### Erro de Importação
```bash
# Se houver erro de importação, verificar PYTHONPATH
export PYTHONPATH=/app
docker exec -w /app tibia-tracker-backend python /app/Scripts/Verificação/check_character.py
```

### Erro de Conexão com Banco
```bash
# Verificar se o container está rodando
docker-compose ps postgres

# Verificar logs do banco
docker-compose logs postgres
```

### Erro de Permissão
```bash
# Dar permissão de execução aos scripts
chmod +x Scripts/Verificação/*.sh
```

## 📈 Exemplos de Uso

### Verificar Personagem Específico
```bash
# Editar o script para mudar o nome do personagem
nano Scripts/Verificação/check_character.py
# Alterar a linha: character_name = "The Crusty"

# Executar
docker exec -w /app -e PYTHONPATH=/app tibia-tracker-backend python /app/Scripts/Verificação/check_character.py
```

### Verificar Saúde Completa
```bash
# Executar verificação completa
sudo ./Scripts/Verificação/health-check.sh

# Ver resultado
cat /var/log/tibia-tracker/health-check.log
```

### Testar Conectividade
```bash
# Executar teste de rede
sudo ./Scripts/Verificação/network-test.sh

# Ver resultado
cat /var/log/tibia-tracker/network-test.log
```

## ✅ Verificações Recomendadas

### Diárias
- `health-check.sh` - Verificação geral do sistema
- `check_experience_data.py` - Verificar dados de experiência

### Semanais
- `network-test.sh` - Teste de conectividade
- `check_outfit_field.py` - Verificar campos de outfit

### Quando Necessário
- `check_character.py` - Debug de personagens específicos
- `check_dates.py` - Debug de problemas de data
- `check_snapshots_debug.py` - Debug detalhado de snapshots

## 📝 Logs

Os scripts de verificação geram logs em:
- `/var/log/tibia-tracker/health-check.log`
- `/var/log/tibia-tracker/network-test.log`

Para verificar logs em tempo real:
```bash
tail -f /var/log/tibia-tracker/health-check.log
``` 