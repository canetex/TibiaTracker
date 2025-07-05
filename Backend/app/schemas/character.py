"""
Schemas Pydantic para validação de dados de personagens
======================================================

Define a estrutura de dados para requests/responses da API.
"""

from pydantic import BaseModel, Field, validator
from typing import Optional, List
from datetime import datetime
from enum import Enum


class ServerType(str, Enum):
    """Tipos de servidores suportados"""
    TALEON = "taleon"
    RUBINI = "rubini"
    DEUS_OT = "deus_ot"
    TIBIA = "tibia"
    PEGASUS_OT = "pegasus_ot"


class WorldType(str, Enum):
    """Mundos suportados por servidor"""
    # Taleon
    SAN = "san"
    AURA = "aura"
    GAIA = "gaia"


class VocationType(str, Enum):
    """Vocações do Tibia"""
    NONE = "None"
    SORCERER = "Sorcerer"
    DRUID = "Druid"
    PALADIN = "Paladin"
    KNIGHT = "Knight"
    MASTER_SORCERER = "Master Sorcerer"
    ELDER_DRUID = "Elder Druid"
    ROYAL_PALADIN = "Royal Paladin"
    ELITE_KNIGHT = "Elite Knight"


class CharacterBase(BaseModel):
    """Schema base para personagens"""
    name: str = Field(..., min_length=2, max_length=255, description="Nome do personagem")
    server: ServerType = Field(..., description="Servidor onde o personagem está")
    world: WorldType = Field(..., description="World atual do personagem")
    level: Optional[int] = Field(0, ge=0, le=1000, description="Level atual do personagem")
    vocation: Optional[str] = Field("None", max_length=50, description="Vocação do personagem")
    residence: Optional[str] = Field(None, max_length=255, description="Residência do personagem")
    guild: Optional[str] = None

    @validator('name')
    def validate_name(cls, v):
        if not v or not v.strip():
            raise ValueError('Nome não pode ser vazio')
        return v.strip()


class CharacterCreate(CharacterBase):
    """Schema para criação de personagens"""
    is_active: bool = Field(True, description="Se o personagem está ativo para scraping")
    is_public: bool = Field(True, description="Se o personagem é público")
    is_favorited: bool = Field(False, description="Se o personagem é favorito")
    
    # URLs opcionais
    profile_url: Optional[str] = Field(None, max_length=500, description="URL do perfil do personagem")
    character_url: Optional[str] = Field(None, max_length=500, description="URL da página do personagem")
    outfit_image_url: Optional[str] = Field(None, max_length=500, description="URL da imagem do outfit")


class CharacterUpdate(BaseModel):
    """Schema para atualização de personagens"""
    name: Optional[str] = Field(None, min_length=2, max_length=255)
    server: Optional[ServerType] = None
    world: Optional[WorldType] = None
    level: Optional[int] = Field(None, ge=0, le=1000)
    vocation: Optional[str] = Field(None, max_length=50)
    residence: Optional[str] = Field(None, max_length=255)
    is_active: Optional[bool] = None
    is_public: Optional[bool] = None
    is_favorited: Optional[bool] = None
    profile_url: Optional[str] = Field(None, max_length=500)
    character_url: Optional[str] = Field(None, max_length=500)
    outfit_image_url: Optional[str] = Field(None, max_length=500)


class CharacterSnapshotBase(BaseModel):
    """Schema base para snapshots de personagens"""
    # Dados básicos obrigatórios
    level: int = Field(..., ge=0, le=1000, description="Level do personagem")
    experience: int = Field(..., ge=0, description="Experiência total do personagem")
    deaths: int = Field(0, ge=0, description="Número de mortes do personagem")
    
    # Pontos especiais (opcionais)
    charm_points: Optional[int] = Field(None, ge=0, description="Pontos de Charm")
    bosstiary_points: Optional[int] = Field(None, ge=0, description="Pontos de Bosstiary")
    achievement_points: Optional[int] = Field(None, ge=0, description="Pontos de Achievement")
    
    # Informações do personagem
    vocation: str = Field(..., max_length=50, description="Vocação do personagem")
    world: WorldType = Field(..., description="World do personagem neste snapshot")
    residence: Optional[str] = Field(None, max_length=255, description="Residência")
    house: Optional[str] = Field(None, max_length=255, description="Casa do personagem")
    guild: Optional[str] = Field(None, max_length=255, description="Guild do personagem")
    guild_rank: Optional[str] = Field(None, max_length=100, description="Rank na guild")
    
    # Status
    is_online: bool = Field(False, description="Se o personagem está online")
    last_login: Optional[datetime] = Field(None, description="Último login do personagem")
    
    # Outfit
    outfit_image_url: Optional[str] = Field(None, max_length=500, description="URL da imagem do outfit")
    outfit_data: Optional[str] = Field(None, description="Dados do outfit em JSON")
    profile_url: Optional[str] = Field(None, max_length=500, description="URL do perfil original")

    @validator('experience')
    def validate_experience(cls, v):
        if v < 0:
            raise ValueError('Experiência não pode ser negativa')
        return v

    @validator('outfit_data')
    def validate_outfit_data(cls, v):
        if v is not None and len(v) > 10000:  # Limite razoável para JSON
            raise ValueError('Dados do outfit muito grandes')
        return v


class CharacterSnapshotCreate(CharacterSnapshotBase):
    """Schema para criação de snapshots"""
    character_id: int = Field(..., description="ID do personagem")
    scrape_source: str = Field("manual", max_length=100, description="Fonte do scraping")
    scrape_duration: Optional[int] = Field(None, ge=0, description="Duração do scraping em ms")


class CharacterSnapshot(CharacterSnapshotBase):
    """Schema completo para snapshots (response)"""
    id: int
    character_id: int
    scraped_at: datetime
    scrape_source: str
    scrape_duration: Optional[int]

    class Config:
        from_attributes = True


class Character(CharacterBase):
    """Schema completo para personagens (response)"""
    id: int
    is_active: bool
    is_public: bool
    is_favorited: bool
    profile_url: Optional[str]
    character_url: Optional[str]
    outfit_image_url: Optional[str]
    last_scraped_at: Optional[datetime]
    scrape_error_count: int
    last_scrape_error: Optional[str]
    next_scrape_at: Optional[datetime]
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class CharacterWithSnapshots(Character):
    """Schema para personagem com seus snapshots"""
    snapshots: List[CharacterSnapshot] = []

    class Config:
        from_attributes = True


class CharacterSummary(BaseModel):
    """Schema resumido para listagens"""
    id: int
    name: str
    server: str
    world: str
    level: int
    vocation: str
    is_active: bool
    is_favorited: bool
    last_scraped_at: Optional[datetime]
    snapshots_count: Optional[int] = 0
    outfit_image_url: Optional[str] = None
    guild: Optional[str] = None

    class Config:
        from_attributes = True


class CharacterEvolution(BaseModel):
    """Schema para dados de evolução temporal"""
    character_id: int
    character_name: str
    period_start: datetime
    period_end: datetime
    
    # Evolução dos dados
    level_start: int
    level_end: int
    level_gained: int
    
    experience_start: int
    experience_end: int
    experience_gained: int
    
    deaths_start: int
    deaths_end: int
    deaths_total: int
    
    # Pontos especiais (se disponíveis)
    charm_points_start: Optional[int]
    charm_points_end: Optional[int]
    charm_points_gained: Optional[int]
    
    bosstiary_points_start: Optional[int]
    bosstiary_points_end: Optional[int]
    bosstiary_points_gained: Optional[int]
    
    achievement_points_start: Optional[int]
    achievement_points_end: Optional[int]
    achievement_points_gained: Optional[int]
    
    # Mudanças de world (se houver)
    world_changes: List[str] = []

    class Config:
        from_attributes = True


class CharacterStats(BaseModel):
    """Schema para estatísticas de personagem"""
    character_id: int
    character_name: str
    
    # Estatísticas gerais
    total_snapshots: int
    first_snapshot: Optional[datetime]
    last_snapshot: Optional[datetime]
    
    # Picos e records
    highest_level: int
    highest_level_date: Optional[datetime]
    highest_experience: int
    highest_experience_date: Optional[datetime]
    
    # Médias
    average_daily_exp_gain: Optional[float]
    average_level_per_month: Optional[float]
    
    # Worlds visitados
    worlds_visited: List[str] = []
    
    class Config:
        from_attributes = True


# Schemas para responses de API
class CharacterListResponse(BaseModel):
    """Response para listagem de personagens"""
    characters: List[CharacterSummary]
    total: int
    page: int
    per_page: int


class CharacterEvolutionResponse(BaseModel):
    """Response para dados de evolução"""
    character: CharacterSummary
    evolution: CharacterEvolution
    snapshots: List[CharacterSnapshot]


class SnapshotListResponse(BaseModel):
    """Response para listagem de snapshots"""
    snapshots: List[CharacterSnapshot]
    total: int
    page: int
    per_page: int


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