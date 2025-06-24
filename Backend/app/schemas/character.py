"""
Schemas Pydantic para validação e serialização
==============================================

Schemas para request/response da API de personagens.
"""

from pydantic import BaseModel, Field, validator
from typing import Optional, List
from datetime import datetime
from enum import Enum


class ServerType(str, Enum):
    """Servidores suportados"""
    TALEON = "taleon"
    RUBINI = "rubini"
    DEUS_OT = "deus_ot"
    TIBIA = "tibia"
    PEGASUS_OT = "pegasus_ot"


class WorldType(str, Enum):
    """Mundos suportados"""
    SAN = "san"
    AURA = "aura"
    GAIA = "gaia"


# === SCHEMAS BASE ===

class CharacterBase(BaseModel):
    """Schema base para personagem"""
    name: str = Field(..., min_length=1, max_length=255, description="Nome do personagem")
    server: ServerType = Field(..., description="Servidor do personagem")
    world: WorldType = Field(..., description="Mundo do personagem")


class CharacterCreate(CharacterBase):
    """Schema para criação de personagem"""
    pass


class CharacterUpdate(BaseModel):
    """Schema para atualização de personagem"""
    is_favorited: Optional[bool] = None
    is_public: Optional[bool] = None


# === SCHEMAS DE RESPONSE ===

class CharacterSnapshotResponse(BaseModel):
    """Schema de resposta para snapshot de personagem"""
    id: int
    level: int
    experience: int
    deaths: int
    charm_points: Optional[int]
    bosstiary_points: Optional[int]
    achievement_points: Optional[int]
    vocation: Optional[str]
    residence: Optional[str]
    house: Optional[str]
    guild: Optional[str]
    guild_rank: Optional[str]
    is_online: bool
    last_login: Optional[datetime]
    scraped_at: datetime
    scrape_source: str

    class Config:
        from_attributes = True


class CharacterResponse(BaseModel):
    """Schema de resposta completa para personagem"""
    id: int
    name: str
    server: str
    world: str
    level: int
    vocation: Optional[str]
    residence: Optional[str]
    is_active: bool
    is_public: bool
    is_favorited: bool
    profile_url: Optional[str]
    last_scraped_at: Optional[datetime]
    scrape_error_count: int
    last_scrape_error: Optional[str]
    next_scrape_at: Optional[datetime]
    created_at: datetime
    updated_at: datetime
    
    # Último snapshot (dados mais recentes)
    latest_snapshot: Optional[CharacterSnapshotResponse] = None
    
    # Estatísticas resumidas
    total_snapshots: int = 0

    class Config:
        from_attributes = True


class CharacterListResponse(BaseModel):
    """Schema para lista de personagens"""
    characters: List[CharacterResponse]
    total: int
    page: int
    size: int
    has_next: bool


class CharacterStatsResponse(BaseModel):
    """Schema para estatísticas de personagem"""
    character_id: int
    total_snapshots: int
    level_progression: List[dict]  # [{date, level}, ...]
    experience_progression: List[dict]  # [{date, experience}, ...]
    deaths_progression: List[dict]  # [{date, deaths}, ...]
    charm_points_progression: List[dict]  # [{date, charm_points}, ...]
    bosstiary_points_progression: List[dict]  # [{date, bosstiary_points}, ...]
    achievement_points_progression: List[dict]  # [{date, achievement_points}, ...]
    first_seen: Optional[datetime]
    last_updated: Optional[datetime]


# === SCHEMAS DE REQUEST ===

class CharacterSearchRequest(BaseModel):
    """Schema para busca de personagem"""
    name: str = Field(..., min_length=1, max_length=255)
    server: ServerType
    world: WorldType

    @validator('name')
    def validate_name(cls, v):
        """Validar nome do personagem"""
        if not v or not v.strip():
            raise ValueError('Nome do personagem não pode estar vazio')
        return v.strip()


class CharacterFavoriteRequest(BaseModel):
    """Schema para favoritar/desfavoritar personagem"""
    is_favorited: bool


# === SCHEMAS DE ERRO ===

class ErrorResponse(BaseModel):
    """Schema para respostas de erro"""
    error: bool = True
    message: str
    details: Optional[dict] = None
    timestamp: datetime = Field(default_factory=datetime.now)


class ScrapeErrorResponse(BaseModel):
    """Schema para erros de scraping"""
    character_id: int
    character_name: str
    error_message: str
    retry_count: int
    next_retry_at: Optional[datetime]
    timestamp: datetime


# === SCHEMAS DE SUCESSO ===

class SuccessResponse(BaseModel):
    """Schema para respostas de sucesso"""
    success: bool = True
    message: str
    data: Optional[dict] = None
    timestamp: datetime = Field(default_factory=datetime.now)


# === VALIDADORES ===

def validate_character_name(name: str) -> str:
    """Validar e limpar nome de personagem"""
    if not name or not name.strip():
        raise ValueError("Nome do personagem é obrigatório")
    
    cleaned_name = name.strip()
    
    # Verificar caracteres permitidos (letras, números, espaços, alguns símbolos)
    allowed_chars = set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 '-")
    if not all(c in allowed_chars for c in cleaned_name):
        raise ValueError("Nome contém caracteres inválidos")
    
    if len(cleaned_name) > 255:
        raise ValueError("Nome muito longo (máximo 255 caracteres)")
    
    return cleaned_name


def validate_server_world_combination(server: str, world: str) -> bool:
    """Validar combinação de servidor e mundo"""
    valid_combinations = {
        "taleon": ["san", "aura", "gaia"],
        # Adicionar outros servidores conforme implementados
    }
    
    if server not in valid_combinations:
        raise ValueError(f"Servidor '{server}' não é suportado")
    
    if world not in valid_combinations[server]:
        raise ValueError(f"Mundo '{world}' não é válido para o servidor '{server}'")
    
    return True 