"""
FastAPI 메인 애플리케이션
"""
import os
import re
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.exception_handlers import http_exception_handler, request_validation_exception_handler
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from starlette.exceptions import HTTPException as StarletteHTTPException

from config import get_settings
from database import Base, engine
from domains.auth.models import ProfileModel  # noqa: F401 - 테이블 생성용 import
from shared.subscription import AppleSubscriptionModel, AppleNotificationModel  # noqa: F401 - 테이블 생성용 import
from domains.auth.router import router as auth_router
from domains.conversation.router import router as conversation_router
from domains.billing.router import router as billing_router
from domains.conversation.topic_router import router as conversation_topic_router
from domains.grammar.router import router as grammar_router
from domains.language_snacks.models import LanguageSnackModel  # noqa: F401 - 테이블 생성용 import
from domains.language_snacks.router import router as language_snacks_router
from domains.search.router import router as search_router
from domains.web.router import router as web_router
from shared.exceptions import AppException, AuthenticationException, NotFoundException
from shared.latency import LatencyMiddleware
from shared.background_tasks import BackgroundTaskRegistry
from shared.http_clients import http_clients
from shared.logging_config import configure_logging, log_event, log_exception

settings = get_settings()
configure_logging()


# Lifespan 이벤트 핸들러
@asynccontextmanager
async def lifespan(_app: FastAPI):
    """애플리케이션 생명주기 관리"""
    # Startup
    if settings.audio_cache_dir:
        cache_dir = Path(settings.audio_cache_dir)
        if not cache_dir.is_absolute() or not cache_dir.is_dir() or not os.access(cache_dir, os.W_OK):
            raise RuntimeError("AUDIO_CACHE_DIR must be an existing writable absolute directory")
        if not settings.is_dev and not os.path.ismount(cache_dir):
            raise RuntimeError("AUDIO_CACHE_DIR must be a mounted persistent volume in production")
    if settings.auto_create_tables:
        Base.metadata.create_all(bind=engine)
        log_event("app.database.metadata_created")
    else:
        log_event("app.database.migrations_managed")
    log_event("app.started")

    async with http_clients(settings) as clients:
        _app.state.http_clients = clients
        tasks = BackgroundTaskRegistry()
        _app.state.background_tasks = tasks
        try:
            yield
        finally:
            # 문법 작업이 공유 client를 사용하는 동안 먼저 닫지 않아요.
            await tasks.aclose(grace_seconds=settings.background_shutdown_grace_seconds)
            log_event("app.stopped")


# FastAPI 앱 생성
app = FastAPI(
    title="tomatalk API",
    description="AI 기반 영어 회화 학습 플랫폼",
    version="1.0.0",
    debug=settings.debug,
    lifespan=lifespan,
)

# CORS 설정
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["*"],
)
app.add_middleware(LatencyMiddleware)


# Exception Handlers
@app.exception_handler(AuthenticationException)
async def authentication_exception_handler(_request, exc: AuthenticationException):
    """401 인증 에러 핸들러"""
    log_exception(exc, status_code=401, error_code="AUTHENTICATION_FAILED")
    return JSONResponse(
        status_code=401,
        content={"success": False, "error": exc.message, "details": exc.details},
    )


@app.exception_handler(NotFoundException)
async def not_found_exception_handler(_request, exc: NotFoundException):
    """404 에러 핸들러"""
    log_exception(exc, status_code=404, error_code="NOT_FOUND")
    return JSONResponse(
        status_code=404,
        content={"success": False, "error": exc.message, "details": exc.details},
    )


@app.exception_handler(AppException)
async def app_exception_handler(_request, exc: AppException):
    """애플리케이션 에러 핸들러"""
    log_exception(exc, status_code=400, error_code=type(exc).__name__)
    return JSONResponse(
        status_code=400,
        content={"success": False, "error": exc.message, "details": exc.details},
    )


@app.exception_handler(StarletteHTTPException)
async def http_error_handler(request, exc: StarletteHTTPException):
    cause = exc.__cause__ or exc.__context__
    detail = exc.detail
    code = detail.get("code") if isinstance(detail, dict) else None
    error_code = f"HTTP_{exc.status_code}"
    if isinstance(code, str) and re.fullmatch(r"[A-Z][A-Z0-9_]{0,63}", code):
        error_code = code
    log_exception(cause or exc, status_code=exc.status_code, error_code=error_code)
    return await http_exception_handler(request, exc)


@app.exception_handler(RequestValidationError)
async def validation_error_handler(request, exc: RequestValidationError):
    log_exception(exc, status_code=422, error_code="REQUEST_VALIDATION_ERROR")
    return await request_validation_exception_handler(request, exc)


# Static Files (정적 파일은 API 라우터보다 먼저 등록)
# 프로젝트 루트의 static 디렉토리 (backend/main.py 기준 상위 디렉토리)
STATIC_DIR = Path(__file__).parent.parent / "static"
app.mount("/static", StaticFiles(directory=str(STATIC_DIR)), name="static")

# API 라우터 등록
app.include_router(auth_router)
app.include_router(conversation_router)
app.include_router(billing_router)
app.include_router(conversation_topic_router)
app.include_router(grammar_router)
app.include_router(language_snacks_router)
app.include_router(search_router)

# Web 라우터 등록 (마지막에 등록하여 API 우선순위 보장)
app.include_router(web_router)


# Health Check (API only)
@app.get("/health", tags=["health"])
async def health_check():
    """상세 헬스 체크"""
    return {
        "status": "healthy",
        "database": "connected",
        "version": "1.0.0",
    }


# 직접 실행 지원
if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8010,
        reload=True,
        reload_dirs=["backend", "static"],
    )
