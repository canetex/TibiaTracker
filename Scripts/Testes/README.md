# Scripts de Teste - Tibia Tracker

Este diretório contém scripts para testes automatizados e manuais do sistema Tibia Tracker.

## 📁 Arquivos Disponíveis

### 🧪 Testes de Frontend

- **`debug-frontend.js`** - Debug completo do frontend usando Puppeteer
- **`test-frontend-components.js`** - Teste de componentes do frontend
- **`test-frontend-guild-filter.js`** - Teste específico do filtro por guild
- **`test-frontend-simple.js`** - Teste simples do frontend sem dependências
- **`simple-frontend-test.js`** - Teste básico de carregamento do frontend
- **`test-final-guild-filter.js`** - Teste final do filtro por guild

### 🔧 Testes de Backend

- **`api-tests.sh`** - Testes específicos da API
- **`test-endpoints.sh`** - Teste de endpoints básicos
- **`test-correct-endpoints.sh`** - Teste de endpoints com prefixo correto
- **`test-activity-filter.py`** - Teste do filtro de atividade
- **`test_world_field.py`** - Teste do campo world

### 🎯 Testes Específicos de Personagens

- **`test_sr_burns_simple.py`** - Teste simples do Sr Burns
- **`test_sr_burns_complete.py`** - Teste completo do Sr Burns
- **`test_sr_burns_complete_fixed.py`** - Teste corrigido do Sr Burns
- **`test_gates_scraping.py`** - Teste específico do scraping do Gates

### 🔍 Testes de Migração e Organização

- **`test-migration.py`** - Teste da migração de imagens de outfit
- **`test-outfit-organization.py`** - Teste da organização por variação de outfit

### 🐛 Testes de Debug

- **`debug-bulk-add.sh`** - Debug do problema de encoding no bulk-add

### 🚀 Testes Automatizados

- **`run-tests.sh`** - Execução de todos os testes automatizados

## 🚀 Como Usar

### Testes de Frontend

```bash
# Debug completo do frontend (requer Node.js e Puppeteer)
node Scripts/Testes/debug-frontend.js

# Teste simples do frontend
node Scripts/Testes/test-frontend-simple.js

# Teste de componentes
node Scripts/Testes/test-frontend-components.js

# Teste do filtro por guild
node Scripts/Testes/test-frontend-guild-filter.js
```

### Testes de Backend

```bash
# Testes da API
sudo ./Scripts/Testes/api-tests.sh

# Teste de endpoints
./Scripts/Testes/test-endpoints.sh

# Teste de endpoints com prefixo correto
./Scripts/Testes/test-correct-endpoints.sh

# Teste do filtro de atividade
docker exec -w /app -e PYTHONPATH=/app tibia-tracker-backend python /app/Scripts/Testes/test-activity-filter.py
```

### Testes de Personagens Específicos

```bash
# Teste do Sr Burns
docker exec -w /app -e PYTHONPATH=/app tibia-tracker-backend python /app/Scripts/Testes/test_sr_burns_simple.py

# Teste completo do Sr Burns
docker exec -w /app -e PYTHONPATH=/app tibia-tracker-backend python /app/Scripts/Testes/test_sr_burns_complete.py

# Teste do Gates
docker exec -w /app -e PYTHONPATH=/app tibia-tracker-backend python /app/Scripts/Testes/test_gates_scraping.py
```

### Testes de Migração

```bash
# Teste da migração de outfits
docker exec -w /app -e PYTHONPATH=/app tibia-tracker-backend python /app/Scripts/Testes/test-migration.py

# Teste da organização de outfits
docker exec -w /app -e PYTHONPATH=/app tibia-tracker-backend python /app/Scripts/Testes/test-outfit-organization.py
```

### Testes Automatizados

```bash
# Executar todos os testes
sudo ./Scripts/Testes/run-tests.sh
```

## 📊 O que Cada Script Faz

### **debug-frontend.js**
- Debug completo do frontend usando Puppeteer
- Verifica carregamento da página, elementos, console e erros
- Testa conectividade e funcionalidade dos componentes
- Gera relatório detalhado de problemas

### **test-frontend-simple.js**
- Teste simples sem dependências externas
- Verifica se o HTML está correto
- Analisa referências de JavaScript
- Identifica possíveis problemas de build

### **test-frontend-components.js**
- Testa componentes específicos do frontend
- Verifica se a API está funcionando
- Testa carregamento de dados
- Valida campos dos personagens

### **test-frontend-guild-filter.js**
- Teste específico do filtro por guild
- Verifica se os dados de guild estão sendo carregados
- Testa filtros por guild específicas
- Valida funcionamento do endpoint

### **api-tests.sh**
- Testes automatizados da API
- Verifica endpoints básicos e de performance
- Testa latência e throughput
- Gera relatório de resultados

### **test_sr_burns_simple.py**
- Teste simples do personagem Sr Burns
- Verifica snapshots no banco
- Faz scraping e compara dados
- Cria novo snapshot para teste

### **test-migration.py**
- Testa migração de imagens de outfit
- Verifica download de imagens
- Testa organização de arquivos
- Valida estrutura de diretórios

### **run-tests.sh**
- Executa todos os testes automatizados
- Testa infraestrutura, banco, API, frontend
- Verifica performance e segurança
- Gera relatório completo

## 🔧 Solução de Problemas

### Erro de Dependências Node.js
```bash
# Instalar dependências para debug-frontend.js
npm install puppeteer node-fetch

# Ou usar versão sem dependências
node Scripts/Testes/test-frontend-simple.js
```

### Erro de Importação Python
```bash
# Verificar PYTHONPATH
export PYTHONPATH=/app
docker exec -w /app tibia-tracker-backend python /app/Scripts/Testes/test_sr_burns_simple.py
```

### Erro de Permissão
```bash
# Dar permissão de execução aos scripts
chmod +x Scripts/Testes/*.sh
```

## 📈 Exemplos de Uso

### Debug de Frontend
```bash
# Debug completo
node Scripts/Testes/debug-frontend.js

# Se houver problemas, usar teste simples
node Scripts/Testes/test-frontend-simple.js
```

### Teste de API
```bash
# Teste básico
./Scripts/Testes/test-endpoints.sh

# Teste completo
sudo ./Scripts/Testes/api-tests.sh
```

### Teste de Personagem
```bash
# Teste simples
docker exec -w /app -e PYTHONPATH=/app tibia-tracker-backend python /app/Scripts/Testes/test_sr_burns_simple.py

# Verificar logs
docker-compose logs backend
```

### Teste Automatizado Completo
```bash
# Executar todos os testes
sudo ./Scripts/Testes/run-tests.sh

# Ver relatório
cat /var/log/tibia-tracker/test-reports/test-report-*.txt
```

## ✅ Testes Recomendados

### Diários
- `test-frontend-simple.js` - Verificar se frontend está funcionando
- `test-endpoints.sh` - Verificar se API está respondendo

### Semanais
- `run-tests.sh` - Teste completo do sistema
- `test_sr_burns_simple.py` - Verificar scraping

### Quando Necessário
- `debug-frontend.js` - Debug de problemas no frontend
- `test-migration.py` - Verificar migrações
- `debug-bulk-add.sh` - Debug de problemas de encoding

## 📝 Logs

Os testes geram logs em:
- `/var/log/tibia-tracker/tests.log`
- `/var/log/tibia-tracker/api-tests.log`
- `/var/log/tibia-tracker/test-reports/`

Para verificar logs em tempo real:
```bash
tail -f /var/log/tibia-tracker/tests.log
```

## 🎯 Dicas de Uso

### Para Desenvolvedores
- Use `debug-frontend.js` para problemas complexos no frontend
- Use `test_sr_burns_simple.py` para testar scraping
- Use `run-tests.sh` antes de commits importantes

### Para Administradores
- Execute `run-tests.sh` semanalmente
- Monitore logs de testes
- Use testes específicos para problemas conhecidos

### Para Debug
- Comece com testes simples
- Use logs para identificar problemas
- Execute testes em ordem crescente de complexidade 