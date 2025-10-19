"""
공통 유틸리티 함수
"""
from datetime import datetime, timedelta


def format_datetime(dt: datetime, format_str: str = "%Y-%m-%d %H:%M:%S") -> str:
    """
    DateTime을 문자열로 포맷팅

    Args:
        dt: DateTime 객체
        format_str: 포맷 문자열

    Returns:
        포맷팅된 문자열
    """
    return dt.strftime(format_str)


def format_duration(seconds: int) -> str:
    """
    초를 시간 형식으로 포맷팅

    Args:
        seconds: 초

    Returns:
        "HH:MM:SS" 형식 문자열
    """
    duration = timedelta(seconds=seconds)
    hours, remainder = divmod(duration.seconds, 3600)
    minutes, seconds = divmod(remainder, 60)
    return f"{hours:02d}:{minutes:02d}:{seconds:02d}"


def truncate_text(text: str, max_length: int = 100, suffix: str = "...") -> str:
    """
    텍스트를 지정된 길이로 자르기

    Args:
        text: 원본 텍스트
        max_length: 최대 길이
        suffix: 말줄임 표시

    Returns:
        잘린 텍스트
    """
    if len(text) <= max_length:
        return text
    return text[: max_length - len(suffix)] + suffix
