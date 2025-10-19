"""
커스텀 예외 정의
"""


class AppException(Exception):
    """애플리케이션 기본 예외"""

    def __init__(self, message: str, details: dict | None = None):
        self.message = message
        self.details = details or {}
        super().__init__(message)


class NotFoundException(AppException):
    """리소스를 찾을 수 없을 때"""

    pass


class ValidationException(AppException):
    """유효성 검증 실패"""

    pass


class ExternalAPIException(AppException):
    """외부 API 호출 실패"""

    pass
