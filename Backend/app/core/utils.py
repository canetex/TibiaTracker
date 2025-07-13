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
    Calcular a última experiência válida (diferente de None) e sua data
    
    Args:
        snapshots: Lista de snapshots do personagem
        
    Returns:
        Tuple[Optional[int], Optional[str]]: (experiência, data_formatada) ou (None, None)
    """
    if not snapshots:
        return None, None
    
    # Ordenar snapshots por data (mais recente primeiro)
    sorted_snapshots = sorted(snapshots, key=lambda x: x.scraped_at, reverse=True)
    
    # Procurar o primeiro snapshot com experiência válida (diferente de None)
    for snapshot in sorted_snapshots:
        if snapshot.experience is not None:
            return snapshot.experience, format_date_pt_br(snapshot.scraped_at)
    
    # Se não encontrou nenhuma experiência válida
    return None, None


def calculate_experience_stats(snapshots: list, days: int = 30) -> dict:
    """
    Calcular estatísticas de experiência para um período específico
    
    Args:
        snapshots: Lista de snapshots do personagem
        days: Número de dias para análise (padrão: 30)
        
    Returns:
        dict: Dicionário com estatísticas de experiência
    """
    if not snapshots:
        return {
            'total_exp_gained': 0,
            'average_daily_exp': 0,
            'last_experience': None,
            'last_experience_date': None,
            'exp_gained': 0
        }
    
    # Calcular data limite
    cutoff_date = get_utc_now() - timedelta(days=days)
    
    # Filtrar snapshots do período
    recent_snapshots = [
        snap for snap in snapshots 
        if snap.scraped_at >= cutoff_date
    ]
    
    # Calcular experiência total ganha no período
    total_exp_gained = sum(max(0, snap.experience) for snap in recent_snapshots)
    
    # Calcular média diária
    average_daily_exp = 0
    if len(recent_snapshots) > 1:
        days_diff = days_between(recent_snapshots[0].scraped_at, recent_snapshots[-1].scraped_at)
        if days_diff > 0:
            average_daily_exp = total_exp_gained / days_diff
    elif len(recent_snapshots) == 1:
        average_daily_exp = total_exp_gained
    
    # Calcular última experiência válida
    last_experience, last_experience_date = calculate_last_experience_data(snapshots)
    
    return {
        'total_exp_gained': total_exp_gained,
        'average_daily_exp': average_daily_exp,
        'last_experience': last_experience,
        'last_experience_date': last_experience_date,
        'exp_gained': total_exp_gained  # Alias para compatibilidade
    } 