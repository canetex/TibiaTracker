# 🤖 Solução de Automação N8N para Rubinot

## 📋 Problema Identificado

O site do Rubinot (https://rubinot.com.br) está protegido pelo **Cloudflare** com desafio anti-bot, retornando HTTP 403 para todas as requisições automatizadas.

## 🎯 Solução Proposta: N8N Self-Hosted

### Por que N8N?

1. **Browser Automation**: N8N pode usar browsers reais (Chrome/Firefox)
2. **Contorna Cloudflare**: Simula navegação humana real
3. **Self-Hosted**: Controle total sobre a infraestrutura
4. **Integração**: Pode enviar dados diretamente para nossa API
5. **Escalabilidade**: Suporta múltiplos workers

## 🏗️ Arquitetura da Solução

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   N8N Worker    │    │   Tibia Tracker │    │   Rubinot Site  │
│                 │    │   API           │    │   (Cloudflare)  │
│ ┌─────────────┐ │    │                 │    │                 │
│ │ HTTP Request│ │───▶│ POST /api/v1/   │    │                 │
│ │ Browser     │ │    │ characters/     │    │                 │
│ │ Automation  │ │    │ scrape-with-    │    │                 │
│ │             │ │    │ history         │    │                 │
│ └─────────────┘ │    └─────────────────┘    └─────────────────┘
└─────────────────┘
```

## 🚀 Implementação

### 1. Instalar N8N no Servidor

```bash
# Instalar N8N via Docker
docker run -d \
  --name n8n \
  -p 5678:5678 \
  -v n8n_data:/home/node/.n8n \
  -e N8N_BASIC_AUTH_ACTIVE=true \
  -e N8N_BASIC_AUTH_USER=admin \
  -e N8N_BASIC_AUTH_PASSWORD=your-secure-password \
  n8nio/n8n:latest
```

### 2. Workflow N8N para Rubinot

#### Estrutura do Workflow:
1. **Trigger**: Manual ou agendado
2. **Read CSV**: Ler arquivo Rubinot.csv
3. **Browser Automation**: Acessar site do Rubinot
4. **Data Extraction**: Extrair dados do personagem
5. **API Call**: Enviar dados para Tibia Tracker
6. **Error Handling**: Tratamento de erros
7. **Rate Limiting**: Delays entre requests

#### Configuração do Browser Node:
```json
{
  "url": "https://rubinot.com.br/?subtopic=characters&name={{$json.character_name}}",
  "waitUntil": "networkidle",
  "timeout": 30000,
  "userAgent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
}
```

#### Extração de Dados:
```javascript
// JavaScript para extrair dados da página
const page = $input.first().json;

// Extrair level
const levelMatch = page.content.match(/level[:\s]*(\d+)/i);
const level = levelMatch ? parseInt(levelMatch[1]) : 0;

// Extrair vocation
const vocationMatch = page.content.match(/vocation[:\s]*([^\n]+)/i);
const vocation = vocationMatch ? vocationMatch[1].trim() : 'None';

// Extrair guild
const guildMatch = page.content.match(/guild[:\s]*([^\n]+)/i);
const guild = guildMatch ? guildMatch[1].trim() : null;

return {
  name: $json.character_name,
  level: level,
  vocation: vocation,
  guild: guild,
  world: $json.world,
  server: 'rubinot'
};
```

### 3. Integração com Tibia Tracker

#### API Call Node:
```json
{
  "url": "http://localhost:8000/api/v1/characters/scrape-with-history",
  "method": "POST",
  "qs": {
    "server": "rubinot",
    "world": "{{$json.world}}",
    "character_name": "{{$json.name}}"
  },
  "body": {
    "level": "{{$json.level}}",
    "vocation": "{{$json.vocation}}",
    "guild": "{{$json.guild}}"
  }
}
```

## 📊 Configuração de Performance

### Para Volume Alto (+10.000 chars):

```yaml
# docker-compose.yml para N8N
version: '3.8'
services:
  n8n:
    image: n8nio/n8n:latest
    container_name: n8n-rubinot
    ports:
      - "5678:5678"
    environment:
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=admin
      - N8N_BASIC_AUTH_PASSWORD=your-password
      - N8N_EXECUTIONS_PROCESS=main
      - N8N_EXECUTIONS_MODE=regular
      - N8N_QUEUE_BULL_REDIS_HOST=redis
      - N8N_QUEUE_BULL_REDIS_PORT=6379
    volumes:
      - n8n_data:/home/node/.n8n
    depends_on:
      - redis
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    container_name: n8n-redis
    restart: unless-stopped
```

### Configurações de Rate Limiting:
- **Delay entre requests**: 3-5 segundos
- **Batch size**: 50-100 personagens por execução
- **Retry attempts**: 3 tentativas por personagem
- **Timeout**: 30 segundos por página

## 🔧 Alternativas Self-Hosted

### 1. **Playwright/Selenium**
```python
# Exemplo com Playwright
from playwright.async_api import async_playwright

async def scrape_rubinot_character(character_name):
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        page = await browser.new_page()
        
        # Configurar headers realistas
        await page.set_extra_http_headers({
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        })
        
        # Acessar página
        await page.goto(f'https://rubinot.com.br/?subtopic=characters&name={character_name}')
        await page.wait_for_load_state('networkidle')
        
        # Extrair dados
        level = await page.locator('text=/level[:\s]*(\d+)/i').text_content()
        
        await browser.close()
        return {'level': level}
```

### 2. **Puppeteer**
```javascript
// Exemplo com Puppeteer
const puppeteer = require('puppeteer');

async function scrapeRubinot(characterName) {
  const browser = await puppeteer.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });
  
  const page = await browser.newPage();
  await page.setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
  
  await page.goto(`https://rubinot.com.br/?subtopic=characters&name=${characterName}`);
  await page.waitForSelector('body');
  
  const level = await page.$eval('body', el => {
    const match = el.textContent.match(/level[:\s]*(\d+)/i);
    return match ? parseInt(match[1]) : 0;
  });
  
  await browser.close();
  return { level };
}
```

### 3. **Scrapy com Selenium**
```python
# Exemplo com Scrapy + Selenium
import scrapy
from selenium import webdriver
from selenium.webdriver.chrome.options import Options

class RubinotSpider(scrapy.Spider):
    name = 'rubinot'
    
    def __init__(self):
        chrome_options = Options()
        chrome_options.add_argument('--headless')
        chrome_options.add_argument('--no-sandbox')
        self.driver = webdriver.Chrome(options=chrome_options)
    
    def parse_character(self, response):
        character_name = response.meta['character_name']
        self.driver.get(f'https://rubinot.com.br/?subtopic=characters&name={character_name}')
        
        # Extrair dados usando Selenium
        level_element = self.driver.find_element_by_xpath("//text()[contains(., 'level')]")
        level = int(re.search(r'level[:\s]*(\d+)', level_element.text).group(1))
        
        yield {
            'name': character_name,
            'level': level,
            'server': 'rubinot'
        }
```

## 📈 Monitoramento e Logs

### Logs do N8N:
```bash
# Ver logs do N8N
docker logs n8n-rubinot -f

# Ver execuções
curl -u admin:password http://localhost:5678/api/v1/executions
```

### Métricas de Performance:
- **Personagens processados por hora**
- **Taxa de sucesso**
- **Tempo médio por personagem**
- **Erros e retries**

## 🎯 Próximos Passos

1. **Implementar N8N**: Configurar ambiente de automação
2. **Criar Workflow**: Desenvolver workflow específico para Rubinot
3. **Testar Performance**: Validar com pequeno volume
4. **Escalar**: Aplicar para todos os 9.177 personagens
5. **Monitorar**: Acompanhar execução e performance

## 💡 Vantagens da Solução

✅ **Contorna Cloudflare**: Usa browser real
✅ **Self-Hosted**: Controle total
✅ **Escalável**: Suporta volume alto
✅ **Integrado**: Envia dados direto para API
✅ **Monitorável**: Logs e métricas detalhadas
✅ **Flexível**: Fácil de adaptar para outros servidores 