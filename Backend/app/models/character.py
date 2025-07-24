"""
Modelos de banco de dados para personagens do Tibia
===================================================

Modelos SQLAlchemy para armazenar informações de personagens
e seus históricos de snapshots diários.
"""

from sqlalchemy import Column, Integer, String, Boolean, DateTime, Text, BigInteger, ForeignKey, Index, UniqueConstraint, Date
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from datetime import datetime

# Importar Base centralizada do database.py
from app.db.database import Base


class Character(Base):
    """
    Modelo principal para armazenar informações de personagens
    
    Armazena informações básicas e estado atual do personagem.
    O histórico completo fica em CharacterSnapshot.
    """
    __tablename__ = "characters"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), nullable=False, index=True)
    server = Column(String(50), nullable=False, index=True)  # taleon, rubini, etc
    world = Column(String(50), nullable=False, index=True)   # san, aura, gaia, etc (current world)
    
    # Informações básicas do personagem (estado atual)
    level = Column(Integer, default=0)
    vocation = Column(String(50), default="None")
    residence = Column(String(255))
    guild = Column(String(255), nullable=True)
    
    # Status e configurações
    is_active = Column(Boolean, default=True, index=True)
    is_public = Column(Boolean, default=True)
    recovery_active = Column(Boolean, default=True, index=True)  # Controla se deve receber scraping automático
    
    # URLs e identificadores
    profile_url = Column(String(500))
    character_url = Column(String(500))
    
    # Outfit atual (URL da imagem se disponível)
    outfit_image_url = Column(String(500), nullable=True)
    outfit_image_path = Column(String(500), nullable=True)  # Caminho local da imagem
    
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

    def __repr__(self):
        return f"<Character(id={self.id}, name='{self.name}', server='{self.server}', world='{self.world}', level={self.level})>"


class CharacterSnapshot(Base):
    """
    Modelo para armazenar snapshots históricos DIÁRIOS dos personagens
    
    Cada registro representa o estado do personagem em um determinado dia.
    Permite rastrear evolução de level, experiência, mortes, pontos especiais, etc.
    
    IMPORTANTE: 
    - exp_date = data a qual se refere a experiência (chave única)
    - scraped_at = data/hora em que o scraping foi realizado
    - experience = experiência ganha naquele dia específico
    """
    __tablename__ = "character_snapshots"

    id = Column(Integer, primary_key=True, index=True)
    character_id = Column(Integer, ForeignKey("characters.id"), nullable=False, index=True)
    
    # ===== DADOS BÁSICOS DO PERSONAGEM =====
    level = Column(Integer, default=0, nullable=False)
    experience = Column(BigInteger, default=0, nullable=False)  # Experiência ganha naquele dia específico
    deaths = Column(Integer, default=0, nullable=False)
    
    # ===== PONTOS ESPECIAIS (podem ser null se não disponíveis) =====
    charm_points = Column(Integer, nullable=True)
    bosstiary_points = Column(Integer, nullable=True)
    achievement_points = Column(Integer, nullable=True)
    
    # ===== INFORMAÇÕES ADICIONAIS =====
    vocation = Column(String(50), nullable=False)
    world = Column(String(50), nullable=False, index=True)  # IMPORTANTE: rastreia mudanças de world
    residence = Column(String(255), nullable=True)
    house = Column(String(255), nullable=True)
    guild = Column(String(255), nullable=True)
    guild_rank = Column(String(100), nullable=True)
    
    # ===== STATUS DO PERSONAGEM =====
    is_online = Column(Boolean, default=False)
    last_login = Column(DateTime(timezone=True), nullable=True)
    
    # ===== OUTFIT INFORMATION =====
    outfit_image_url = Column(String(500), nullable=True)  # URL da imagem do outfit
    outfit_image_path = Column(String(500), nullable=True)  # Caminho local da imagem
    outfit_data = Column(Text, nullable=True)  # JSON string com dados detalhados do outfit
    profile_url = Column(String(500), nullable=True)
    
    # ===== DATAS IMPORTANTES =====
    exp_date = Column(Date, nullable=False, index=True)  # Data da experiência (chave única)
    scraped_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False, index=True)  # Data do scraping
    
    # ===== METADADOS DO SCRAPING =====
    scrape_source = Column(String(100), default="manual")  # manual, scheduled, retry
    scrape_duration = Column(Integer, nullable=True)  # duração em milissegundos
    
    # Relacionamentos
    character = relationship("Character", back_populates="snapshots")
    
    # Índices para performance e consultas históricas
    __table_args__ = (
        UniqueConstraint('character_id', 'exp_date', name='uq_character_exp_date'),
        Index('idx_snapshot_character_scraped', 'character_id', 'scraped_at'),
        Index('idx_snapshot_scraped_at', 'scraped_at'),
        Index('idx_snapshot_character_world', 'character_id', 'world'),
        Index('idx_snapshot_level_experience', 'level', 'experience'),
        Index('idx_snapshot_points', 'charm_points', 'bosstiary_points', 'achievement_points'),
        Index('idx_snapshot_exp_date', 'exp_date'),
        Index('idx_snapshot_temporal', 'character_id', 'exp_date', postgresql_ops={'exp_date': 'DESC'}),
    )

    def __repr__(self):
        return f"<CharacterSnapshot(character_id={self.character_id}, level={self.level}, exp={self.experience}, world='{self.world}', exp_date='{self.exp_date}', scraped_at='{self.scraped_at}')>"


class CharacterFavorite(Base):
    """
    Modelo para armazenar relação entre usuários e personagens favoritos
    
    Preparado para futura implementação de sistema de usuários.
    Atualmente usa user_id = 1 para compatibilidade.
    """
    __tablename__ = "character_favorites"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, nullable=False, default=1, index=True)  # user_id = 1 para compatibilidade atual
    character_id = Column(Integer, ForeignKey("characters.id"), nullable=False, index=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    
    # Relacionamentos
    character = relationship("Character")
    
    # Índices para performance
    __table_args__ = (
        UniqueConstraint('user_id', 'character_id', name='uq_user_character_favorite'),
        Index('idx_favorites_user', 'user_id'),
        Index('idx_favorites_character', 'character_id'),
    )

    def __repr__(self):
        return f"<CharacterFavorite(user_id={self.user_id}, character_id={self.character_id}, created_at='{self.created_at}')>" 