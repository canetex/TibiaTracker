# Script de Carregamento Automático de Personagens - Taleon

Este diretório contém scripts para fazer scraping automático de personagens dos sites do Taleon e adicioná-los ao sistema via API.

## 📁 Arquivos Disponíveis

### Versões do Script

1. **`auto-load-new-chars-official.py`** ⭐ **RECOMENDADO**
   - Usa a classe `TaleonCharacterScraper` oficial do backend
   - Aproveita todo o tratamento robusto já implementado
   - Suporte automático a compressão gzip
   - Sessão HTTP persistente com aiohttp
   - Headers completos simulando navegador real
   - **Requer**: `aiohttp`, `beautifulsoup4` (dependências do backend)

2. **`auto-load-new-chars-simple.py`**
   - Versão simplificada usando apenas bibliotecas padrão
   - Não requer dependências externas
   - Pode ter problemas com compressão gzip
   - **Requer**: Apenas Python padrão

3. **`auto-load-new-chars.py`**
   - Versão original (deprecated)
   - Mantida para referência

### Scripts de Teste

- **`test-official-script.py`** - Testa a versão oficial
- **`test-simple-script.py`** - Testa a versão simplificada

### Scripts de CRON

- **`setup-cron-deaths.sh`** - Configura CRON para sites de mortes (3 dias)
- **`setup-cron-powergamers.sh`** - Configura CRON para powergamers (diário)
- **`setup-cron-online.sh`** - Configura CRON para online (1h)
- **`setup-all-crons.sh`** - Configura todos os CRONs de uma vez

## 🚀 Uso Recomendado (Versão Oficial)

### Pré-requisitos

1. **Instalar dependências do backend**:
   ```bash
   cd Backend
   pip install -r requirements.txt
   ```

2. **Verificar se o backend está rodando**:
   ```bash
   # O script precisa acessar os módulos do backend
   # Certifique-se de que o ambiente está configurado
   ```

### Execução

```bash
# Executar todos os sites
python3 auto-load-new-chars-official.py

# Executar apenas sites de mortes (recomendado para CRON a cada 3 dias)
python3 auto-load-new-chars-official.py --deaths-only

# Executar apenas powergamers (recomendado para CRON diário)
python3 auto-load-new-chars-official.py --powergamers-only

# Executar apenas online (recomendado para CRON a cada 1h)
python3 auto-load-new-chars-official.py --online-only

# Com opções adicionais
python3 auto-load-new-chars-official.py --deaths-only --max-characters 50 --debug
```

### Testar a Versão Oficial

```bash
# Executar testes completos
python3 test-official-script.py
```

## 🔧 Configuração de CRON

### Configurar Todos os CRONs

```bash
# Dar permissão de execução
chmod +x setup-all-crons.sh

# Executar script de configuração
./setup-all-crons.sh
```

### Configurar CRONs Individuais

```bash
# Sites de mortes (a cada 3 dias às 02:00)
chmod +x setup-cron-deaths.sh
./setup-cron-deaths.sh

# Powergamers (diário às 03:00)
chmod +x setup-cron-powergamers.sh
./setup-cron-powergamers.sh

# Online (a cada hora)
chmod +x setup-cron-online.sh
./setup-cron-online.sh
```

## 📊 Sites Monitorados

### Sites de Mortes (3 dias)
- `https://san.taleon.online/deaths.php`
- `https://aura.taleon.online/deaths.php`
- `https://gaia.taleon.online/deaths.php`

### Sites de Powergamers (diário)
- `https://san.taleon.online/powergamers.php`
- `https://aura.taleon.online/powergamers.php`
- `https://gaia.taleon.online/powergamers.php`

### Sites de Online (1h)
- `https://san.taleon.online/onlinelist.php`
- `https://aura.taleon.online/onlinelist.php`
- `https://gaia.taleon.online/onlinelist.php`

## 🔍 Métodos de Extração

### Deaths (Mortes)
- Extrai links de `characterprofile.php?name=Nome`
- Foca em personagens que morreram recentemente
- Delay: 3.0s entre sites

### Powergamers
- Extrai links de `characterprofile.php?name=Nome`
- Foca em personagens com alta experiência
- Delay: 3.5s entre sites

### Online
- Extrai links de `characterprofile.php?name=Nome`
- Foca em personagens atualmente online
- Delay: 2.5s entre sites

## ⚡ Vantagens da Versão Oficial

| Aspecto | Versão Oficial | Versão Simplificada |
|---------|----------------|-------------------|
| **Compressão** | ✅ Automática (aiohttp) | ❌ Manual (urllib) |
| **Headers** | ✅ Completos | ⚠️ Básicos |
| **Sessão** | ✅ Persistente | ❌ Nova conexão |
| **Dependências** | ❌ aiohttp + bs4 | ✅ Apenas stdlib |
| **Performance** | ✅ Otimizada | ⚠️ Básica |
| **Manutenção** | ✅ Consistente | ⚠️ Separada |
| **Logs** | ✅ Detalhados | ⚠️ Básicos |

## 📝 Logs e Monitoramento

### Arquivos de Log
- `auto-load-new-chars-official.log` - Log da versão oficial
- `auto-load-new-chars-simple.log` - Log da versão simplificada

### Exemplo de Log de Sucesso
```
2024-01-15 10:30:00 - INFO - 🚀 Iniciando carregamento automático de personagens (modo: deaths-only)
2024-01-15 10:30:00 - INFO - 📊 Sites configurados: 9
2024-01-15 10:30:00 - INFO - 🎯 Sites para processar: 3
2024-01-15 10:30:00 - INFO - 🌐 Processando Latest Deaths San...
2024-01-15 10:30:01 - INFO - ✅ Latest Deaths San: 45 personagens encontrados em 1200ms
2024-01-15 10:30:01 - INFO - ✅ Latest Deaths San: 45 personagens para processar
2024-01-15 10:30:04 - INFO - 🌐 Processando Latest Deaths Aura...
2024-01-15 10:30:05 - INFO - ✅ Latest Deaths Aura: 38 personagens encontrados em 1100ms
2024-01-15 10:30:05 - INFO - ✅ Latest Deaths Aura: 38 personagens para processar
2024-01-15 10:30:08 - INFO - 🌐 Processando Latest Deaths Gaia...
2024-01-15 10:30:09 - INFO - ✅ Latest Deaths Gaia: 52 personagens encontrados em 1300ms
2024-01-15 10:30:09 - INFO - ✅ Latest Deaths Gaia: 52 personagens para processar
2024-01-15 10:30:09 - INFO - 🎯 Total de personagens únicos encontrados: 135
2024-01-15 10:30:09 - INFO - 👤 [1/135] Processando: Gates
2024-01-15 10:30:10 - INFO - 🎯 Adicionando personagem: Gates (san)
2024-01-15 10:30:12 - INFO - ✅ Gates (san): Adicionado com sucesso em 2100ms
2024-01-15 10:30:13 - INFO - 👤 [2/135] Processando: Galado
2024-01-15 10:30:14 - INFO - 🎯 Adicionando personagem: Galado (aura)
2024-01-15 10:30:16 - INFO - ✅ Galado (aura): Adicionado com sucesso em 1900ms
...
2024-01-15 10:45:30 - INFO - 🏁 Carregamento automático concluído em 0:15:30
2024-01-15 10:45:30 - INFO - 📊 Estatísticas finais:
2024-01-15 10:45:30 - INFO -    - Sites processados: 3
2024-01-15 10:45:30 - INFO -    - Sites com falha: 0
2024-01-15 10:45:30 - INFO -    - Personagens encontrados: 135
2024-01-15 10:45:30 - INFO -    - Personagens adicionados: 128
2024-01-15 10:45:30 - INFO -    - Personagens com falha: 7
```

## 🛠️ Troubleshooting

### Problemas Comuns

#### 1. Erro de Import
```
ImportError: No module named 'aiohttp'
```
**Solução**: Instalar dependências do backend
```bash
cd Backend
pip install -r requirements.txt
```

#### 2. Erro de Path
```
ImportError: No module named 'app.services.scraping.taleon'
```
**Solução**: Verificar se está executando do diretório correto
```bash
cd Scripts/Manutenção
python3 auto-load-new-chars-official.py
```

#### 3. Timeout nas Requisições
```
asyncio.TimeoutError: Timeout ao acessar...
```
**Solução**: Aumentar timeout ou verificar conectividade
```bash
python3 auto-load-new-chars-official.py --debug
```

#### 4. Nenhum Personagem Encontrado
```
✅ Site: 0 personagens encontrados
```
**Solução**: Verificar se os sites estão acessíveis
```bash
curl -I https://san.taleon.online/deaths.php
```

### Debug e Logs

```bash
# Ativar modo debug
python3 auto-load-new-chars-official.py --debug

# Ver logs em tempo real
tail -f auto-load-new-chars-official.log

# Verificar CRON jobs
crontab -l
```

## 🔄 Atualizações

### Atualizar Scripts no Servidor LXC

```bash
# Fazer commit das mudanças
git add .
git commit -m "Adiciona versão oficial do auto loader"
git push

# Baixar no servidor LXC
wget -O /opt/tibia-tracker/Scripts/Manutenção/auto-load-new-chars-official.py https://raw.githubusercontent.com/seu-usuario/tibia-tracker/main/Scripts/Manutenção/auto-load-new-chars-official.py
wget -O /opt/tibia-tracker/Scripts/Manutenção/test-official-script.py https://raw.githubusercontent.com/seu-usuario/tibia-tracker/main/Scripts/Manutenção/test-official-script.py

# Tornar executável
chmod +x /opt/tibia-tracker/Scripts/Manutenção/auto-load-new-chars-official.py
chmod +x /opt/tibia-tracker/Scripts/Manutenção/test-official-script.py
```

## 📈 Resultados Esperados

### Sites de Mortes (3 dias)
- **Personagens encontrados**: 30-60 por mundo
- **Tempo de execução**: 15-30 minutos
- **Sucesso esperado**: 85-95%

### Powergamers (diário)
- **Personagens encontrados**: 50-100 por mundo
- **Tempo de execução**: 20-40 minutos
- **Sucesso esperado**: 90-98%

### Online (1h)
- **Personagens encontrados**: 100-300 por mundo
- **Tempo de execução**: 30-60 minutos
- **Sucesso esperado**: 80-90%

## 🎯 Próximos Passos

1. **Testar a versão oficial** no ambiente de desenvolvimento
2. **Configurar CRONs** para execução automática
3. **Monitorar logs** para identificar problemas
4. **Ajustar delays** se necessário para evitar sobrecarga
5. **Considerar implementar cache** para evitar reprocessamento

---

**Nota**: A versão oficial é recomendada para produção, pois aproveita toda a infraestrutura robusta já implementada no backend e garante consistência com o resto do sistema. 