# 🚀 Sistema de Auto-Load de Personagens - Taleon

## 📋 Visão Geral

Este sistema automatiza o carregamento de personagens dos sites do Taleon Online, fazendo scraping de múltiplas fontes e adicionando os personagens ao banco de dados via API.

## 🎯 Funcionalidades

- ✅ **Scraping Multi-Site**: 9 sites diferentes (3 por mundo: San, Aura, Gaia)
- ✅ **Múltiplas Fontes**: Latest Deaths, Powergamers, Online Players
- ✅ **API Integration**: Adiciona personagens automaticamente via API
- ✅ **CRON Automation**: Execução automática a cada 3 dias
- ✅ **Logs Detalhados**: Monitoramento completo do processo
- ✅ **Rate Limiting**: Delays configuráveis para não sobrecarregar os sites
- ✅ **Error Handling**: Tratamento robusto de erros e retries

## 📁 Estrutura de Arquivos

```
Scripts/Manutenção/
├── auto-load-new-chars.py          # Script principal de scraping
├── test-taleon-sites.py            # Script de teste dos sites
├── setup-auto-load-cron.sh         # Configuração do CRON
├── taleon-sites-config.json        # Configuração dos sites
├── README-auto-load.md             # Esta documentação
└── auto-load-cron.log              # Logs do CRON (gerado automaticamente)
```

## 🌐 Sites Configurados

### **San (san.taleon.online)**
1. **Latest Deaths San** - Personagens que morreram recentemente
2. **Powergamers San** - Personagens que ganharam mais experiência
3. **Online List San** - Jogadores atualmente online

### **Aura (aura.taleon.online)**
1. **Latest Deaths Aura** - Personagens que morreram recentemente
2. **Powergamers Aura** - Personagens que ganharam mais experiência
3. **Online List Aura** - Jogadores atualmente online

### **Gaia (gaia.taleon.online)**
1. **Latest Deaths Gaia** - Personagens que morreram recentemente
2. **Powergamers Gaia** - Personagens que ganharam mais experiência
3. **Online List Gaia** - Jogadores atualmente online

## 🚀 Como Usar

### **1. Testar os Sites (Recomendado)**

Antes de executar o scraping completo, teste se os sites estão acessíveis:

```bash
cd Scripts/Manutenção/
python3 test-taleon-sites.py
```

**Resultado esperado:**
```
🎯 RELATÓRIO DE TESTES DOS SITES DO TALEON
============================================================
📅 Data: 2025-01-27 15:30:00
🌐 Total de sites testados: 9

📊 ESTATÍSTICAS GERAIS:
   ✅ Sites acessíveis: 9
   ❌ Sites com falha: 0
   👥 Total de personagens encontrados: 1200

🌍 SITES POR MUNDO:
   SAN: 3 acessíveis, 0 falhas, 400 personagens
   AURA: 3 acessíveis, 0 falhas, 400 personagens
   GAIA: 3 acessíveis, 0 falhas, 400 personagens
```

### **2. Executar Scraping Manual**

Para executar o scraping uma vez:

```bash
cd Scripts/Manutenção/
python3 auto-load-new-chars.py
```

**Logs de exemplo:**
```
🎯 Script de Carregamento Automático de Personagens - Taleon
============================================================
🎯 Configurados 6 sites do Taleon para scraping
🚀 Iniciando carregamento automático de personagens...
🔍 [Latest Deaths San] Iniciando scraping: https://san.taleon.online/deaths.php
✅ [Latest Deaths San] Scraping concluído: 50 personagens encontrados em 2500ms
🔍 [Powergamers San] Iniciando scraping: https://san.taleon.online/powergamers.php
✅ [Powergamers San] Scraping concluído: 100 personagens encontrados em 3000ms
🔍 [Online List San] Iniciando scraping: https://san.taleon.online/onlinelist.php
✅ [Online List San] Scraping concluído: 173 personagens encontrados em 2000ms
🌐 Adicionando personagem via API: Gates (san)
✅ Gates adicionado com sucesso (ID: 123)
📈 Progresso san: 10/150 personagens processados
```

### **3. Configurar CRON Automático**

Para executar automaticamente a cada 3 dias:

```bash
cd Scripts/Manutenção/
chmod +x setup-auto-load-cron.sh
./setup-auto-load-cron.sh
```

**O script irá:**
- ✅ Verificar se Python 3 está disponível
- ✅ Tornar o script principal executável
- ✅ Criar backup do CRON atual
- ✅ Adicionar entrada: `0 2 */3 * *` (2:00 AM a cada 3 dias)
- ✅ Salvar logs em `auto-load-cron.log`

### **4. Monitorar Execução**

```bash
# Ver logs em tempo real
tail -f Scripts/Manutenção/auto-load-cron.log

# Ver entradas do CRON
crontab -l

# Executar manualmente se necessário
cd Scripts/Manutenção/
python3 auto-load-new-chars.py
```

## ⚙️ Configuração

### **Arquivo de Configuração: `taleon-sites-config.json`**

```json
{
  "taleon_sites": {
    "sites": [
      {
        "id": "deaths_san",
        "name": "Latest Deaths San",
        "world": "san",
        "base_url": "https://san.taleon.online",
        "character_list_url": "https://san.taleon.online/deaths.php",
        "enabled": true,
        "delay_seconds": 3.0,
        "max_characters": 100,
        "scraping_method": "deaths"
      }
    ]
  }
}
```

### **Parâmetros Configuráveis**

- **`enabled`**: Habilitar/desabilitar site
- **`delay_seconds`**: Delay entre requisições
- **`max_characters`**: Máximo de personagens por site
- **`timeout_seconds`**: Timeout das requisições
- **`scraping_method`**: Método de extração (deaths, powergamers)

## 📊 Métodos de Scraping

### **1. Latest Deaths**
- **URL**: `{world}.taleon.online/deaths.php`
- **Extrai**: Personagens que morreram recentemente
- **Limite**: 100 personagens por mundo
- **Prioridade**: Alta (personagens ativos que morreram)

### **2. Powergamers**
- **URL**: `{world}.taleon.online/powergamers.php`
- **Extrai**: Personagens que ganharam mais experiência
- **Limite**: 150 personagens por mundo
- **Prioridade**: Média (personagens ativos que estão evoluindo)

### **3. Online List**
- **URL**: `{world}.taleon.online/onlinelist.php`
- **Extrai**: Jogadores atualmente online
- **Limite**: 200 personagens por mundo
- **Prioridade**: Baixa (captura personagens ativos no momento)

## 🔧 API Integration

O sistema usa a API de busca para adicionar personagens:

```http
GET /api/v1/characters/search?name={CHAR}&server=taleon&world={WORLD}
```

**Comportamento:**
- ✅ **Se existe**: Retorna dados do banco
- ✅ **Se não existe**: Faz scraping e cria automaticamente
- ✅ **Logs detalhados**: Sucesso, falha, duplicatas

## 📈 Estatísticas e Relatórios

### **Relatório de Execução**
```
🎉 Carregamento automático concluído!
📊 Relatório Final:
   ⏱️  Duração total: 0:25:30
   🌐 Sites processados: 9
   ❌ Sites com falha: 0
   👥 Personagens encontrados: 1200
   ✅ Personagens adicionados: 150
   ℹ️  Personagens já existentes: 1050
   ❌ Personagens com falha: 0
```

### **Logs Detalhados**
- **Scraping**: Tempo, personagens encontrados, erros
- **API**: Sucessos, falhas, duplicatas
- **Performance**: Duração por site e total
- **Erros**: Detalhes completos para debugging

## 🛡️ Segurança e Rate Limiting

### **Headers HTTP**
```python
{
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36...',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
    'Accept-Language': 'pt-BR,pt;q=0.9,en;q=0.8',
    'Accept-Encoding': 'gzip, deflate, br',
    'Connection': 'keep-alive',
    'Upgrade-Insecure-Requests': '1',
}
```

### **Delays Configuráveis**
- **Latest Deaths**: 3.0s (personagens ativos que morreram)
- **Powergamers**: 3.5s (personagens ativos que estão evoluindo)

### **Timeouts**
- **Requisições**: 30-45 segundos
- **Sessão**: 60 segundos
- **Retries**: 3 tentativas

## 🔍 Troubleshooting

### **Problemas Comuns**

#### **1. Sites não acessíveis**
```bash
# Testar conectividade
curl -I https://san.taleon.online/deaths.php
curl -I https://san.taleon.online/powergamers.php

# Verificar DNS
nslookup san.taleon.online
```

#### **2. API não responde**
```bash
# Testar API
curl "http://localhost:8000/api/v1/characters/supported-servers"

# Verificar se o backend está rodando
docker ps | grep tibia-tracker-backend
```

#### **3. CRON não executa**
```bash
# Verificar logs do sistema
sudo tail -f /var/log/syslog | grep CRON

# Verificar permissões
ls -la auto-load-new-chars.py
```

#### **4. Muitos erros de scraping**
```bash
# Aumentar delays no config
"delay_seconds": 5.0

# Reduzir limite de personagens
"max_characters": 50
```

### **Logs de Debug**

```bash
# Logs detalhados
tail -f auto-load-cron.log | grep -E "(ERROR|WARNING|CRITICAL)"

# Logs de um site específico
tail -f auto-load-cron.log | grep "Latest Deaths San"
tail -f auto-load-cron.log | grep "Powergamers San"

# Logs de API
tail -f auto-load-cron.log | grep "API"
```

## 📝 Comandos Úteis

### **Gerenciamento**
```bash
# Ver CRON atual
crontab -l

# Editar CRON
crontab -e

# Remover entrada do CRON
crontab -r

# Executar manualmente
python3 auto-load-new-chars.py

# Testar sites
python3 test-taleon-sites.py
```

### **Monitoramento**
```bash
# Logs em tempo real
tail -f auto-load-cron.log

# Últimas execuções
tail -20 auto-load-cron.log

# Estatísticas de execução
grep "Carregamento automático concluído" auto-load-cron.log
```

### **Manutenção**
```bash
# Backup do CRON
crontab -l > crontab_backup_$(date +%Y%m%d).txt

# Limpar logs antigos
find . -name "*.log" -mtime +30 -delete

# Verificar espaço em disco
df -h
```

## 🎯 Próximos Passos

### **Melhorias Futuras**
1. **Mais Sites**: Adicionar outros servidores (Rubini, etc.)
2. **Filtros Inteligentes**: Evitar personagens inativos
3. **Priorização**: Personagens mais ativos primeiro
4. **Notificações**: Alertas por email/telegram
5. **Dashboard**: Interface web para monitoramento
6. **Machine Learning**: Detectar padrões de atividade

### **Configurações Avançadas**
1. **Proxy Rotation**: Para evitar bloqueios
2. **User Agent Rotation**: Simular diferentes navegadores
3. **Geolocalização**: Delays baseados em região
4. **Análise de Performance**: Métricas detalhadas
5. **Auto-scaling**: Ajustar delays automaticamente

---

## 📞 Suporte

Para dúvidas ou problemas:
1. Verificar logs em `auto-load-cron.log`
2. Executar `test-taleon-sites.py` para diagnóstico
3. Verificar configuração em `taleon-sites-config.json`
4. Consultar esta documentação

**🎉 Sistema pronto para uso!** 