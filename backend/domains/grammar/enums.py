"""
Grammar 도메인 Enum 정의
"""
from enum import Enum


class ErrorType(str, Enum):
    """에러 타입"""

    GRAMMAR = "grammar"
    WORD_CHOICE = "word_choice"
    EXPRESSION = "expression"
    SPELLING = "spelling"
    PUNCTUATION = "punctuation"
