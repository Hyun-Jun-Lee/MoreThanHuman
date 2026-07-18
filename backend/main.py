"""
FastAPI 메인 애플리케이션
"""
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles

from config import get_settings
from database import Base, engine
from domains.auth.models import ProfileModel  # noqa: F401 - 테이블 생성용 import
from domains.auth.router import router as auth_router
from domains.conversation.router import router as conversation_router
from domains.grammar.router import router as grammar_router
from domains.search.router import router as search_router
from domains.web.router import router as web_router
from shared.exceptions import AppException, AuthenticationException, NotFoundException

settings = get_settings()


# Lifespan 이벤트 핸들러
@asynccontextmanager
async def lifespan(_app: FastAPI):
    """애플리케이션 생명주기 관리"""
    # Startup
    if settings.auto_create_tables:
        Base.metadata.create_all(bind=engine)
        print("✅ Database tables created via SQLAlchemy metadata")
    else:
        print("✅ Database migrations are managed by Alembic")
    print(f"✅ Application started in {'DEBUG' if settings.debug else 'PRODUCTION'} mode")

    yield

    # Shutdown
    print("👋 Application shutting down")


# FastAPI 앱 생성
app = FastAPI(
    title="영어 회화 학습 API",
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


# Exception Handlers
@app.exception_handler(AuthenticationException)
async def authentication_exception_handler(_request, exc: AuthenticationException):
    """401 인증 에러 핸들러"""
    return JSONResponse(
        status_code=401,
        content={"success": False, "error": exc.message, "details": exc.details},
    )


@app.exception_handler(NotFoundException)
async def not_found_exception_handler(_request, exc: NotFoundException):
    """404 에러 핸들러"""
    return JSONResponse(
        status_code=404,
        content={"success": False, "error": exc.message, "details": exc.details},
    )


@app.exception_handler(AppException)
async def app_exception_handler(_request, exc: AppException):
    """애플리케이션 에러 핸들러"""
    return JSONResponse(
        status_code=400,
        content={"success": False, "error": exc.message, "details": exc.details},
    )


# Static Files (정적 파일은 API 라우터보다 먼저 등록)
# 프로젝트 루트의 static 디렉토리 (backend/main.py 기준 상위 디렉토리)
STATIC_DIR = Path(__file__).parent.parent / "static"
app.mount("/static", StaticFiles(directory=str(STATIC_DIR)), name="static")

# API 라우터 등록
app.include_router(auth_router)
app.include_router(conversation_router)
app.include_router(grammar_router)
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
