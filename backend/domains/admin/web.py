from pathlib import Path

from fastapi import APIRouter, Depends, Request
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.templating import Jinja2Templates
from sqlalchemy.orm import Session

from database import get_db
from domains.admin.access import AdminAccessService, cookie_name

router = APIRouter(tags=["admin-web"])
templates = Jinja2Templates(directory=str(Path(__file__).parent / "templates"))


def _page(request: Request, name: str) -> HTMLResponse:
    response = templates.TemplateResponse(name, {"request": request})
    response.headers["Cache-Control"] = "no-store"
    return response


@router.get("/admin/login", response_class=HTMLResponse)
def login_page(request: Request):
    return _page(request, "login.html")


@router.get("/admin", response_class=HTMLResponse)
def admin_page(request: Request, db: Session = Depends(get_db)):
    session = AdminAccessService(db).session(request.cookies.get(cookie_name()))
    if session is None:
        return RedirectResponse("/admin/login", status_code=303)
    return _page(request, "dashboard.html")
