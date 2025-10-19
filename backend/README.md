# 영어 회화 학습 백엔드

FastAPI 기반 영어 회화 학습 플랫폼 백엔드 API

## 🚀 빠른 시작

### 1. 환경 설정

```bash
# 프로젝트 루트에서 .env 파일 생성
cp .env.example .env
```

.env 파일을 열어 다음 값들을 설정하세요:
- `DATABASE_URL`: PostgreSQL 연결 문자열
- `OPENROUTER_API_KEY`: OpenRouter API 키
- `TAVILY_API_KEY`: Tavily API 키

### 2. 의존성 설치

```bash
pip install -r requirements.txt
```

### 3. 데이터베이스 설정

PostgreSQL 데이터베이스를 생성하세요:

```sql
CREATE DATABASE english_learning;
```

### 4. 서버 실행

```bash
# 개발 모드 (auto-reload)
uvicorn backend.main:app --reload --port 8000

# 프로덕션 모드
uvicorn backend.main:app --host 0.0.0.0 --port 8000
```

서버가 실행되면 다음 주소로 접속할 수 있습니다:
- API: http://localhost:8000
- Swagger 문서: http://localhost:8000/docs
- ReDoc 문서: http://localhost:8000/redoc

## 📂 프로젝트 구조

```
backend/
├── main.py                 # FastAPI 앱 초기화
├── config.py              # 환경 설정
├── database.py            # DB 연결
├── shared/                # 공통 모듈
│   ├── types.py
│   ├── exceptions.py
│   └── utils.py
└── domains/               # 도메인별 모듈
    ├── conversation/
    │   ├── models.py
    │   ├── repository.py
    │   ├── service.py
    │   └── router.py
    ├── grammar/
    │   └── (동일 구조)
    └── search/
        └── (동일 구조)
```

## 🔌 API 엔드포인트

### Conversation (대화)
- `POST /api/conversations/start/` - 대화 시작
- `POST /api/conversations/{id}/message/` - 메시지 전송
- `GET /api/conversations/` - 대화 목록 조회
- `GET /api/conversations/{id}/` - 대화 조회
- `GET /api/conversations/{id}/messages/` - 메시지 목록 조회
- `PUT /api/conversations/{id}/end/` - 대화 종료
- `DELETE /api/conversations/{id}/` - 대화 삭제

### Grammar (문법)
- `POST /api/grammar/check/` - 문법 체크
- `GET /api/grammar/message/{id}/` - 메시지 문법 피드백 조회
- `GET /api/grammar/stats/` - 문법 통계 조회

### Search (검색)
- `POST /api/search/` - 검색 실행

## 🧪 테스트

```bash
# 모든 테스트 실행
pytest

# 커버리지 포함
pytest --cov=backend --cov-report=html
```

## 📝 개발 가이드

### 새 도메인 추가

1. `domains/{domain_name}/` 폴더 생성
2. `models.py` - Pydantic/SQLAlchemy 모델 정의
3. `repository.py` - 데이터 접근 계층
4. `service.py` - 비즈니스 로직
5. `router.py` - API 엔드포인트
6. `main.py`에 라우터 등록

### 순수 함수 원칙

이 프로젝트는 함수형 프로그래밍 원칙을 선호합니다:
- 부수 효과 최소화
- 순수 함수 작성
- 불변성 유지

## 🔧 환경 변수

| 변수 | 설명 | 기본값 |
|------|------|--------|
| `DATABASE_URL` | PostgreSQL 연결 문자열 | 필수 |
| `OPENROUTER_API_KEY` | OpenRouter API 키 | 필수 |
| `TAVILY_API_KEY` | Tavily API 키 | 필수 |
| `DEBUG` | 디버그 모드 | `false` |
| `LLM_MODEL` | 기본 LLM 모델 | `google/gemini-2.0-flash-exp:free` |
| `MAX_TOKENS` | LLM 최대 토큰 | `2000` |
| `TEMPERATURE` | LLM Temperature | `0.7` |
| `MAX_HISTORY_TURNS` | 최대 대화 기록 턴 | `10` |
