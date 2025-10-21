"""
Web Router - HTML Page Serving
"""
from pathlib import Path

from fastapi import APIRouter, Request
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates

router = APIRouter(tags=["web"])

# Setup Jinja2 templates (절대경로 사용)
TEMPLATE_DIR = Path(__file__).parent / "templates"
templates = Jinja2Templates(directory=str(TEMPLATE_DIR))


@router.get("/", response_class=HTMLResponse)
async def landing_page(request: Request):
    """
    랜딩 페이지

    Returns:
        HTML 페이지
    """
    return templates.TemplateResponse("landing.html", {"request": request})


@router.get("/conversations", response_class=HTMLResponse)
async def conversation_list_page(request: Request):
    """
    대화 목록 페이지

    Returns:
        HTML 페이지
    """
    return templates.TemplateResponse("conversation_list.html", {"request": request})


@router.get("/conversations/new", response_class=HTMLResponse)
async def new_chat_page(request: Request):
    """
    새 대화 페이지

    Returns:
        HTML 페이지
    """
    return templates.TemplateResponse("chat.html", {"request": request})


@router.get("/conversations/{conversation_id}", response_class=HTMLResponse)
async def chat_page(request: Request, conversation_id: str):
    """
    채팅 페이지

    Args:
        conversation_id: 대화 ID

    Returns:
        HTML 페이지
    """
    return templates.TemplateResponse(
        "chat.html",
        {"request": request, "conversation_id": conversation_id}
    )


@router.get("/grammar/stats", response_class=HTMLResponse)
async def grammar_stats_page(request: Request):
    """
    문법 통계 페이지

    Returns:
        HTML 페이지
    """
    return templates.TemplateResponse("grammar_stats.html", {"request": request})
