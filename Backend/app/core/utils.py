"""
Utilitários da aplicação
========================

Funções utilitárias para padronizar operações comuns.
"""

from datetime import datetime, timezone
from typing import Optional


def get_utc_now() -> datetime:
    """
    Obter data/hora atual em UTC com timezone
    
    Returns:
        datetime: Data/hora atual em UTC com timezone
    """
    return datetime.now(timezone.utc)


def get_utc_date() -> datetime:
    """
    Obter data atual em UTC (meia-noite) com timezone
    
    Returns:
        datetime: Data atual em UTC com timezone
    """
    now = datetime.now(timezone.utc)
    return now.replace(hour=0, minute=0, second=0, microsecond=0)


def normalize_datetime(dt: Optional[datetime]) -> Optional[datetime]:
    """
    Normalizar datetime para UTC com timezone
    
    Args:
        dt: Datetime para normalizar
        
    Returns:
        datetime: Datetime normalizado ou None se input for None
    """
    if dt is None:
        return None
    
    # Se já tem timezone, retornar como está
    if dt.tzinfo is not None:
        return dt
    
    # Se não tem timezone, assumir UTC
    return dt.replace(tzinfo=timezone.utc)


def compare_dates_safely(date1: Optional[datetime], date2: Optional[datetime]) -> int:
    """
    Comparar duas datas de forma segura, normalizando timezones
    
    Args:
        date1: Primeira data
        date2: Segunda data
        
    Returns:
        int: -1 se date1 < date2, 0 se iguais, 1 se date1 > date2
    """
    if date1 is None and date2 is None:
        return 0
    if date1 is None:
        return -1
    if date2 is None:
        return 1
    
    # Normalizar ambas as datas
    norm_date1 = normalize_datetime(date1)
    norm_date2 = normalize_datetime(date2)
    
    # Agora sabemos que ambas não são None
    if norm_date1 is not None and norm_date2 is not None:
        if norm_date1 < norm_date2:
            return -1
        elif norm_date1 > norm_date2:
            return 1
        else:
            return 0
    
    # Fallback (não deveria chegar aqui)
    return 0


def days_between(date1: datetime, date2: datetime) -> int:
    """
    Calcular diferença em dias entre duas datas
    
    Args:
        date1: Primeira data
        date2: Segunda data
        
    Returns:
        int: Diferença em dias
    """
    # Normalizar ambas as datas
    norm_date1 = normalize_datetime(date1)
    norm_date2 = normalize_datetime(date2)
    
    # Verificar se ambas não são None
    if norm_date1 is None or norm_date2 is None:
        return 0
    
    # Calcular diferença
    diff = abs(norm_date1 - norm_date2)
    return diff.days 