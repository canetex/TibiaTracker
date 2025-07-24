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
    
    @classmethod
    def _missing_(cls, value):
        """Permitir valores com primeira letra maiúscula"""
        if isinstance(value, str):
            lower_value = value.lower()
            for member in cls:
                if member.value == lower_value:
                    return member
        return None


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
    name: str = Field(..., max_length=255, description="Nome do personagem")
    server: ServerType = Field(..., description="Servidor do personagem")
    world: WorldType = Field(..., description="World do personagem")
    level: int = Field(0, ge=0, le=9999, description="Level do personagem")
    vocation: VocationType = Field(VocationType.NONE, description="Vocação do personagem")
    residence: Optional[str] = Field(None, max_length=255, description="Residência do personagem")
    guild: Optional[str] = Field(None, max_length=255, description="Guild do personagem")
    is_active: bool = Field(True, description="Se o personagem está ativo")
    is_public: bool = Field(True, description="Se o personagem é público")
    recovery_active: bool = Field(True, description="Se o personagem deve receber scraping automático")
    profile_url: Optional[str] = Field(None, max_length=500, description="URL do perfil")
    character_url: Optional[str] = Field(None, max_length=500, description="URL do personagem")
    outfit_image_url: Optional[str] = Field(None, max_length=500, description="URL da imagem do outfit")
    outfit_image_path: Optional[str] = Field(None, max_length=500, description="Caminho local da imagem do outfit")

    @validator('name')
    def validate_name(cls, v):
        if not v.strip():
            raise ValueError('Nome não pode estar vazio')
        return v.strip()

    @validator('level')
    def validate_level(cls, v):
        if v < 0 or v > 9999:
            raise ValueError('Level deve estar entre 0 e 9999')
        return v


class CharacterCreate(CharacterBase):
    """Schema para criação de personagem"""
    pass


class CharacterUpdate(BaseModel):
    """Schema para atualização de personagem"""
    name: Optional[str] = Field(None, max_length=255)
    server: Optional[ServerType] = None
    world: Optional[WorldType] = None
    level: Optional[int] = Field(None, ge=0, le=9999)
    vocation: Optional[VocationType] = None
    residence: Optional[str] = Field(None, max_length=255)
    guild: Optional[str] = Field(None, max_length=255)
    is_active: Optional[bool] = None
    is_public: Optional[bool] = None
    recovery_active: Optional[bool] = None
    profile_url: Optional[str] = Field(None, max_length=500)
    character_url: Optional[str] = Field(None, max_length=500)
    outfit_image_url: Optional[str] = Field(None, max_length=500)
    outfit_image_path: Optional[str] = Field(None, max_length=500)


class CharacterSnapshotBase(BaseModel):
    """Schema base para snapshots de personagens"""
    # Dados básicos obrigatórios
    level: int = Field(..., ge=0, le=9999, description="Level do personagem")
    experience: int = Field(..., ge=0, description="Experiência ganha naquele dia específico")
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

    @validator('level')
    def validate_level(cls, v):
        if v < 0 or v > 9999:
            raise ValueError('Level deve estar entre 0 e 9999')
        return v


class CharacterSnapshotCreate(CharacterSnapshotBase):
    """Schema para criação de snapshot"""
    character_id: int = Field(..., description="ID do personagem")
    exp_date: datetime = Field(..., description="Data da experiência")


class CharacterSnapshot(CharacterSnapshotBase):
    """Schema para resposta de snapshot"""
    id: int
    character_id: int
    exp_date: datetime
    scraped_at: datetime
    scrape_source: Optional[str] = None
    scrape_duration: Optional[int] = None

    class Config:
        from_attributes = True


class Character(CharacterBase):
    """Schema para resposta de personagem"""
    id: int
    last_scraped_at: Optional[datetime] = None
    scrape_error_count: int = 0
    last_scrape_error: Optional[str] = None
    next_scrape_at: Optional[datetime] = None
    recovery_active: bool = True
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class CharacterWithSnapshots(Character):
    """Schema para personagem com snapshots"""
    snapshots: List[CharacterSnapshot] = []
    previous_experience: Optional[int] = Field(None, description="Experiência do dia anterior")

    class Config:
        from_attributes = True


class CharacterList(BaseModel):
    """Schema para lista de personagens"""
    characters: List[Character]
    total: int
    skip: int
    limit: int


class CharacterIDsRequest(BaseModel):
    """Schema para requisição de IDs de personagens"""
    ids: List[int] = Field(..., description="Lista de IDs de personagens")


class CharacterIDsResponse(BaseModel):
    """Schema para resposta de IDs de personagens"""
    ids: List[int] = Field(..., description="Lista de IDs de personagens")


class CharacterStats(BaseModel):
    """Schema para estatísticas de personagens"""
    total_characters: int
    active_characters: int
    total_snapshots: int
    characters_by_server: dict
    characters_by_world: dict
    characters_by_vocation: dict
    average_level: float
    max_level: int
    min_level: int


class GlobalStats(BaseModel):
    """Schema para estatísticas globais"""
    total_characters: int
    active_characters: int
    total_snapshots: int
    characters_by_server: dict
    characters_by_world: dict
    characters_by_vocation: dict
    average_level: float
    max_level: int
    min_level: int
    total_experience_gained: int
    total_deaths: int 