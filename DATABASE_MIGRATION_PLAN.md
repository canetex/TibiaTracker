# Plano de Migração do Banco de Dados - Tibia Tracker

## 🎯 Mudanças Estruturais Necessárias

### **1. Tabela CHARACTERS - Remover is_favorited**
```sql
-- Remover campo is_favorited (será movido para tabela de usuários)
ALTER TABLE characters DROP COLUMN IF EXISTS is_favorited;
```

### **2. Tabela CHARACTER_SNAPSHOTS - Reestruturação**
```sql
-- Adicionar campo exp_date (data da experiência)
ALTER TABLE character_snapshots ADD COLUMN IF NOT EXISTS exp_date DATE;

-- Renomear scraped_at para scraped_at (já existe, mas vamos garantir)
-- scraped_at = data/hora do scraping
-- exp_date = data a qual se refere a experiência

-- Criar índice único para (character_id, exp_date)
CREATE UNIQUE INDEX IF NOT EXISTS idx_snapshot_character_exp_date 
ON character_snapshots(character_id, exp_date);

-- Remover índice antigo se existir
DROP INDEX IF EXISTS idx_snapshot_character_scraped;
```

## 📊 Nova Estrutura das Tabelas

### **CHARACTERS (Simplificada)**
```sql
CREATE TABLE characters (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    server VARCHAR(50) NOT NULL,
    world VARCHAR(50) NOT NULL,
    level INTEGER DEFAULT 0,
    vocation VARCHAR(50) DEFAULT 'None',
    residence VARCHAR(255),
    guild VARCHAR(255),
    is_active BOOLEAN DEFAULT TRUE,
    is_public BOOLEAN DEFAULT TRUE,
    profile_url VARCHAR(500),
    character_url VARCHAR(500),
    outfit_image_url VARCHAR(500),
    outfit_image_path VARCHAR(500),
    last_scraped_at TIMESTAMP WITH TIME ZONE,
    scrape_error_count INTEGER DEFAULT 0,
    last_scrape_error TEXT,
    next_scrape_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
```

### **CHARACTER_SNAPSHOTS (Reestruturada)**
```sql
CREATE TABLE character_snapshots (
    id SERIAL PRIMARY KEY,
    character_id INTEGER REFERENCES characters(id) ON DELETE CASCADE,
    
    -- ===== DADOS BÁSICOS DO PERSONAGEM =====
    level INTEGER NOT NULL DEFAULT 0,
    experience BIGINT NOT NULL DEFAULT 0,  -- Experiência ganha naquele dia
    deaths INTEGER NOT NULL DEFAULT 0,
    
    -- ===== PONTOS ESPECIAIS =====
    charm_points INTEGER,
    bosstiary_points INTEGER,
    achievement_points INTEGER,
    
    -- ===== INFORMAÇÕES ADICIONAIS =====
    vocation VARCHAR(50) NOT NULL,
    world VARCHAR(50) NOT NULL,
    residence VARCHAR(255),
    house VARCHAR(255),
    guild VARCHAR(255),
    guild_rank VARCHAR(100),
    
    -- ===== STATUS DO PERSONAGEM =====
    is_online BOOLEAN DEFAULT FALSE,
    last_login TIMESTAMP WITH TIME ZONE,
    
    -- ===== OUTFIT INFORMATION =====
    outfit_image_url VARCHAR(500),
    outfit_image_path VARCHAR(500),
    outfit_data TEXT,
    profile_url VARCHAR(500),
    
    -- ===== DATAS IMPORTANTES =====
    exp_date DATE NOT NULL,                    -- Data da experiência (chave)
    scraped_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,  -- Data do scraping
    
    -- ===== METADADOS DO SCRAPING =====
    scrape_source VARCHAR(100) DEFAULT 'manual',
    scrape_duration INTEGER
);

-- Índice único para evitar duplicatas
CREATE UNIQUE INDEX idx_snapshot_character_exp_date 
ON character_snapshots(character_id, exp_date);

-- Índices para performance
CREATE INDEX idx_snapshot_character_scraped ON character_snapshots(character_id, scraped_at);
CREATE INDEX idx_snapshot_exp_date ON character_snapshots(exp_date);
CREATE INDEX idx_snapshot_character_world ON character_snapshots(character_id, world);
CREATE INDEX idx_snapshot_level_experience ON character_snapshots(level, experience);
```

### **CHARACTER_FAVORITES (Nova Tabela)**
```sql
CREATE TABLE character_favorites (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,  -- Referência futura para tabela de usuários
    character_id INTEGER REFERENCES characters(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(user_id, character_id)
);

CREATE INDEX idx_favorites_user ON character_favorites(user_id);
CREATE INDEX idx_favorites_character ON character_favorites(character_id);
```

## 🔄 Script de Migração

### **1. Backup e Preparação**
```sql
-- Backup das tabelas atuais
CREATE TABLE characters_backup AS SELECT * FROM characters;
CREATE TABLE character_snapshots_backup AS SELECT * FROM character_snapshots;

-- Backup dos favoritos
CREATE TABLE favorites_backup AS 
SELECT id, character_id, created_at 
FROM characters 
WHERE is_favorited = true;
```

### **2. Migração dos Dados**
```sql
-- 1. Remover is_favorited da tabela characters
ALTER TABLE characters DROP COLUMN IF EXISTS is_favorited;

-- 2. Adicionar exp_date na tabela character_snapshots
ALTER TABLE character_snapshots ADD COLUMN IF NOT EXISTS exp_date DATE;

-- 3. Migrar dados existentes: usar scraped_at como exp_date inicial
UPDATE character_snapshots 
SET exp_date = DATE(scraped_at) 
WHERE exp_date IS NULL;

-- 4. Tornar exp_date NOT NULL
ALTER TABLE character_snapshots ALTER COLUMN exp_date SET NOT NULL;

-- 5. Criar índice único
CREATE UNIQUE INDEX idx_snapshot_character_exp_date 
ON character_snapshots(character_id, exp_date);

-- 6. Criar tabela de favoritos
CREATE TABLE character_favorites (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    character_id INTEGER REFERENCES characters(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, character_id)
);

-- 7. Migrar favoritos existentes (user_id = 1 para compatibilidade)
INSERT INTO character_favorites (user_id, character_id, created_at)
SELECT 1, character_id, created_at 
FROM favorites_backup;
```

## 🛠️ Ajustes nas Lógicas de Select

### **1. Criação de um Registro**
```python
async def create_character_with_snapshot(character_data, snapshot_data):
    """Criar personagem com snapshot inicial"""
    
    # 1. Criar personagem
    character = CharacterModel(
        name=character_data['name'],
        server=character_data['server'],
        world=character_data['world'],
        level=snapshot_data['level'],
        vocation=snapshot_data['vocation'],
        # ... outros campos
    )
    db.add(character)
    await db.flush()
    
    # 2. Criar snapshot
    snapshot = CharacterSnapshotModel(
        character_id=character.id,
        level=snapshot_data['level'],
        experience=snapshot_data['experience_gained'],
        exp_date=snapshot_data['exp_date'],  # Data da experiência
        scraped_at=datetime.utcnow(),        # Data do scraping
        # ... outros campos
    )
    db.add(snapshot)
    await db.commit()
```

### **2. Atualização de um Registro**
```python
async def update_character_snapshot(character_id, exp_date, new_data):
    """Atualizar snapshot existente ou criar novo"""
    
    # Buscar snapshot existente para a data
    existing = await db.execute(
        select(CharacterSnapshotModel)
        .where(
            and_(
                CharacterSnapshotModel.character_id == character_id,
                CharacterSnapshotModel.exp_date == exp_date
            )
        )
    )
    snapshot = existing.scalar_one_or_none()
    
    if snapshot:
        # Atualizar snapshot existente
        snapshot.experience = new_data['experience_gained']
        snapshot.level = new_data['level']
        snapshot.scraped_at = datetime.utcnow()  # Atualizar data do scraping
        # ... outros campos
    else:
        # Criar novo snapshot
        snapshot = CharacterSnapshotModel(
            character_id=character_id,
            exp_date=exp_date,
            experience=new_data['experience_gained'],
            scraped_at=datetime.utcnow(),
            # ... outros campos
        )
        db.add(snapshot)
    
    await db.commit()
```

### **3. Select com Base em Filtros**
```python
async def filter_characters_with_snapshots(filters):
    """Filtrar personagens com snapshots mais recentes"""
    
    query = (
        select(CharacterModel, CharacterSnapshotModel)
        .join(
            CharacterSnapshotModel,
            and_(
                CharacterSnapshotModel.character_id == CharacterModel.id,
                CharacterSnapshotModel.exp_date == (
                    select(func.max(CharacterSnapshotModel.exp_date))
                    .where(CharacterSnapshotModel.character_id == CharacterModel.id)
                    .scalar_subquery()
                )
            )
        )
    )
    
    # Aplicar filtros
    if filters.get('min_level'):
        query = query.where(CharacterSnapshotModel.level >= filters['min_level'])
    
    if filters.get('server'):
        query = query.where(CharacterModel.server == filters['server'])
    
    # ... outros filtros
    
    return await db.execute(query)
```

### **4. Geração dos Gráficos**
```python
async def get_character_experience_chart(character_id, days=30):
    """Gerar dados para gráfico de experiência"""
    
    end_date = datetime.utcnow().date()
    start_date = end_date - timedelta(days=days)
    
    query = (
        select(CharacterSnapshotModel)
        .where(
            and_(
                CharacterSnapshotModel.character_id == character_id,
                CharacterSnapshotModel.exp_date >= start_date,
                CharacterSnapshotModel.exp_date <= end_date
            )
        )
        .order_by(CharacterSnapshotModel.exp_date)
    )
    
    result = await db.execute(query)
    snapshots = result.scalars().all()
    
    # Processar dados para gráfico
    chart_data = []
    for snapshot in snapshots:
        chart_data.append({
            'date': snapshot.exp_date.strftime('%Y-%m-%d'),
            'experience': snapshot.experience,
            'level': snapshot.level
        })
    
    return chart_data
```

### **5. Geração dos Cards**
```python
async def get_character_card_data(character_id):
    """Obter dados para exibição no card"""
    
    # Buscar personagem com snapshot mais recente
    query = (
        select(CharacterModel, CharacterSnapshotModel)
        .join(
            CharacterSnapshotModel,
            and_(
                CharacterSnapshotModel.character_id == CharacterModel.id,
                CharacterSnapshotModel.exp_date == (
                    select(func.max(CharacterSnapshotModel.exp_date))
                    .where(CharacterSnapshotModel.character_id == CharacterModel.id)
                    .scalar_subquery()
                )
            )
        )
        .where(CharacterModel.id == character_id)
    )
    
    result = await db.execute(query)
    character, latest_snapshot = result.first()
    
    # Buscar experiência do dia anterior
    yesterday = datetime.utcnow().date() - timedelta(days=1)
    yesterday_query = (
        select(CharacterSnapshotModel)
        .where(
            and_(
                CharacterSnapshotModel.character_id == character_id,
                CharacterSnapshotModel.exp_date == yesterday
            )
        )
    )
    
    yesterday_result = await db.execute(yesterday_query)
    yesterday_snapshot = yesterday_result.scalar_one_or_none()
    
    return {
        'character': character,
        'latest_snapshot': latest_snapshot,
        'yesterday_experience': yesterday_snapshot.experience if yesterday_snapshot else 0
    }
```

## 🔧 Ajustes no Backend

### **1. Modelos SQLAlchemy**
```python
class CharacterSnapshot(Base):
    __tablename__ = "character_snapshots"
    
    id = Column(Integer, primary_key=True, index=True)
    character_id = Column(Integer, ForeignKey("characters.id"), nullable=False, index=True)
    
    # ... outros campos ...
    
    exp_date = Column(Date, nullable=False, index=True)  # Data da experiência
    scraped_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)  # Data do scraping
    
    # Índice único
    __table_args__ = (
        UniqueConstraint('character_id', 'exp_date', name='uq_character_exp_date'),
        Index('idx_snapshot_character_scraped', 'character_id', 'scraped_at'),
        Index('idx_snapshot_exp_date', 'exp_date'),
    )
```

### **2. Endpoints Atualizados**
```python
@router.post("/by-ids", response_model=List[CharacterWithSnapshots])
async def get_characters_by_ids(req: CharacterIDsRequest, db: AsyncSession = Depends(get_db)):
    """Buscar personagens com dados de card"""
    
    if not req.ids:
        return []
    
    # Buscar personagens com snapshot mais recente
    query = (
        select(CharacterModel)
        .where(CharacterModel.id.in_(req.ids))
        .options(selectinload(CharacterModel.snapshots))
    )
    
    result = await db.execute(query)
    characters = result.scalars().all()
    
    # Processar cada personagem
    for character in characters:
        if character.snapshots:
            # Ordenar por exp_date (não scraped_at)
            character.snapshots.sort(key=lambda x: x.exp_date, reverse=True)
            
            # Buscar experiência do dia anterior
            yesterday = datetime.utcnow().date() - timedelta(days=1)
            yesterday_snapshot = None
            
            for snapshot in character.snapshots:
                if snapshot.exp_date == yesterday:
                    yesterday_snapshot = snapshot
                    break
            
            # Definir experiência do dia anterior
            if yesterday_snapshot:
                setattr(character, 'previous_experience', max(0, yesterday_snapshot.experience))
            else:
                setattr(character, 'previous_experience', 0)
        else:
            setattr(character, 'previous_experience', 0)
    
    return characters
```

## 📋 Checklist de Migração

### **Fase 1: Preparação**
- [ ] Backup completo do banco
- [ ] Criar scripts de migração
- [ ] Testar em ambiente de desenvolvimento

### **Fase 2: Migração**
- [ ] Executar script de migração
- [ ] Verificar integridade dos dados
- [ ] Atualizar modelos SQLAlchemy
- [ ] Atualizar endpoints da API

### **Fase 3: Testes**
- [ ] Testar criação de registros
- [ ] Testar atualização de registros
- [ ] Testar filtros
- [ ] Testar gráficos
- [ ] Testar cards

### **Fase 4: Deploy**
- [ ] Deploy em produção
- [ ] Monitorar logs
- [ ] Verificar performance

## 🎯 Benefícios da Nova Estrutura

1. **Clareza conceitual**: Separação clara entre data do scraping e data da experiência
2. **Integridade**: Índice único evita duplicatas
3. **Performance**: Índices otimizados para consultas comuns
4. **Escalabilidade**: Estrutura preparada para múltiplos usuários
5. **Manutenibilidade**: Código mais limpo e lógico 