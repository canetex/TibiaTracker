-- Etapa 3: Criar tabela character_favorites
CREATE TABLE IF NOT EXISTS character_favorites (
    id SERIAL PRIMARY KEY,
    character_id INTEGER NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
    user_id INTEGER NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(character_id, user_id)
);

-- Criar índices
CREATE INDEX IF NOT EXISTS idx_character_favorites_character_id ON character_favorites(character_id);
CREATE INDEX IF NOT EXISTS idx_character_favorites_user_id ON character_favorites(user_id);
CREATE INDEX IF NOT EXISTS idx_character_favorites_created_at ON character_favorites(created_at);

COMMIT;
