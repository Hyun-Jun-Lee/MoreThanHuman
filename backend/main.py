"""
FastAPI 메인 애플리케이션
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from backend.config import get_settings
from backend.database import Base, engine
from backend.domains.conversation.router import router as conversation_router
from backend.domains.grammar.router import router as grammar_router
from backend.domains.search.router import router as search_router
from backend.shared.exceptions import AppException, NotFoundException

settings = get_settings()

# FastAPI 앱 생성
app = FastAPI(
    title="영어 회화 학습 API",
    description="AI 기반 영어 회화 학습 플랫폼",
    version="1.0.0",
    debug=settings.debug,
)

# CORS 설정
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=False,
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["*"],
)


# Exception Handlers
@app.exception_handler(NotFoundException)
async def not_found_exception_handler(request, exc: NotFoundException):
    """404 에러 핸들러"""
    return JSONResponse(
        status_code=404,
        content={"success": False, "error": exc.message, "details": exc.details},
    )


@app.exception_handler(AppException)
async def app_exception_handler(request, exc: AppException):
    """애플리케이션 에러 핸들러"""
    return JSONResponse(
        status_code=400,
        content={"success": False, "error": exc.message, "details": exc.details},
    )


# 라우터 등록
app.include_router(conversation_router)
app.include_router(grammar_router)
app.include_router(search_router)


# Startup/Shutdown 이벤트
@app.on_event("startup")
async def startup_event():
    """애플리케이션 시작 시 실행"""
    # 데이터베이스 테이블 생성
    Base.metadata.create_all(bind=engine)
    print("✅ Database tables created")
    print(f"✅ Application started in {'DEBUG' if settings.debug else 'PRODUCTION'} mode")


@app.on_event("shutdown")
async def shutdown_event():
    """애플리케이션 종료 시 실행"""
    print("👋 Application shutting down")


# Health Check
@app.get("/", tags=["health"])
async def root():
    """헬스 체크"""
    return {
        "status": "ok",
        "message": "영어 회화 학습 API",
        "version": "1.0.0",
    }


@app.get("/health", tags=["health"])
async def health_check():
    """상세 헬스 체크"""
    return {
        "status": "healthy",
        "database": "connected",
        "version": "1.0.0",
    }
