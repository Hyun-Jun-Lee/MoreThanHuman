"""
Auth Service Layer
비즈니스 로직: 비밀번호 해싱, JWT 생성/검증, Google OAuth
"""
import logging
from datetime import datetime, timedelta, timezone
from uuid import uuid4

import bcrypt
import httpx
from jose import JWTError, jwt

from config import get_settings
from domains.auth.models import UserModel
from domains.auth.repository import AuthRepository
from domains.auth.schemas import TokenResponse, UserProfile
from shared.exceptions import AuthenticationException, ValidationException

logger = logging.getLogger(__name__)
settings = get_settings()


class AuthService:
    """인증 서비스"""

    def __init__(self, repository: AuthRepository):
        self.repository = repository

    # --- 비밀번호 ---

    @staticmethod
    def hash_password(password: str) -> str:
        return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")

    @staticmethod
    def verify_password(plain_password: str, hashed_password: str) -> bool:
        return bcrypt.checkpw(plain_password.encode("utf-8"), hashed_password.encode("utf-8"))

    # --- JWT ---

    @staticmethod
    def create_access_token(user_id: str) -> str:
        expire = datetime.now(timezone.utc) + timedelta(minutes=settings.jwt_access_token_expire_minutes)
        payload = {"sub": user_id, "exp": expire}
        return jwt.encode(payload, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)

    @staticmethod
    def decode_access_token(token: str) -> str:
        """토큰 디코딩 → user_id 반환"""
        try:
            payload = jwt.decode(token, settings.jwt_secret_key, algorithms=[settings.jwt_algorithm])
            user_id: str | None = payload.get("sub")
            if user_id is None:
                raise AuthenticationException("Invalid token: missing subject")
            return user_id
        except JWTError as e:
            raise AuthenticationException(f"Invalid token: {str(e)}")

    # --- 회원가입 / 로그인 ---

    def register(self, email: str, password: str, name: str) -> TokenResponse:
        """이메일+비밀번호 회원가입"""
        existing = self.repository.find_by_email(email)
        if existing:
            raise ValidationException("이미 등록된 이메일입니다")

        user = UserModel(
            id=str(uuid4()),
            email=email,
            hashed_password=self.hash_password(password),
            name=name,
        )
        self.repository.save(user)

        token = self.create_access_token(user.id)
        return TokenResponse(access_token=token)

    def login(self, email: str, password: str) -> TokenResponse:
        """이메일+비밀번호 로그인"""
        user = self.repository.find_by_email(email)
        if not user or not user.hashed_password:
            raise AuthenticationException("이메일 또는 비밀번호가 올바르지 않습니다")

        if not self.verify_password(password, user.hashed_password):
            raise AuthenticationException("이메일 또는 비밀번호가 올바르지 않습니다")

        if not user.is_active:
            raise AuthenticationException("비활성화된 계정입니다")

        token = self.create_access_token(user.id)
        return TokenResponse(access_token=token)

    # --- Google OAuth ---

    def get_google_login_url(self) -> str:
        """Google OAuth2 로그인 URL 생성"""
        if not settings.google_client_id:
            raise ValidationException("Google OAuth가 설정되지 않았습니다")

        params = {
            "client_id": settings.google_client_id,
            "redirect_uri": settings.google_redirect_uri,
            "response_type": "code",
            "scope": "openid email profile",
            "access_type": "offline",
        }
        query = "&".join(f"{k}={v}" for k, v in params.items())
        return f"https://accounts.google.com/o/oauth2/v2/auth?{query}"

    async def handle_google_callback(self, code: str) -> TokenResponse:
        """Google OAuth2 콜백 처리"""
        if not settings.google_client_id or not settings.google_client_secret:
            raise ValidationException("Google OAuth가 설정되지 않았습니다")

        # 1. code → access_token 교환
        async with httpx.AsyncClient() as client:
            token_resp = await client.post(
                "https://oauth2.googleapis.com/token",
                data={
                    "code": code,
                    "client_id": settings.google_client_id,
                    "client_secret": settings.google_client_secret,
                    "redirect_uri": settings.google_redirect_uri,
                    "grant_type": "authorization_code",
                },
            )
            if token_resp.status_code != 200:
                logger.error(f"Google token exchange failed: {token_resp.text}")
                raise AuthenticationException("Google 인증에 실패했습니다")

            token_data = token_resp.json()
            google_access_token = token_data["access_token"]

            # 2. access_token → 사용자 정보 조회
            userinfo_resp = await client.get(
                "https://www.googleapis.com/oauth2/v2/userinfo",
                headers={"Authorization": f"Bearer {google_access_token}"},
            )
            if userinfo_resp.status_code != 200:
                raise AuthenticationException("Google 사용자 정보 조회에 실패했습니다")

            userinfo = userinfo_resp.json()

        google_id = userinfo["id"]
        email = userinfo["email"]
        name = userinfo.get("name", email.split("@")[0])

        # 3. 기존 사용자 조회 또는 신규 생성
        user = self.repository.find_by_oauth("google", google_id)
        if not user:
            # 같은 이메일로 가입된 계정이 있는지 확인
            user = self.repository.find_by_email(email)
            if user:
                # 기존 계정에 Google OAuth 연결
                user.oauth_provider = "google"
                user.oauth_provider_id = google_id
                self.repository.save(user)
            else:
                # 신규 사용자 생성
                user = UserModel(
                    id=str(uuid4()),
                    email=email,
                    name=name,
                    oauth_provider="google",
                    oauth_provider_id=google_id,
                )
                self.repository.save(user)

        token = self.create_access_token(user.id)
        return TokenResponse(access_token=token)

    # --- 프로필 ---

    def get_profile(self, user_id: str) -> UserProfile:
        """사용자 프로필 조회"""
        user = self.repository.find_by_id(user_id)
        return UserProfile.model_validate(user)
