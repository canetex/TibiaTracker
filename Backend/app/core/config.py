"""
Configurações da Aplicação
==========================

Gerencia todas as configurações usando Pydantic Settings
para validação e carregamento de variáveis de ambiente.
"""

from pydantic_settings import BaseSettings
from pydantic import validator, Field
from typing import List, Optional
import os


class Settings(BaseSettings):
    """Configurações principais da aplicação"""
    
    # ==========================================================================
    # CONFIGURAÇÕES GERAIS
    # ==========================================================================
    ENVIRONMENT: str = Field(default="development", description="Ambiente de execução")
    DEBUG: bool = Field(default=True, description="Modo debug")
    SECRET_KEY: str = Field(..., description="Chave secreta para JWT")
    
    # ==========================================================================
    # API CONFIGURAÇÕES
    # ==========================================================================
    API_HOST: str = Field(default="0.0.0.0", description="Host da API")
    API_PORT: int = Field(default=8000, description="Porta da API")
    API_WORKERS: int = Field(default=4, description="Número de workers")
    API_RELOAD: bool = Field(default=True, description="Auto-reload em desenvolvimento")
    
    # ==========================================================================
    # BANCO DE DADOS
    # ==========================================================================
    DB_HOST: str = Field(default="localhost", description="Host do PostgreSQL")
    DB_PORT: int = Field(default=5432, description="Porta do PostgreSQL")
    DB_NAME: str = Field(default="tibia_tracker", description="Nome do banco")
    DB_USER: str = Field(default="tibia_user", description="Usuário do banco")
    DB_PASSWORD: str = Field(..., description="Senha do banco")
    DATABASE_URL: Optional[str] = Field(default=None, description="URL completa do banco")
    
    @validator('DATABASE_URL', pre=True)
    def assemble_db_connection(cls, v, values):
        if isinstance(v, str):
            return v
        return f"postgresql://{values.get('DB_USER')}:{values.get('DB_PASSWORD')}@{values.get('DB_HOST')}:{values.get('DB_PORT')}/{values.get('DB_NAME')}"
    
    # ==========================================================================
    # REDIS (CACHE)
    # ==========================================================================
    REDIS_HOST: str = Field(default="localhost", description="Host do Redis")
    REDIS_PORT: int = Field(default=6379, description="Porta do Redis")
    REDIS_PASSWORD: Optional[str] = Field(default=None, description="Senha do Redis")
    REDIS_URL: Optional[str] = Field(default=None, description="URL completa do Redis")
    
    @validator('REDIS_URL', pre=True)
    def assemble_redis_connection(cls, v, values):
        if isinstance(v, str):
            return v
        password = f":{values.get('REDIS_PASSWORD')}@" if values.get('REDIS_PASSWORD') else ""
        return f"redis://{password}{values.get('REDIS_HOST')}:{values.get('REDIS_PORT')}/0"
    
    # ==========================================================================
    # JWT TOKENS
    # ==========================================================================
    JWT_SECRET_KEY: str = Field(..., description="Chave JWT")
    JWT_ALGORITHM: str = Field(default="HS256", description="Algoritmo JWT")
    JWT_EXPIRATION_HOURS: int = Field(default=24, description="Expiração do token em horas")
    
    # ==========================================================================
    # WEB SCRAPING
    # ==========================================================================
    USER_AGENT: str = Field(
        default="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        description="User-Agent para scraping"
    )
    SCRAPE_DELAY_SECONDS: int = Field(default=2, description="Delay entre requests")
    SCRAPE_TIMEOUT_SECONDS: int = Field(default=30, description="Timeout das requisições")
    SCRAPE_RETRY_ATTEMPTS: int = Field(default=3, description="Tentativas de retry")
    SCRAPE_RETRY_DELAY_MINUTES: int = Field(default=5, description="Delay entre retries")
    
    # ==========================================================================
    # SERVIDORES TIBIA
    # ==========================================================================
    TALEON_SAN_URL: str = Field(default="https://san.taleon.online", description="URL Taleon San")
    TALEON_AURA_URL: str = Field(default="https://aura.taleon.online", description="URL Taleon Aura")
    TALEON_GAIA_URL: str = Field(default="https://gaia.taleon.online", description="URL Taleon Gaia")
    
    # ==========================================================================
    # AGENDAMENTO
    # ==========================================================================
    SCHEDULER_TIMEZONE: str = Field(default="America/Sao_Paulo", description="Timezone do scheduler")
    DAILY_UPDATE_HOUR: int = Field(default=0, description="Hora da atualização diária")
    DAILY_UPDATE_MINUTE: int = Field(default=1, description="Minuto da atualização diária")
    
    # ==========================================================================
    # AUTENTICAÇÃO
    # ==========================================================================
    GOOGLE_CLIENT_ID: Optional[str] = Field(default=None, description="Google OAuth Client ID")
    GOOGLE_CLIENT_SECRET: Optional[str] = Field(default=None, description="Google OAuth Secret")
    DISCORD_CLIENT_ID: Optional[str] = Field(default=None, description="Discord OAuth Client ID")
    DISCORD_CLIENT_SECRET: Optional[str] = Field(default=None, description="Discord OAuth Secret")
    
    # ==========================================================================
    # CORS E SEGURANÇA
    # ==========================================================================
    ALLOWED_ORIGINS: List[str] = Field(
        default=["http://localhost:3000", "https://localhost:3000"],
        description="Origins permitidas para CORS"
    )
    ALLOWED_HOSTS: List[str] = Field(
        default=["localhost", "127.0.0.1"],
        description="Hosts confiáveis"
    )
    
    # ==========================================================================
    # LOGGING
    # ==========================================================================
    LOG_LEVEL: str = Field(default="INFO", description="Nível de log")
    LOG_FORMAT: str = Field(
        default="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
        description="Formato do log"
    )
    LOG_FILE: str = Field(
        default="/var/log/tibia-tracker/app.log",
        description="Arquivo de log"
    )
    
    # ==========================================================================
    # CACHE CONFIGURAÇÕES
    # ==========================================================================
    CACHE_TTL_SECONDS: int = Field(default=300, description="TTL padrão do cache")
    CACHE_CHARACTER_TTL: int = Field(default=3600, description="TTL cache de personagem")
    
    # ==========================================================================
    # RATE LIMITING
    # ==========================================================================
    RATE_LIMIT_PER_MINUTE: int = Field(default=60, description="Limite de requests por minuto")
    RATE_LIMIT_BURST: int = Field(default=10, description="Burst de requests")
    
    @validator('ALLOWED_ORIGINS', pre=True)
    def parse_cors_origins(cls, v):
        if isinstance(v, str):
            return [x.strip() for x in v.split(',')]
        return v
    
    @validator('ALLOWED_HOSTS', pre=True)
    def parse_allowed_hosts(cls, v):
        if isinstance(v, str):
            return [x.strip() for x in v.split(',')]
        return v
    
    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = True


# Instância global das configurações
settings = Settings()


def get_settings() -> Settings:
    """Obter instância das configurações"""
    return settings 