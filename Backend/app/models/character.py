"""
Modelos de banco de dados para personagens do Tibia
===================================================

Modelos SQLAlchemy para armazenar informações de personagens
e seus históricos de snapshots.
"""

from sqlalchemy import Column, Integer, String, DateTime, Boolean, Text, ForeignKey, Index
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from enum import Enum

Base = declarative_base()


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


class Character(Base):
    """
    Modelo principal para armazenar informações de personagens
    """
    __tablename__ = "characters"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), nullable=False, index=True)
    server = Column(String(50), nullable=False, index=True)  # taleon, rubini, etc
    world = Column(String(50), nullable=False, index=True)   # san, aura, gaia, etc
    
    # Informações básicas do personagem
    level = Column(Integer, default=0)
    vocation = Column(String(50), default="None")
    residence = Column(String(255))
    
    # Status e configurações
    is_active = Column(Boolean, default=True, index=True)
    is_public = Column(Boolean, default=True)
    is_favorited = Column(Boolean, default=False, index=True)
    
    # URLs e identificadores
    profile_url = Column(String(500))
    character_url = Column(String(500))
    
    # Metadados de scraping
    last_scraped_at = Column(DateTime(timezone=True), nullable=True)
    scrape_error_count = Column(Integer, default=0)
    last_scrape_error = Column(Text, nullable=True)
    next_scrape_at = Column(DateTime(timezone=True), nullable=True)
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)
    
    # Relacionamentos
    snapshots = relationship("CharacterSnapshot", back_populates="character", cascade="all, delete-orphan")
    
    # Índices compostos para performance
    __table_args__ = (
        Index('idx_character_server_world', 'server', 'world'),
        Index('idx_character_name_server_world', 'name', 'server', 'world'),
        Index('idx_character_active_favorited', 'is_active', 'is_favorited'),
        Index('idx_character_next_scrape', 'next_scrape_at', 'is_active'),
    )

    def __repr__(self):
        return f"<Character(name='{self.name}', server='{self.server}', world='{self.world}', level={self.level})>"


class CharacterSnapshot(Base):
    """
    Modelo para armazenar snapshots históricos dos personagens
    """
    __tablename__ = "character_snapshots"

    id = Column(Integer, primary_key=True, index=True)
    character_id = Column(Integer, ForeignKey("characters.id"), nullable=False, index=True)
    
    # Dados coletados no scraping
    level = Column(Integer, default=0)
    experience = Column(Integer, default=0)
    deaths = Column(Integer, default=0)
    
    # Pontos especiais (podem ser null se não disponíveis)
    charm_points = Column(Integer, nullable=True)
    bosstiary_points = Column(Integer, nullable=True)
    achievement_points = Column(Integer, nullable=True)
    
    # Informações adicionais
    vocation = Column(String(50))
    residence = Column(String(255))
    house = Column(String(255), nullable=True)
    guild = Column(String(255), nullable=True)
    guild_rank = Column(String(100), nullable=True)
    
    # Status do personagem
    is_online = Column(Boolean, default=False)
    last_login = Column(DateTime(timezone=True), nullable=True)
    
    # Outfit (para futuras implementações)
    outfit_data = Column(Text, nullable=True)  # JSON string com dados do outfit
    
    # Metadados do scraping
    scraped_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False, index=True)
    scrape_source = Column(String(100), default="manual")  # manual, scheduled, retry
    scrape_duration = Column(Integer, nullable=True)  # duração em milissegundos
    
    # Relacionamentos
    character = relationship("Character", back_populates="snapshots")
    
    # Índices para performance
    __table_args__ = (
        Index('idx_snapshot_character_scraped', 'character_id', 'scraped_at'),
        Index('idx_snapshot_scraped_at', 'scraped_at'),
    )

    def __repr__(self):
        return f"<CharacterSnapshot(character_id={self.character_id}, level={self.level}, exp={self.experience}, scraped_at='{self.scraped_at}')>"


# Função para criar todas as tabelas
def create_tables(engine):
    """Criar todas as tabelas no banco de dados"""
    Base.metadata.create_all(bind=engine) 