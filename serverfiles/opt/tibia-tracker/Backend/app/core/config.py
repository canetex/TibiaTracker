"""
Configurações da aplicação
=========================

Gerenciamento centralizado de configurações usando Pydantic Settings.
"""

from pydantic_settings import BaseSettings
from pydantic import Field, validator
from typing import List, Optional
import os


class Settings(BaseSettings):
    """Configurações da aplicação"""
    
    # Configurações gerais
    ENVIRONMENT: str = Field(default="development", description="Ambiente de execução")
    DEBUG: bool = Field(default=True, description="Modo debug")
    SECRET_KEY: str = Field(..., description="Chave secreta da aplicação")
    
    # Banco de dados PostgreSQL
    DB_HOST: str = Field(default="localhost", description="Host do banco")
    DB_PORT: int = Field(default=5432, description="Porta do banco")
    DB_NAME: str = Field(default="tibia_tracker", description="Nome do banco")
    DB_USER: str = Field(default="tibia_user", description="Usuário do banco")
    DB_PASSWORD: str = Field(..., description="Senha do banco")
    DATABASE_URL: Optional[str] = Field(default=None, description="URL completa do banco")
    
    # Redis Cache
    REDIS_HOST: str = Field(default="localhost", description="Host do Redis")
    REDIS_PORT: int = Field(default=6379, description="Porta do Redis")
    REDIS_PASSWORD: Optional[str] = Field(default=None, description="Senha do Redis")
    REDIS_URL: Optional[str] = Field(default=None, description="URL completa do Redis")
    
    # API Configurações
    API_HOST: str = Field(default="0.0.0.0", description="Host da API")
    API_PORT: int = Field(default=8000, description="Porta da API")
    API_WORKERS: int = Field(default=4, description="Número de workers")
    API_RELOAD: bool = Field(default=True, description="Auto-reload do código")
    
    # Autenticação
    JWT_SECRET_KEY: str = Field(..., description="Chave secreta JWT")
    JWT_ALGORITHM: str = Field(default="HS256", description="Algoritmo JWT")
    JWT_EXPIRATION_HOURS: int = Field(default=24, description="Expiração do token em horas")
    
    # OAuth - Google
    GOOGLE_CLIENT_ID: Optional[str] = Field(default=None, description="Google OAuth Client ID")
    GOOGLE_CLIENT_SECRET: Optional[str] = Field(default=None, description="Google OAuth Secret")
    GOOGLE_REDIRECT_URI: Optional[str] = Field(default=None, description="Google OAuth Redirect URI")
    
    # OAuth - Discord
    DISCORD_CLIENT_ID: Optional[str] = Field(default=None, description="Discord OAuth Client ID")
    DISCORD_CLIENT_SECRET: Optional[str] = Field(default=None, description="Discord OAuth Secret")
    DISCORD_REDIRECT_URI: Optional[str] = Field(default=None, description="Discord OAuth Redirect URI")
    
    # URLs Base
    BASE_URL: str = Field(default="http://localhost", description="URL base da aplicação")
    API_BASE_URL: str = Field(default="http://localhost:8000", description="URL base da API")
    
    # Web Scraping
    USER_AGENT: str = Field(
        default="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        description="User Agent para scraping"
    )
    SCRAPE_DELAY_SECONDS: int = Field(default=2, description="Delay entre requests")
    SCRAPE_TIMEOUT_SECONDS: int = Field(default=30, description="Timeout das requests")
    SCRAPE_RETRY_ATTEMPTS: int = Field(default=3, description="Tentativas de retry")
    SCRAPE_RETRY_DELAY_MINUTES: int = Field(default=5, description="Delay entre retries")
    
    # Agendamento
    SCHEDULER_TIMEZONE: str = Field(default="America/Sao_Paulo", description="Timezone do scheduler")
    DAILY_UPDATE_HOUR: int = Field(default=0, description="Hora da atualização diária")
    DAILY_UPDATE_MINUTE: int = Field(default=1, description="Minuto da atualização diária")
    
    # URLs dos servidores Tibia
    TALEON_SAN_URL: str = Field(default="https://san.taleon.online", description="URL do Taleon San")
    TALEON_AURA_URL: str = Field(default="https://aura.taleon.online", description="URL do Taleon Aura")
    TALEON_GAIA_URL: str = Field(default="https://gaia.taleon.online", description="URL do Taleon Gaia")
    
    # CORS e Segurança
    ALLOWED_ORIGINS: List[str] = Field(
        default=["http://localhost:3000", "http://localhost:8000"],
        description="Origens permitidas para CORS"
    )
    ALLOWED_HOSTS: List[str] = Field(
        default=["localhost", "127.0.0.1"],
        description="Hosts permitidos"
    )
    CORS_ALLOW_CREDENTIALS: bool = Field(default=True, description="Permitir credentials no CORS")
    
    # Logs
    LOG_LEVEL: str = Field(default="INFO", description="Nível de log")
    LOG_FORMAT: str = Field(
        default="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
        description="Formato do log"
    )
    LOG_FILE: str = Field(default="/var/log/tibia-tracker/app.log", description="Arquivo de log")
    
    # Docker e Deploy
    DOCKER_REGISTRY: str = Field(default="localhost", description="Registry do Docker")
    DOCKER_TAG: str = Field(default="latest", description="Tag do Docker")
    COMPOSE_PROJECT_NAME: str = Field(default="tibia-tracker", description="Nome do projeto Docker")
    
    # Caddy (Proxy Reverso)
    DOMAIN: str = Field(default="localhost", description="Domínio da aplicação")
    SSL_EMAIL: str = Field(default="admin@localhost", description="Email para SSL")
    CADDY_PORT: int = Field(default=80, description="Porta do Caddy HTTP")
    CADDY_HTTPS_PORT: int = Field(default=443, description="Porta do Caddy HTTPS")
    
    # Monitoramento
    PROMETHEUS_PORT: int = Field(default=9090, description="Porta do Prometheus")
    NODE_EXPORTER_PORT: int = Field(default=9100, description="Porta do Node Exporter")
    
    @validator("DATABASE_URL", pre=True, always=True)
    def build_database_url(cls, v: Optional[str], values: dict) -> str:
        """Construir URL do banco de dados se não fornecida"""
        if v:
            return v
        
        db_user = values.get("DB_USER", "tibia_user")
        db_password = values.get("DB_PASSWORD", "")
        db_host = values.get("DB_HOST", "localhost")
        db_port = values.get("DB_PORT", 5432)
        db_name = values.get("DB_NAME", "tibia_tracker")
        
        return f"postgresql+asyncpg://{db_user}:{db_password}@{db_host}:{db_port}/{db_name}"
    
    @validator("REDIS_URL", pre=True, always=True)
    def build_redis_url(cls, v: Optional[str], values: dict) -> str:
        """Construir URL do Redis se não fornecida"""
        if v:
            return v
        
        redis_password = values.get("REDIS_PASSWORD", "")
        redis_host = values.get("REDIS_HOST", "localhost")
        redis_port = values.get("REDIS_PORT", 6379)
        
        if redis_password:
            return f"redis://:{redis_password}@{redis_host}:{redis_port}/0"
        else:
            return f"redis://{redis_host}:{redis_port}/0"
    
    @validator("ALLOWED_ORIGINS", pre=True)
    def parse_cors_origins(cls, v) -> List[str]:
        """Parse das origens CORS"""
        if isinstance(v, str):
            return [origin.strip() for origin in v.split(",")]
        return v
    
    @validator("ALLOWED_HOSTS", pre=True)
    def parse_allowed_hosts(cls, v) -> List[str]:
        """Parse dos hosts permitidos"""
        if isinstance(v, str):
            return [host.strip() for host in v.split(",")]
        return v
    
    @validator("LOG_LEVEL")
    def validate_log_level(cls, v: str) -> str:
        """Validar nível de log"""
        valid_levels = ["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"]
        if v.upper() not in valid_levels:
            raise ValueError(f"Log level deve ser um de: {valid_levels}")
        return v.upper()
    
    @property
    def is_development(self) -> bool:
        """Verificar se está em ambiente de desenvolvimento"""
        return self.ENVIRONMENT.lower() == "development"
    
    @property
    def is_production(self) -> bool:
        """Verificar se está em ambiente de produção"""
        return self.ENVIRONMENT.lower() == "production"
    
    @property
    def is_testing(self) -> bool:
        """Verificar se está em ambiente de teste"""
        return self.ENVIRONMENT.lower() == "testing"
    
    class Config:
        env_file = ".env"
        case_sensitive = True
        validate_assignment = True


# Instância global das configurações
settings = Settings() 