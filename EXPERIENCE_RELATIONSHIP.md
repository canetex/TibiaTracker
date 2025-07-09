# Relação Char + DIA + EXPERIÊNCIA - Como Funciona

## 📊 Diagrama da Relação

```
┌─────────────────────────────────────────────────────────────────┐
│                    SITE TALEON                                  │
├─────────────────────────────────────────────────────────────────┤
│                    EXPERIENCE HISTORY TABLE                     │
├─────────────────────────────────────────────────────────────────┤
│ Data        │ Experience Gained                                 │
├─────────────┼───────────────────────────────────────────────────┤
│ Today       │ 1,500,000                                         │
│ Yesterday   │ 800,000                                           │
│ 08/01/2025  │ 1,200,000                                         │
│ 07/01/2025  │ 0 (no exp gained)                                 │
│ 06/01/2025  │ 2,100,000                                         │
└─────────────────────────────────────────────────────────────────┘
                                │
                                │ SCRAPING
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                    BACKEND PROCESSING                           │
├─────────────────────────────────────────────────────────────────┤
│ 1. Extrair tabela "Experience History" do site                  │
│ 2. Parsear cada linha: Data + Experiência Ganha                │
│ 3. Converter datas: "Today" → 2025-01-09                       │
│ 4. Criar lista: experience_history = [                         │
│    {date: 2025-01-09, experience_gained: 1500000},             │
│    {date: 2025-01-08, experience_gained: 800000},              │
│    {date: 2025-01-08, experience_gained: 1200000},             │
│    {date: 2025-01-07, experience_gained: 0},                   │
│    {date: 2025-01-06, experience_gained: 2100000}              │
│ ]                                                              │
└─────────────────────────────────────────────────────────────────┘
                                │
                                │ SAVE TO DATABASE
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                    CHARACTER_SNAPSHOTS                          │
├─────────────────────────────────────────────────────────────────┤
│ id │ character_id │ experience │ scraped_at    │ scrape_source  │
├────┼──────────────┼────────────┼───────────────┼────────────────┤
│ 1  │ 1            │ 1,500,000  │ 2025-01-09    │ history        │
│ 2  │ 1            │ 800,000    │ 2025-01-08    │ history        │
│ 3  │ 1            │ 1,200,000  │ 2025-01-08    │ history        │
│ 4  │ 1            │ 0          │ 2025-01-07    │ history        │
│ 5  │ 1            │ 2,100,000  │ 2025-01-06    │ history        │
└─────────────────────────────────────────────────────────────────┘
```

## 🔍 Como os Dados são Extraídos

### **1. Scraping da Tabela de Experiência**
```python
def _extract_experience_history_data(self, soup: BeautifulSoup) -> List[Dict[str, Any]]:
    """Extrair dados históricos de experiência de vários dias"""
    
    # 1. Buscar seção "Experience History" na página
    exp_section = soup.find(text=re.compile(r'experience history', re.IGNORECASE))
    
    # 2. Encontrar a tabela de experiência
    exp_table = exp_section.find_next('table')
    
    # 3. Processar cada linha da tabela
    for row in exp_table.find_all('tr')[1:]:  # Pular header
        cells = row.find_all(['td', 'th'])
        date_text = cells[0].get_text().strip()    # "Today", "Yesterday", "08/01/2025"
        exp_text = cells[1].get_text().strip()     # "1,500,000", "800,000"
        
        # 4. Converter data
        if date_text.lower() == 'today':
            snapshot_date = datetime.now().date()
        elif date_text.lower() == 'yesterday':
            snapshot_date = (datetime.now() - timedelta(days=1)).date()
        else:
            snapshot_date = datetime.strptime(date_text, '%d/%m/%Y').date()
        
        # 5. Extrair experiência
        experience_gained = self._extract_number(exp_text)
        
        # 6. Adicionar ao histórico
        history_data.append({
            'date': snapshot_date,
            'experience_gained': experience_gained,
            'date_text': date_text
        })
```

### **2. Salvamento no Banco**
```python
# Para cada entrada do histórico
for entry in history_data:
    snapshot = CharacterSnapshotModel(
        character_id=character.id,
        experience=entry['experience_gained'],  # Experiência GANHA naquele dia
        scraped_at=datetime.combine(entry['date'], datetime.min.time()),
        scrape_source="history"
    )
    db.add(snapshot)
```

## 📅 Exemplo Real de Dados

### **Site Taleon - Personagem "Gates"**
```
┌─────────────────────────────────────────────────────────────────┐
│                    EXPERIENCE HISTORY                           │
├─────────────────────────────────────────────────────────────────┤
│ Today       │ 1,500,000                                         │
│ Yesterday   │ 800,000                                           │
│ 08/01/2025  │ 1,200,000                                         │
│ 07/01/2025  │ 0                                                 │
│ 06/01/2025  │ 2,100,000                                         │
└─────────────────────────────────────────────────────────────────┘
```

### **Banco de Dados - CHARACTER_SNAPSHOTS**
```sql
SELECT character_id, experience, scraped_at, scrape_source 
FROM character_snapshots 
WHERE character_id = 1 
ORDER BY scraped_at DESC;

-- Resultado:
-- character_id │ experience │ scraped_at    │ scrape_source
-- 1            │ 1,500,000  │ 2025-01-09    │ history
-- 1            │ 800,000    │ 2025-01-08    │ history  
-- 1            │ 1,200,000  │ 2025-01-08    │ history
-- 1            │ 0          │ 2025-01-07    │ history
-- 1            │ 2,100,000  │ 2025-01-06    │ history
```

## ⚠️ Pontos Importantes

### **1. Campo `experience` nos Snapshots**
- **NÃO é experiência total acumulada**
- **É experiência GANHA naquele dia específico**
- **Vem diretamente da tabela "Experience History" do site**

### **2. Campo `scraped_at`**
- **NÃO é a data/hora do scraping**
- **É a data específica do dia da experiência**
- **Exemplo**: Se hoje é 09/01/2025 e o site mostra "Yesterday: 800,000", então:
  - `experience = 800000`
  - `scraped_at = 2025-01-08 00:00:00`

### **3. Campo `scrape_source`**
- **`"history"`**: Dados extraídos da tabela de histórico
- **`"manual"`**: Dados extraídos de scraping manual
- **`"scheduled"`**: Dados de scraping automático
- **`"refresh"`**: Dados de atualização

## 🔄 Fluxo Completo

### **1. Scraping Diário**
```
1. Sistema acessa perfil do personagem no Taleon
2. Encontra seção "Experience History"
3. Extrai tabela com datas e experiências ganhas
4. Para cada linha:
   - Converte data ("Today" → 2025-01-09)
   - Extrai experiência ganha (1,500,000)
   - Cria snapshot com:
     * experience = 1500000
     * scraped_at = 2025-01-09 00:00:00
     * scrape_source = "history"
5. Salva no banco CHARACTER_SNAPSHOTS
```

### **2. Consulta para "Experiência do Dia Anterior"**
```python
# Buscar snapshot do dia anterior
yesterday = datetime.utcnow().date() - timedelta(days=1)

# Procurar snapshot com scraped_at = yesterday
yesterday_snapshot = await db.execute(
    select(CharacterSnapshotModel)
    .where(
        and_(
            CharacterSnapshotModel.character_id == character_id,
            func.date(CharacterSnapshotModel.scraped_at) == yesterday
        )
    )
)

# Retornar experience do snapshot (já é a experiência ganha naquele dia)
return yesterday_snapshot.experience  # Ex: 800,000
```

## 🎯 Resumo

- **Fonte**: Tabela "Experience History" do site Taleon
- **Processo**: Scraping → Parse → Conversão de datas → Salvamento
- **Armazenamento**: Cada linha da tabela vira um registro em CHARACTER_SNAPSHOTS
- **Campo `experience`**: Experiência ganha naquele dia específico
- **Campo `scraped_at`**: Data do dia da experiência (não do scraping)
- **Resultado**: Histórico completo dia-a-dia de experiência ganha por personagem 