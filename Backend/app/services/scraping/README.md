# 🕷️ Sistema de Scraping Desacoplado

## 📋 Visão Geral

Este módulo implementa uma arquitetura desacoplada para scraping de personagens de diferentes servidores de Tibia. Cada servidor possui seu próprio scraper especializado, mas todos seguem uma interface comum padronizada.

## 🏗️ Arquitetura

```
scraping/
├── __init__.py              # Interface unificada (ScrapingManager)
├── base.py                  # Classe base abstrata
├── taleon.py               # Scraper do Taleon ✅
├── rubini_template.py      # Template para novos scrapers
└── [futuros]...            # Novos servidores
```

### 🔧 Componentes

- **`BaseCharacterScraper`**: Classe abstrata que define a interface comum
- **`ScrapingManager`**: Gerenciador que escolhe o scraper correto automaticamente
- **`ScrapingResult`**: Formato padronizado de retorno
- **Scrapers específicos**: Implementações para cada servidor

## 🚀 Como Usar

### Uso Básico

```python
from app.services.scraping import scrape_character_data

# Fazer scraping automaticamente
result = await scrape_character_data("taleon", "san", "Gates")

if result.success:
    character_data = result.data
    print(f"Personagem: {character_data['name']}")
    print(f"Level: {character_data['level']}")
else:
    print(f"Erro: {result.error_message}")
    print(f"Tentar novamente em: {result.retry_after}")
```

### Uso Avançado

```python
from app.services.scraping import ScrapingManager

# Verificar servidores suportados
servers = ScrapingManager.get_supported_servers()
print(f"Servidores: {servers}")

# Obter informações de um servidor
info = ScrapingManager.get_server_info("taleon")
print(f"Mundos do Taleon: {info['supported_worlds']}")

# Verificar suporte
if ScrapingManager.is_world_supported("taleon", "san"):
    result = await ScrapingManager.scrape_character("taleon", "san", "Gates")
```

### Context Manager

```python
from app.services.scraping.taleon import TaleonCharacterScraper

async with TaleonCharacterScraper() as scraper:
    result = await scraper.scrape_character("san", "Gates")
```

## 📊 Formato de Dados

Todos os scrapers retornam dados no formato padronizado:

```python
{
    'name': 'Gates',
    'level': 542,
    'vocation': 'Elite Knight',
    'residence': 'San',
    'house': None,
    'guild': 'Example Guild',
    'guild_rank': 'Member',
    'experience': 1234567890,
    'deaths': 15,
    'charm_points': 1250,
    'bosstiary_points': 850,
    'achievement_points': 320,
    'is_online': False,
    'last_login': datetime(2025, 6, 27, 19, 33),
    'profile_url': 'https://san.taleon.online/characterprofile.php?name=Gates',
    'outfit_image_url': 'https://outfits.taleon.online/outfit.php?...'
}
```

## ➕ Adicionando Novo Servidor

### 1. Criar Scraper

```python
# Exemplo: Backend/app/services/scraping/rubini.py

from .base import BaseCharacterScraper

class RubiniCharacterScraper(BaseCharacterScraper):
    def _get_server_name(self) -> str:
        return "rubini"
    
    def _get_supported_worlds(self) -> List[str]:
        return ["world1", "world2"]
    
    def _build_character_url(self, world: str, character_name: str) -> str:
        return f"https://{world}.rubini.com/character/{character_name}"
    
    async def _extract_character_data(self, html: str, url: str) -> Dict[str, Any]:
        # Implementar parsing específico do servidor
        soup = BeautifulSoup(html, 'lxml')
        # ... lógica de extração ...
        return data
```

### 2. Registrar no Sistema

```python
# No arquivo __init__.py
from .rubini import RubiniCharacterScraper

SCRAPERS = {
    "taleon": TaleonCharacterScraper,
    "rubini": RubiniCharacterScraper,  # ← Adicionar aqui
}
```

### 3. Usar Template

Use o arquivo `rubini_template.py` como base. Ele contém:
- ✅ Estrutura completa
- ✅ Comentários explicativos
- ✅ TODOs para implementação
- ✅ Exemplos de código

## 🔧 Métodos da Classe Base

### Métodos Abstratos (devem ser implementados)

- `_get_server_name()`: Nome do servidor
- `_get_supported_worlds()`: Lista de mundos
- `_build_character_url()`: Construir URL do personagem
- `_extract_character_data()`: Extrair dados do HTML

### Métodos Opcionais (podem ser sobrescritos)

- `_get_request_delay()`: Delay entre requests (padrão: 2.0s)
- `_get_default_headers()`: Headers HTTP padrão
- `_parse_date()`: Parser de datas personalizado
- `_is_character_not_found()`: Detectar personagem não encontrado

### Métodos Utilitários (prontos para uso)

- `_extract_number()`: Extrair números de strings
- `_validate_world()`: Validar se mundo é suportado
- `_standardize_character_data()`: Padronizar formato dos dados

## 🛡️ Tratamento de Erros

O sistema possui tratamento robusto de erros:

```python
result = await scrape_character_data("taleon", "san", "Gates")

if not result.success:
    print(f"Erro: {result.error_message}")
    if result.retry_after:
        print(f"Tentar novamente após: {result.retry_after}")
```

**Tipos de Erro:**
- ❌ **Servidor não suportado**: Lista servidores disponíveis
- ❌ **Mundo não suportado**: Lista mundos do servidor
- ❌ **Personagem não encontrado**: Retry em 1 hora
- ❌ **Erro de rede**: Retry em 5 minutos
- ❌ **Timeout**: Retry em 5 minutos
- ❌ **Dados insuficientes**: Retry em 15 minutos

## 📈 Benefícios da Arquitetura

### ✅ Para Desenvolvedores
- **Isolamento**: Mudanças em um servidor não afetam outros
- **Template**: Base clara para implementar novos scrapers
- **Testes**: Cada scraper pode ser testado independentemente
- **Especialização**: Otimizações específicas por servidor

### ✅ Para Manutenção
- **Modularidade**: Cada arquivo tem responsabilidade específica
- **Debugging**: Logs identificam servidor específico
- **Evolução**: Adicionar funcionalidades sem quebrar existentes
- **Performance**: Configurações otimizadas por servidor

### ✅ Para Usuários
- **Confiabilidade**: Sistema robusto com retry automático
- **Transparência**: Interface unificada independente do servidor
- **Escalabilidade**: Suporte fácil para novos servidores
- **Performance**: Delays otimizados por servidor

## 🔍 APIs dos Endpoints

### Informações do Sistema
- `GET /api/v1/characters/supported-servers`: Lista todos servidores
- `GET /api/v1/characters/server-info/{server}`: Detalhes básicos de um servidor
- `GET /api/v1/characters/server-worlds/{server}`: **NOVO** - Configurações detalhadas de todos os mundos
- `GET /api/v1/characters/server-worlds/{server}/{world}`: **NOVO** - Configuração específica de um mundo

### Scraping
- `GET /api/v1/characters/test-scraping/{server}/{world}/{name}`: Teste sem salvar
- `POST /api/v1/characters/scrape-and-create`: Scraping + salvar no banco

## 🧪 Testando

```bash
# Testar scraper específico
curl "http://localhost:8000/api/v1/characters/test-scraping/taleon/san/Gates"

# Verificar servidores suportados
curl "http://localhost:8000/api/v1/characters/supported-servers"

# Informações básicas do Taleon
curl "http://localhost:8000/api/v1/characters/server-info/taleon"

# 🆕 Configurações detalhadas de todos os mundos do Taleon
curl "http://localhost:8000/api/v1/characters/server-worlds/taleon"

# 🆕 Configuração específica do mundo San
curl "http://localhost:8000/api/v1/characters/server-worlds/taleon/san"
```

### Exemplo de Response - Configurações por Mundo

```json
{
  "server": "taleon",
  "worlds_count": 3,
  "worlds": {
    "san": {
      "name": "San",
      "subdomain": "san", 
      "base_url": "https://san.taleon.online",
      "request_delay": 2.5,
      "timeout_seconds": 30,
      "max_retries": 3,
      "example_url": "https://san.taleon.online/characterprofile.php?name=ExampleCharacter"
    },
    "aura": {
      "name": "Aura",
      "subdomain": "aura",
      "base_url": "https://aura.taleon.online", 
      "request_delay": 2.5,
      "timeout_seconds": 30,
      "max_retries": 3,
      "example_url": "https://aura.taleon.online/characterprofile.php?name=ExampleCharacter"
    },
    "gaia": {
      "name": "Gaia",
      "subdomain": "gaia",
      "base_url": "https://gaia.taleon.online",
      "request_delay": 2.5, 
      "timeout_seconds": 30,
      "max_retries": 3,
      "example_url": "https://gaia.taleon.online/characterprofile.php?name=ExampleCharacter"
    }
  }
}
```

---

📝 **Nota**: Esta arquitetura é facilmente extensível. Para adicionar suporte a novos servidores de Tibia, basta seguir o template e implementar os métodos específicos do servidor! 