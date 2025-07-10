"""
Utilitários da aplicação
========================

Funções utilitárias para padronizar operações comuns.
"""

from datetime import datetime, timezone, timedelta
from typing import Optional, Tuple


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


def format_date_pt_br(date) -> str:
    """
    Formatar data no padrão brasileiro DD/MM/AAAA
    
    Args:
        date: Data para formatar (datetime ou date)
        
    Returns:
        str: Data formatada como DD/MM/AAAA
    """
    return date.strftime("%d/%m/%Y")


def get_activity_filter_labels() -> dict:
    """
    Obter labels dos filtros de atividade com datas formatadas
    
    Returns:
        dict: Dicionário com labels formatados
    """
    today = get_utc_now().date()
    yesterday = today - timedelta(days=1)
    two_days_ago = today - timedelta(days=2)
    three_days_ago = today - timedelta(days=3)
    
    return {
        'active_today': f"Ativos Hoje ({format_date_pt_br(today)})",
        'active_yesterday': f"Ativos D-1 (Ontem {format_date_pt_br(yesterday)})",
        'active_2days': f"Ativos D-2 ({format_date_pt_br(two_days_ago)})",
        'active_3days': f"Ativos D-3 ({format_date_pt_br(three_days_ago)})"
    }


def calculate_last_experience_data(snapshots: list) -> Tuple[Optional[int], Optional[str]]:
    """
    Calcular a última experiência válida (> 0) e sua data
    
    Args:
        snapshots: Lista de snapshots do personagem
        
    Returns:
        Tuple[Optional[int], Optional[str]]: (experiência, data_formatada) ou (None, None)
    """
    import logging
    logger = logging.getLogger(__name__)
    
    if not snapshots:
        logger.debug("calculate_last_experience_data: Nenhum snapshot fornecido")
        return None, None
    
    logger.debug(f"calculate_last_experience_data: Processando {len(snapshots)} snapshots")
    
    # Ordenar snapshots por data (mais recente primeiro)
    sorted_snapshots = sorted(snapshots, key=lambda x: x.scraped_at, reverse=True)
    
    # Procurar o primeiro snapshot com experiência > 0
    for i, snapshot in enumerate(sorted_snapshots):
        logger.debug(f"Snapshot {i}: experience={snapshot.experience}, scraped_at={snapshot.scraped_at}")
        if snapshot.experience and snapshot.experience > 0:
            result = (snapshot.experience, format_date_pt_br(snapshot.scraped_at))
            logger.debug(f"Encontrou experiência válida: {result}")
            return result
    
    # Se não encontrou nenhuma experiência > 0
    logger.debug("calculate_last_experience_data: Nenhuma experiência > 0 encontrada")
    return None, None 