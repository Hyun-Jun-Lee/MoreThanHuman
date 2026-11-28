# 시스템 아키텍처

> 프로젝트: MoreThanHuman (서비스명: tomatalk) · 최종 갱신: 2026-11-28 · TTS 음성 설정 반영

---

## 1. 스택

### Backend

| 기술 | 버전 | 역할 |
|------|------|------|
| Python | ≥ 3.12 | 런타임 |
| FastAPI | 0.109.0 | API 프레임워크 |
| SQLAlchemy | 2.0.25 | ORM |
| Pydantic | 2.5.3 | 데이터 검증 |
| pydantic-settings | 2.1.0 | 환경 설정 |
| uvicorn | 0.27.0 | ASGI 서버 |
| httpx | 0.26.0 | 외부 HTTP 클라이언트 |
| Supabase Auth | managed | 모바일 소셜 로그인과 세션 관리 |
| python-jose | ≥ 3.3.0 | 레거시 JWT tooling / JWT 유틸리티 |
| bcrypt | ≥ 4.0.0 | 비밀번호 해싱 |
| ddgs | ≥ 9.0.0 | 웹 검색 |
| psycopg2-binary | 2.9.9 | PostgreSQL 드라이버 |

### Database

| 기술 | 용도 |
|------|------|
| SQLite | 개발 기본값 |
| PostgreSQL | 프로덕션 |

### Client

| 기술 | 상태 |
|------|------|
| Flutter 3.44.2 / Dart 3.12.2 | `mobile/` iOS·Android 프로젝트 초기화 |
| Riverpod 3 | 앱 상태와 비동기 상태 관리 |
| go_router 17 | 선언형 라우팅과 인증 redirect |
| Dio 5 | FastAPI HTTP client와 interceptor |
| flutter_secure_storage 10 | 설치 단위 device ID와 온보딩 상태 보관 |
| supabase_flutter 2 | Supabase Auth 세션 관리 |
| google_sign_in 7 | Google SDK 기반 모바일 인증 |
| sign_in_with_apple 8 / crypto 3 | iOS Apple 인증과 nonce 해시 |

현재 저장소는 FastAPI 백엔드 API와 Flutter 모바일 앱을 함께 관리해요.

주간 대화 추천 v2(2026-11-27)은 conversation 도메인의 언어쌍·주간 슬롯별 발행 묶음과 주제를 사용해요. 운영자가 수동 CLI를 실행해 `ko→en`, `en→ko` 공통 주제와 학습 언어 첫 질문을 생성하고 검사를 통과한 묶음만 저장해요. 명시적 재발행은 같은 주차의 활성 주제 ID를 유지하며 문구와 첫 질문을 함께 교체해요. 생성 실패하면 기존 발행 데이터를 유지하며 cron worker는 아직 없어요. 홈 목록은 주차 제한 없이 해당 언어쌍의 전체 발행 주제에서 보관·첫 질문 누락 항목을 제외하고 최대 8개를 매 요청 무작위 추출해요. week_start는 발행 관리에만 쓰고 목록 응답에서는 null이에요. 홈 진입·탭 복귀·앱 복귀·당겨서 새로고침 때 다시 조회해요. 홈은 대화 수와 관계없이 인증된 목록 API와 계정·언어쌍별 캐시를 사용해요. Flutter는 제목·공통 배경 박스 없이 회색 바탕·검정 글자의 주제 카드를 ‘오늘의 토마토’ 제목과 대화 카드 사이에 보여주고, 탭한 주제는 확인 중 빨간색으로 표시해요. 각 카드는 얕은 곡선을 따라 오른쪽으로 이동하고 손가락 드래그로 좌우 이동한 위치에서 자동 흐름을 이어가며, 축소 동작 설정에서는 정적 목록을 보여줘요. 카드 탭은 주제를 보여주는 확인 팝업을 거치고, 확인 후 API 응답 전까지 ‘대화 시작을 준비하고 있어요’ 로딩 표시로 바꿔 중복 시작을 막아요. 추천 시작 API는 요청 ID를 예약하고 발행 시 저장된 첫 질문 하나가 있는 `FREE_CHAT`을 생성해요. 트랜잭션에서 대화와 첫 AI 메시지를 먼저 DB에 반영한 다음 메시지 FK를 참조하는 예약 기록을 완료해요. 첫 사용자 발화 수는 0이며 기존 슬롯 제한을 적용해요.

---

## 2. 시스템 구조

**아키텍처 패턴**: FastAPI Modular Monolith + Flutter Mobile Client

```text
backend/
├── main.py                  # FastAPI 앱 초기화, 라우터 등록
├── config.py                # Pydantic BaseSettings 환경 설정
├── database.py              # SQLAlchemy 엔진·세션 팩토리
├── shared/                  # 공통 타입, 언어 컨텍스트, prompt policy, 예외, 유틸리티
└── domains/                 # 도메인별 수직 슬라이스
    ├── auth/                # Supabase token 검증, profiles 연결
    ├── conversation/        # 대화 관리
    ├── grammar/             # 문법 체크 및 통계
    ├── llm/                 # LLM 프로바이더 추상화
    ├── search/              # ddgs 검색 + query analysis + LLM source judge + LLM 요약
    ├── voice/               # STT/TTS provider 추상화와 OpenRouter/OpenAI Audio 연동
    └── web/                 # 서버 렌더링 HTML 라우트

mobile/
├── android/                 # Android runner
├── ios/                     # iOS runner
├── lib/
│   ├── main.dart            # ProviderScope 앱 진입점
│   ├── app/                 # 앱, router, theme
│   ├── core/                # config, Dio API, secure token storage, 공통 widget
│   └── features/            # feature-first 화면, 상태, 도메인 widget
│       ├── auth/            # Riverpod 인증 상태, 모바일 auth API
│       ├── conversation/    # 대화 API, 메시지 전송, grammar polling, UI
│       ├── home/            # 최근 대화 API 상태와 Home UI
│       ├── language/        # 언어쌍 모델, preference API, selector UI
│       ├── onboarding/      # 완료 상태와 pending 앱·학습 언어 저장, 5장 onboarding UI
│       ├── roleplay_setup/  # 롤플레이 상황 선택 UI
│       └── topic_prep/      # Topic Input, 검색 준비 카드 API 상태와 UI
├── test/                    # Flutter 테스트
└── pubspec.yaml             # Dart/Flutter 의존성
```

Flutter API 요청은 `ApiClient → AuthTokenInterceptor → TokenRefreshInterceptor → Dio` 순서로 실행돼요. 응답은 공통 envelope parser를 거쳐 feature decoder로 전달해요. Supabase SDK가 access/refresh session을 관리하고, `AuthTokenInterceptor`는 현재 Supabase access token을 `Authorization: Bearer` 헤더로 주입해요. 여러 요청이 동시에 `401`을 받아도 Supabase refresh는 하나만 공유하며, 새 access token으로 각 요청을 한 번만 재시도해요.

Home의 `language_snacks`는 최근 대화와 독립된 학습 콘텐츠 흐름이에요. v2 feed는 profile.target_language와 content_language가 같은 published 카드 12개를 반환해요. 기본은 최신순이며 Home은 `order=random`으로 전체 발행 목록에서 추출해요. Flutter는 학습 언어 변경 시 즉시 다시 조회하고, Home 재진입·앱 복귀 시 마지막 성공 조회가 5분 이상 지났으면 갱신해요. API 실패에는 언어·설명 언어별 secure storage 캐시를 사용하고 캐시·당일 스냅샷이 모두 없으면 해당 영역만 숨겨요. 이전 언어의 지연 응답은 버려요.

토마토 스낵 v2.1(2026-09-19)은 `DailySnackBasketController`가 사용자 ID·학습 언어·기기 로컬 날짜별 12개 스냅샷과 소비 횟수를 저장해요. `SnackTomatoBasket`은 투명 바구니 4단계·토마토 5단계 이미지를 사용해 토마토 3개를 각 4입 먹고 `LanguageSnackContent` 팝업을 열어요. 4·8·12번째 팝업을 닫으면 남은 2·1·0개 바구니로 돌아가며 다음 토마토는 다시 눌러 꺼내요. 복원 시 완료 경계는 바구니, 진행 중이면 먹던 토마토를 표시하며 별도 저장 필드는 추가하지 않아요. 12개 소진 후에는 빈 바구니에서 재시작해도 추가 터치를 막고, `LanguageSnackHomeSection`의 현지 자정 타이머·앱 복귀 검사로 다음 날짜에 재구성해요. 열린 팝업·애니메이션은 종료 후 갱신해요. 발행 목록이 12개 미만이면 중복 ID를 제거한 목록을 한 번씩 순회한 뒤 반복 배치해요. 당일 피드 재조회는 이미 정한 묶음을 바꾸지 않으며 진행은 기기 간 동기화하지 않아요. 기존 5초 자동 슬라이드는 Home에서 제거했어요.

iOS 홈 화면 스낵 위젯 v1(2026-10-27, 2026-11-15 모션 갱신)은 iOS 17 이상 `systemMedium`·`systemLarge` WidgetKit extension이에요. 두 크기는 같은 App Group 스냅샷을 공유하며 크기별 SwiftUI 레이아웃을 사용해요. Flutter의 일일 스냅샷은 MethodChannel을 거쳐 App Group UserDefaults에도 저장하고, 위젯 `AppIntent`가 바구니에서 토마토 꺼내기·한입 소비·본문 페이지 이동을 그 저장소에서 처리해요. 두 크기는 같은 SwiftUI 이미지 레이어를 사용해요. 바구니 터치는 한 번의 상태 갱신으로 토마토를 교차 표시하고, 토마토 터치는 소비 횟수를 저장한 뒤 단일 타임라인 항목으로 스낵 카드를 바로 표시해요. 이동·확대 모션은 사용하지 않아요. 위젯 전용 이미지는 최대 512px로 저장해요. 꺼낼 때는 바구니가 사라지며 토마토 한 개가 나타나고, 토마토 터치에는 흔들림·한입 이미지 미리보기·카드 지연을 사용하지 않아요. 카드 교체에는 페이드·비활성 버튼 흐림을 사용하지 않아요. 스낵 카드가 나타나면 유형별 불투명 배경이 시작 화면의 토마토와 제목을 가려요. 앱 Home 진입·복귀는 위젯 진행을 보안 저장소에 반영하고, 로그아웃은 위젯 스냅샷을 지워요. 앱을 열지 않은 채 날짜가 바뀌면 위젯은 마지막 12개를 새 날짜에 재사용해요. 상세 동작과 검증 범위는 [iOS 스낵 위젯 계약](_contracts/IOS_SNACK_WIDGET.md)에 있어요.

스낵 v2(2026-11-26 여섯 유형 확장)는 여섯 유형의 `payload`와 지식 `identity`를 JSONB로 저장해요. identity는 NFC·공백 정규화, 객체 키·entry 순서 정렬 후 SHA-256을 계산해 UNIQUE로 보호하며 대소문자·sense는 보존해요. LLM은 같은 content_language의 모든 상태·유형 요약 이력을 보고 별도로 의미 중복을 판정해요. reserved를 먼저 저장하고 본문 구조·품질 검증 후 published로 전환하며 재시도 소진이나 운영 취소는 archived로 남겨 재생성하지 않아요. draft는 향후 편집용 상태로 현재 경로에서는 따로 저장하지 않아요.

스낵 유형 확장(2026-11-26): register_contrast·collocation은 비교형 payload, idiomatic_expression은 단일 표현 payload예요. Flutter는 본문 타입별로 저장·렌더링하고 iOS 위젯은 optional items와 유형별 검증·페이지를 사용해요. 기존 identity 해시·카드 ID·캐시 키는 유지해요. generation run의 content_types는 기존 세 유형으로 백필하고 새 run에는 여섯 유형을 저장해 재개 목표가 바뀌지 않게 해요. API schema_version은 1이에요.

주간 CLI는 API 이미지의 별도 작업 컨테이너에서 en/ko run을 순서대로 실행해요. 영속 `run_key`는 주간 슬롯+언어의 재실행을 멱등하게 만들고 예약을 우선 재개해요. scheduled_for 별도 컬럼 대신 run_key의 주간 날짜를 사용해요. metrics에는 후보 rounds, calls, reported_tokens, published_by_type와 발생한 중복·불확실 수/오류 코드가 저장돼요. 후보 라운드·호출 상한은 run에 누적되며 본문 시도 횟수는 예약 metadata에 저장돼요. 추정 토큰과 전체 실행 시간으로 중단하지 않으며 요청별 65초 타임아웃은 유지해요. 기존 metrics의 charged_tokens는 과거 기록으로만 남고 더 이상 증가하거나 제한에 사용되지 않아요. reserved/published/archived 개수로 예약·발행·실패를 추가 집계할 수 있어요.

스낵 LLM 요청은 모든 단계에 strict JSON Schema를 사용해요. 후보는 카테고리별 독립 요청(최대 3개)으로 분리하고 해당 유형의 relation·identity 필드와 언어만 wire schema에 남겨요. 후보에는 모든 유형·상태의 identity만 전달하고 ID·요약은 빼며 최종 중복 검사에는 전체 이력을 유지해요. 프롬프트에서 스키마의 중복 사본은 제거해요. 라운드는 미완료 유형 작업을 최대 6개 병렬 실행하는 단위이며 기존 rounds·calls를 보존해요. 유형별 후보 오류는 해당 작업만 중단하며 다른 유형은 계속해요. 새 후보의 중복 검사·예약은 asyncio 잠금 아래 직렬화하고, 본문·품질 검사는 병렬 실행해요. 동기 DB 세션·metrics 작업은 단일 이벤트 루프에서 await 없이 완료해야 해요. 자원 한도·잠금 실패나 취소는 모든 작업을 취소·회수한 뒤 외부 쓰기 잠금을 해제해요. 요청 시작 전에 calls를 예약하고 진단 호출 번호를 고정해요. 취소된 본문 시도는 예약의 attempts를 되돌려 재개 기회를 보존해요. nullable 필드도 required에 포함하고 default는 제거하며 모든 객체의 추가 필드를 금지해요. OpenRouter는 지원 endpoint를 요구하고 일반 텍스트로 폴백하지 않아요. Pydantic 도메인 검증을 유지하고 응답 finish_reason·거절 여부를 별도로 전달해 실패를 구분해요. run metrics.failures는 원문 없는 최근 20건의 진단만 저장해요.

운영 POST·PATCH와 CLI 쓰기는 같은 PostgreSQL session advisory lock을 획득해 직렬화해요. 전용 direct/session 연결에 잠금을 유지하고 LLM 대기 중 ORM 트랜잭션은 열어두지 않아요. 잠금 연결을 잃으면 추가 저장을 중지해요. SQLite 잠금은 단일 프로세스 개발용이에요. 전체 이력 크기를 넘으면 과거 항목을 생략하지 않고 중단하며 LLM 의미·품질 판정에는 오차가 남아요. API는 구버전 GET에 빈 목록, 구버전 POST에 410을 제공해요. 상세 외부 계약은 [DSL](../docs/DSL.md), 파괴적 migration·cron 설치·롤백은 [운영 가이드](../docs/OPERATIONS.md), 환경변수는 [환경 설정](../docs/ENVIRONMENT.md)이 기준이에요. [README](../README.md)는 실행·CLI 진입점으로 유지해요.

Flutter 앱 시작은 `Splash → Onboarding(최초 1회) → 익명 게스트 Home` 순서예요. 저장된 정식 회원 세션이 있으면 바로 회원 Home을 복원해요. `go_router`가 onboarding 완료 상태와 Riverpod 인증 상태를 함께 관찰하며 세션 복원 중에는 Splash를 유지하고, 온보딩 안내 선택을 저장하는 동안에는 온보딩을 유지해요. 게스트에게도 Home의 스낵·주간 추천·최근 대화를 보여주고 두 번째 탭 이름은 `내 정보`로 유지하지만, 탭하면 Login을 push해 뒤로가기로 Home 상태를 복원해요. Onboarding은 system locale이 `ko`이면 한국어, 그 밖에는 영어 앱 언어를 먼저 제안하고 선택 즉시 `MaterialApp.router.locale`에 반영해요. 이어서 기기 locale로 `ko -> en`, `en -> ko` 학습 언어 기본값을 고르고, 중국어가 포함된 언어쌍은 화면에 표시하되 선택은 막아요. 완료하면 앱 언어와 학습 언어를 secure storage의 pending 값으로 저장하고, `authControllerProvider`가 Supabase 익명 세션을 만들거나 복원한 뒤 두 값을 `POST /api/auth/bootstrap`에 함께 보내 프로필 생성·기본값 적용·최종 응답을 한 요청으로 마친 뒤 안내 선택까지 저장하면 Home을 표시해요. 성공 뒤 pending 값을 지우며, 초기화 전 재시작에는 pending 앱 언어를 복원해요. 이미 온보딩을 마친 profile의 `app_locale`이 null이면 system locale fallback을 유지해요. 내 정보에는 앱 언어 변경 UI를 두지 않고, 회원의 `학습 언어` 설정만 profile default를 갱신해 새 대화부터 적용해요. 온보딩 종료·Skip에서 개인정보처리방침 안내와 AI 처리 선택을 제공하며, AI 사용에는 현재 AI 처리 버전의 동의가 필요해요. 방침 안내 확인은 별도로 기록해요. 게스트는 활성 대화 1개와 계정 누적 사용자 발화 5회를 사용할 수 있고, 한도 뒤에는 기록 열람을 유지한 채 작성기와 새 시작을 Login CTA로 바꿔요. 새 Google·Apple 신원은 익명 사용자에 연결해 ID와 데이터를 유지하고, 기존 신원은 일회용 영수증으로 대화·동의·사용 기록을 회원 계정에 이전해요. Home은 활성 언어쌍과 `/api/conversations/`의 모든 페이지를 조회한 뒤 활성 대화를 우선 정렬하고, 처음에는 5개만 표시하며 `더 보기`로 나머지를 펼쳐요. Free Chat 선택 시 `Topic Input → Topic Prep`으로 이어져 `POST /api/search/topic-prep/`의 ready/low-quality/error 상태를 보여주고, 첫 답변 제출 후 `POST /api/conversations/start/free-chat/stream/`로 Conversation 화면에 진입해요. Topic Input 정적 예시 검색어는 system locale이 아니라 native language로 고르고 그대로 검색 요청에 보내요. Roleplay 선택 시 `Roleplay Setup`에서 target language에 맞는 preset/custom 상황을 고르고 `role_character`로 `POST /api/conversations/start/roleplay/stream/`를 호출해요. `turn_started`에서 요청 ID 기반 임시 대화 화면으로 들어가 첫 인사 델타와 음성을 표시·재생하고, `turn_completed`에서 영속 대화 ID로 화면을 교체해요. Topic Prep과 Roleplay 콘텐츠 선택은 target language를 따르고, retry guidance나 짧은 설명은 feedback language를 따르는 정책을 유지해요. Backend LLM prompt policy도 같은 원칙과 함께 현재 profile의 nullable nickname만 구분된 데이터로 전달해 자연스러운 경우에만 간헐적으로 부르게 해요. 닉네임은 conversation snapshot에 저장하지 않으며 이메일과 OAuth 원본 이름은 prompt에 추가하지 않아요. 이 정책은 STT/TTS나 provider/model routing을 변경하지 않아요. Home 최근 대화 카드도 `/conversation/:conversationId`로 이동해 기존 메시지를 이어가요.

새 대화 선택 시트·준비 화면 제목·최근 대화 유형의 방식 이름은 system locale과 관계없이 `FreeChat`·`Role Playing`으로 표시해요. Roleplay Setup의 프리셋 목록은 target language로 고르되 카드의 회색 상황 설명만 native language로 표시해요. 이는 위의 feedback language 기반 안내 정책과 구분되는 정적 프리셋 설명이에요.

로그인 화면의 브랜드 표시는 Home 헤더와 같은 `logo_img/KakaoTalk_Photo_2026-10-08-22-20-21 002.png` 에셋을 사용해요. 로그인 CTA 아래에는 별도의 관심 주제 예시 카드를 표시하지 않아요.

Splash의 Flutter 화면은 새 Toma Talk 이미지와 그 아래의 `오늘의 토마톡!`을 흰 배경의 중앙보다 위쪽에 함께 배치해요. 제목은 Home의 `오늘의 토마토`와 같은 Freesentation 16px Bold 버튼 서체로 표시해요. 이미지 원본의 넓은 흰 여백은 화면에서 잘라 그림과 제목을 가깝게 배치해요. 이미지와 제목은 진입 시 한 번 0.96배로 줄였다가 650ms 안에 원래 크기로 되돌려요. 인증·onboarding 확인이 먼저 끝나도 모션 완료까지 Splash에 머물러요. 동작 줄이기 설정에서는 모션을 생략하고 즉시 화면 이동을 허용해요. 로딩 문구는 표시하지 않고 인증 또는 onboarding 확인 오류일 때만 하단 재시도 아이콘을 표시해요.

모바일 내비게이션 v2 (2026-09-22, 2026-11-10 갱신)는 `StatefulShellRoute.indexedStack`이 홈(`/home`)·내 정보(`/profile`) 두 탭과 각 스크롤을 유지해요. 홈은 스낵 → 대화 카드 순서이며 처음 5개를 표시하고 `더 보기`로 나머지를 펼쳐요. 새 대화 버튼은 화면 하단에 고정해요. 홈의 `전체 보기` 버튼은 표시하지 않고, 전체 대화(`/history`) 직접 진입 경로는 shell 밖에 유지해요. 전체 대화는 별도 repository/controller가 기존 limit/offset API로 20개씩 조회하는 행 목록이에요. 추가 조회는 중복 요청·ID와 계정 변경 전 지연 응답을 차단해요. 준비·대화 경로도 shell 밖 루트 stack에 push하며, 생성 성공 시 준비 경로만 제거해 출발 화면을 보존해요. 대화에서 pop하면 두 목록을 갱신하고 전체 목록은 읽던 범위까지 재조회해요. 설정 저장은 인증 loading 전환 없이 profile을 갱신해 현재 탭을 유지하고, 로그아웃은 기존 인증 redirect로 shell을 해제해요. 상세 경로 계약은 [모바일 내비게이션 계약](_contracts/MOBILE_NAVIGATION.md)을 따라요.

홈 헤더는 서비스 이름을 왼쪽, 현재 언어 쌍 배지를 오른쪽 끝에 표시해요. 내 정보 진입은 하단 탭으로 통일해요.

내 정보 화면을 아래로 당기면 `GET /api/auth/me`로 현재 프로필의 닉네임·언어쌍을 다시 읽고, 계정 잔액도 다시 조회해요. 프로필 응답의 앱 언어는 전체 앱 chrome의 source of truth로 계속 사용하지만 내 정보에서는 변경 UI를 표시하지 않아요. 프로필 조회는 인증 초기화 요청을 재실행하지 않으며 화면이 짧아도 새로고침 제스처가 동작해요.

대화 권한 v3 (2026-11-25)는 계정별 credit lot·turn reservation·구매 delivery 원장을 사용해요. 회원은 기본 대화창 슬롯 1개·계정 최초 체험 대화권 10회를 받고, 이후 대화창 슬롯 +1/+3개와 대화권 5/10/20회 충전의 다섯 Consumable을 반복 구매해요. 프로필 행 잠금 아래에서 생성·지급·예약·commit·환불·삭제를 직렬화하고 AI 텍스트와 차감을 같은 트랜잭션으로 확정해요. 기존 회원 대화는 잠그지 않아요. StoreKit finish는 서버 terminal 이후에만 수행해요. 삭제 후에는 버전형 HMAC만 남겨 거래 재지급과 이전 JWT 접근을 막아요. 상세 정책·운영·키 교체는 [DSL](../docs/DSL.md), [운영 가이드](../docs/OPERATIONS.md)를 기준으로 해요.

대화 목록의 `slot_active`·잠금은 게스트 정책에만 적용해요. 회원 목록은 저장된 전체 대화를 표시하며 슬롯 초과나 대화권 소진에도 기존 기록을 열람할 수 있어요. 회원 제한 활성화 시 새 대화 생성은 슬롯과 대화권을, 기존 대화의 새 발화는 대화권을 검사해요. Flutter는 구매·답변 terminal·앱 복귀 때 계정 잔액과 대화 권한을 갱신해요. 부족 종류에 따라 상점의 대화창 슬롯 추가 또는 대화권 충전 구역으로 이동해요.

바구니 운영 리셋 v1(2026-09-19)은 `language_snack_basket_resets`에 `(user_id, content_language)`별 최신 UUID·시간만 upsert해요. POST는 운영 키로, GET은 본인 Bearer로 보호해요. 앱은 Home 진입·복귀 때 별도 GET으로 확인하고 일일 스냅샷의 `reset_id`와 다르면 같은 카드 묶음의 소비를 0으로 초기화해요. 요청 중 계정·언어가 바뀌면 응답을 버리고, 팝업·애니메이션 중에는 적용을 미뤄요. 로컬에 ID를 함께 저장해 재실행·자정에도 재적용하지 않으며 네트워크 실패는 기존 진행에 영향을 주지 않아요. 소비 횟수의 기기 간 동기화는 아니에요.

도메인은 기본적으로 아래 계층을 따라요:

```text
domains/{name}/
├── models.py       # SQLAlchemy 모델
├── schemas.py      # Pydantic 요청/응답 스키마
├── enums.py        # Enum 정의
├── repository.py   # 데이터 접근 계층
├── service.py      # 비즈니스 로직
└── router.py       # FastAPI 엔드포인트
```

도메인 특성상 모든 파일이 항상 필요한 것은 아니며, `search`처럼 저장 모델이 없는 도메인은 `service.py`와 `router.py` 중심으로 구성해요.

새 도메인은 `backend/domains/{domain_name}/`에 필요한 모델·스키마·repository·service·router를 추가하고 `backend/main.py`에 라우터를 등록해요. API·설정·실행법의 문서 동기화 대상은 [AGENTS.md §5.8](../AGENTS.md#5-핵심-규칙)을 따라요.

문서 정리(2026-09-13): README의 구조·개발 안내를 이 문서로 통합하고 환경변수·운영 절차를 별도 기준 문서로 연결했어요.

---

## 3. 데이터 플로우

### API 구조화 로그와 음성 지연 진단 v2

`shared/latency.py`의 ASGI middleware는 모든 `/api/` 요청과 `/health`에 요청별 ContextVar를 설정해 최종 body 전송까지 측정해요. 요청마다 JSON stdout 완료 로그 한 건을 내고, 보호 API의 인증 확인과 대화의 auth·STT·LLM·TTS·인코딩 단계를 같은 trace로 연결해요. `shared/logging_config.py`는 허용 필드만 직렬화하고 500 오류의 예외 종류·스택 위치에서 메시지와 지역 변수를 제외해요. nginx는 자체 요청 ID와 upstream 시간을 JSON으로 남기며 Docker가 API·nginx 로그를 회전해요. Flutter의 첫 playing 이벤트 측정은 유지해요. 필드와 측정 절차는 [로그 계약](../docs/OBSERVABILITY.md), 상태 전이와 검증 범위는 [Voice Streaming 계약](_contracts/VOICE_STREAMING.md)을 참조해요.

대화 음성 스트림은 `stream_turns`·`stream_attempts`에 시도·오디오 상태를 기록해요. 주간 추천은 저장된 첫 질문을 합성하고, Free Chat·Roleplay 시작과 기존 대화의 `/turn/stream/`·`/message/stream/`은 LLM 토큰 reader, 문장 분리, 최대 2개씩 제한된 큐와 단일 TTS worker를 사용해요. 확정된 사용자 발화는 생성 전에 저장하고, 완성된 AI 답변만 저장해요. 연결 중 상태 변경은 독립 DB session에서 처리해요. 문장별 MP3는 호스트 bind mount의 staging 디렉터리에 쓰고 완료 후 원자적으로 공개해요. `conversation_audio_cache`는 manifest와 다중 워커 생성 lease를 보관해요. 다시 듣기는 파일 전체를 검사한 뒤 캐시를 재생하고, 누락·손상 시 저장된 텍스트에서 재생성해요. 30일 파일 만료는 운영 cron 작업이 실행하며 대화 삭제 시 파일도 제거해요. 앱은 Dio 증분 decoder·단일 재생 큐로 문장 오디오를 순서대로 재생하고, 완료된 assistant 메시지에 다시 듣기 버튼을 표시해요. 요청별 컨트롤러의 메모리에는 생성 텍스트를 누적하고, 재생 차례의 문장까지만 UI 상태에 공개해 타이핑해요. 첫 글자의 화면 프레임 이후 해당 음성을 재생하고, 앞 문장 재생 중에는 다음 문장을 숨겨요. 완료 이벤트도 대기 문장을 공개하지 않으며 TTS·재생 실패 때는 남은 텍스트를 공개해요. 서버 송출·앱 수신·첫 화면 프레임은 공통 trace ID와 델타 번호로 확인해요. 화면 이탈 때 요청과 큐를 취소해요.

기본 TTS는 OpenRouter의 MAI-Voice-2.1-Flash, 미국 Harper 음성, 0.8배 속도예요. 이 모델의 합성 요청에는 Azure `style=neutral`을 전달해요. 모든 음성 생성 API는 요청별 `tts_accent`(us·au·gb)와 `tts_speed` 쿼리를 받고, 캐시는 모델·음성·속도·스타일을 검사한 뒤 다시 듣기에 재사용해요.

### 인증

개인정보 안내·AI 처리 선택 v2 (2026-11-26)는 온보딩 종료·Skip의 공개 고지 조회 → 사용자 선택 → 게스트 bootstrap → 버전이 명시된 선택 저장 → 온보딩 완료 순서예요. 홈에서는 계정별 첫 진입에 필요한 안내를 확인하고 회원의 필수 닉네임 팝업과 직렬화해요. 처리방침 안내 확인(`privacy_notice`)과 AI 처리 수락(`ai_data_processing`)은 기존 `user_consents` 원장에 별도 종류로 저장해요. AI 접근은 현재 AI 처리 동의로만 판단하고 기존 동의 기록은 보존해요. 배지 UI·권한·읽음 동기화는 포함하지 않아요.

첫 앱 프로필은 `nickname=NULL`로 생성해요. 기존 프로필은 migration에서 현재 `name`을 닉네임으로 이관해 이전 표시 이름을 유지해요. 앱은 초기화 응답의 닉네임이 null이면 Home 위에 필수 입력 팝업을 띄워요. 이때 기기의 우선 시스템 언어가 한국어면 영어, 그 외에는 한국어 임의 닉네임을 입력 칸에 미리 채우며 앱 표시 언어와 학습 언어쌍은 사용하지 않아요. `PUT /api/auth/me/nickname` 저장이 성공해야 팝업을 닫아요. 저장 실패 시 입력을 유지하며 앱 재시작 후에도 다시 표시해요. 내 정보에서 닉네임을 수정할 수 있고, 닉네임은 계정 식별자가 아니므로 중복을 허용해요.

```text
[Flutter 앱] → Google Sign-In SDK로 Google id_token 획득
             → Google access_token 획득
             → Supabase Auth signInWithIdToken(provider=google)
             → Supabase session/access_token 발급

[Flutter iOS 앱] → 요청별 원본 nonce 생성, SHA-256 해시를 Apple에 전달
                 → Apple identityToken과 원본 nonce로 signInWithIdToken(provider=apple)
                 → Supabase session/access_token 발급

[Flutter 앱] → 인증 API에서 401 수신
             → 진행 중인 Supabase refresh가 있으면 같은 결과 대기
             → Supabase SDK refreshSession
             → 새 Supabase access_token으로 Authorization 갱신
             → 원 요청 1회 재시도
             → refresh가 실패하거나 세션이 없으면 unauthenticated 전환

[FastAPI] → Authorization: Bearer <supabase_access_token>
          → auto 모드의 ES256 token은 캐시된 Supabase JWKS 공개 키로 검증
          → 그 외 token 또는 remote 모드는 Supabase Auth /user 검증
          → 로그인 초기화 요청에서 profile 생성·선택적 언어 적용
          → 일반 요청은 ID만 사용하고 언어가 필요한 요청만 profile 조회
          → current_user.id를 ownership boundary로 사용
```

인증이 필요한 API는 `Authorization: Bearer <supabase_access_token>` 헤더를 사용해요. 모바일은 Google native sign-in과 iOS Apple native sign-in을 제공해요.
`auto` 모드는 워커마다 JWKS를 5분 캐시하고 키 ID가 없으면 갱신을 시도해요. 서명·발급자·대상·역할·만료 검증이 실패하면 요청을 거절해요. 로컬 검증은 토큰 유효 기간 중 Supabase 사용자 상태 변경을 즉시 확인하지 못하므로 즉시 폐기 확인이 필요한 운영에서는 `remote` 모드를 사용해요.
일반 Bearer 인증과 SSE 쿼리 토큰 인증은 토큰 검증 후 계정 삭제 상태를 확인해요. 이 동기 DB 조회는 스레드 풀에서 실행해 비동기 인증 경로의 이벤트 루프를 막지 않아요.

관리자 웹은 기존 API 호스트의 `/admin`에서 FastAPI 템플릿과 정적 JS로 제공해요. `ADMIN_ACCESS_CODE` 환경변수의 공유 입장 코드를 확인해 서버 세션을 만들고 관리자 API를 열어요. 관리자 데이터 API는 매 요청 코드 기반 HMAC으로 세션을 조회하며 쓰기 요청은 CSRF 토큰을 검사해요. 세션은 DB에 무작위 토큰의 HMAC과 만료 시각을 저장하고 브라우저에는 HttpOnly 쿠키만 보내요. 코드 변경 후 API를 재시작하면 기존 세션은 조회되지 않아요. 공유 코드를 쓰므로 변경 이력을 개인별 관리자로 구별하지 않아요. 공개 `website/` 정적 사이트와 분리해요.
언어 선호는 profile 기본값(`native_language`, `target_language`, `feedback_language`)으로 저장하고, 기존 값이 없으면 `ko -> en`과 feedback `ko`로 보정해요.
일반 인증 요청은 기존 profile의 필드와 `updated_at`을 변경하지 않아요. 초기화 요청에 pending 언어가 있거나 언어 선호·앱 표시 언어 변경 API를 호출할 때만 해당 설정을 저장해요. `is_active`는 인증 차단 정책에서 제외하고 기존 저장·응답 필드로 유지해요. Supabase의 이름·사진 등 metadata 변경은 현재 자동 동기화하지 않아요.

### 대화

대화 재진입 v1.1 (2026-09-22): Flutter는 기존 시간순 offset API의 첫 응답에서 total_count를 확인하고, 40개 초과 시 마지막 40개를 추가 조회해 최초 화면에 표시해요. ConversationState.oldestOffset으로 이전 구간을 40개씩 조회하며, 실패 시 표시 중인 메시지를 유지해 재시도해요. 이전 구간 로딩과 전송은 동시에 실행하지 않아요. 화면은 reverse 목록·역순 위젯 배열과 진입별 ScrollController(keepScrollOffset: false)로 최신 위치에서 시작하고, 과거 열람·교정 카드 확장 때 강제 이동하지 않아요. 대화 provider의 기존 캐시·음성 상태는 유지하며 재진입 시 다른 기기의 변경을 자동 조회하지는 않아요. 서버 API 계약은 변경하지 않아요.

```text
[사용자] → POST /api/conversations/start/{free-chat|roleplay}/
         → ConversationRouter
         → ConversationService
         → profile language defaults를 conversation language snapshot으로 저장
         → roleplay는 role_character를 저장
         ├── LLMProvider → OpenRouter / Ollama
         ├── GrammarService 백그라운드 문법 체크(snapshot language)
         └── Response { conversation_id, response, message_id, language }

[Flutter 앱] → Topic Prep 첫 답변 또는 Roleplay Setup CTA
             → start conversation API
             → /conversation/{conversation_id}
             → GET /api/conversations/{conversation_id}/messages/?limit=50&offset=0

[Flutter 앱] → Conversation composer 전송
             → POST /api/conversations/{conversation_id}/message/
             → optimistic user bubble + TypingIndicator
             → AI 응답 표시 후 canonical messages refresh

[Flutter 앱] → Conversation composer 텍스트/음성 전송
             → POST /api/conversations/{conversation_id}/turn/
             → text 또는 audio_file 중 하나 전달
             → audio_file이면 VoiceService → OpenRouter/OpenAI STT provider → transcript 생성
             → ConversationService.continue_conversation(transcript 또는 text, conversation language snapshot)
             → include_audio_response=true이면 VoiceService → OpenRouter/OpenAI TTS provider
             → Response { transcript, response, audio?, audio_error? }

[Flutter 앱] → Free Chat 음성 시작
             → POST /api/conversations/start/free-chat/
             → first_message 또는 audio_file 중 하나 전달
             → audio_file이면 transcript를 first_message로 사용
```

### 문법 피드백

```text
[모바일 앱] → GET /api/grammar/message/{message_id}/
           → 현재 사용자 소유 message인지 검증
           → 2초 간격, 최대 30초 polling
           → 피드백이 없거나 접근 불가하면 404를 pending/timeout UX로 처리
           → GrammarFeedback 수신 또는 앱 timeout 처리

[선택적 실시간 경로] → GET /api/conversations/messages/{message_id}/grammar-feedback/stream
                    → SSE로 GrammarFeedback 또는 timeout/error 수신
```

### 검색

```text
[사용자] → POST /api/search/
         → hybrid query analysis
         → ddgs 검색
         → LLM source judge
         → SearchResult { query, enhanced_query, ready, summary?, sources, quality, timestamp }
```

Topic Prep은 검색이 필요한 주제에서 출처 품질 판정을 통과한 결과의 제목·검색 요약을 카드 생성 LLM에 참고 데이터로 전달해요. 검색이 필요 없는 주제는 출처 없이 카드의 완성도와 적합성을 판정해요. 두 경로 모두 카드 요약을 생성하고 대화 시작 시 `search_context`로 전달해요. 앱은 직접 입력하거나 수정한 주제에는 요약을 표시하고, Freechat 추천 주제를 그대로 선택한 경우에는 준비 중과 완료 후 요약 UI를 숨겨요.

### 웹 페이지

```text
[브라우저] → GET /, /conversations, /grammar/stats 등
           → WebRouter
           → Jinja2Templates로 HTML 응답
```

---

## 4. 외부 의존성

### 외부 HTTP 연결 풀 v1 — 구현 결정 (2026-09-13)

FastAPI lifespan에서 워커의 이벤트 루프별 AI용·Supabase 인증용 `httpx.AsyncClient`를 각각 만들고 dependency → service → provider로 명시적으로 전달해요. provider는 빌린 client를 닫지 않아요. 스낵 CLI도 자신의 이벤트 루프에서 같은 생성 함수를 사용해 실행 전체에 하나의 AI client를 소유해요. HTTP client 생성 시에는 실제 API를 호출하지 않아요.

초기 한도는 풀마다 최대 연결 100개·유휴 연결 20개·유휴 만료 30초이며 환경변수로 조절해요. OpenRouter LLM 30초, Ollama 60초, 음성·인증의 기존 timeout은 요청별로 유지해요. HTTP/2·자동 재시도·provider 변경은 추가하지 않아요. 요청별 인증 헤더를 사용하고 upstream 쿠키 저장을 차단해 사용자 상태가 공유되지 않도록 해요.

백그라운드 문법 task는 워커별 registry가 추적해요. 종료 시 최대 5초(설정 가능) 동안 기다린 뒤 남은 task를 cancel하고 await한 후 HTTP client를 닫아요. 문법 저장에는 요청용 DB session 대신 task가 소유한 별도 session을 사용해요. 종료 중 취소된 문법 피드백은 저장되지 않을 수 있으며 재시작 후 자동 재개하는 작업 큐는 이번 범위에 포함하지 않아요.

검증은 실제 localhost HTTP/1.1 연결 재사용, 동시 요청·인증 헤더/쿠키 분리, timeout·오류 유지, 종료 순서, CLI와 provider 주입 경로를 포함해요. 외부 유료 API 호출과 운영 배포는 수행하지 않아요.

| 서비스 | 용도 | 실패 시 |
|--------|------|---------|
| OpenRouter API | LLM 대화 생성 | 502 계열 외부 API 오류 |
| Ollama | 로컬 LLM 대안 | 502 계열 외부 API 오류 |
| OpenRouter Audio API | 기본 STT/TTS 음성 대화 입출력 | STT 실패 시 대화 저장 전 오류, TTS 실패 시 `audio_error` |
| OpenAI Audio API | OpenAI direct STT/TTS fallback | STT 실패 시 대화 저장 전 오류, TTS 실패 시 `audio_error` |
| DuckDuckGo(ddgs) | 검색 자료 수집 | 검색 실패 오류 |
| Supabase Auth | Google·Apple 로그인, 세션 refresh, token 검증 | 인증 오류 |
| Google Sign-In | 모바일 native Google 계정 선택 | 인증 오류 |
| Sign in with Apple | iOS native Apple 계정 선택 | 인증 오류 |

---

## 5. 보안 경계

- API 키와 서버 전용 secret은 환경변수로만 관리해요.
- 클라이언트에는 OpenRouter, OpenAI, Supabase service role key를 노출하지 않아요.
- Flutter 앱은 Google `id_token`·`access_token` 또는 iOS Apple `identityToken`·원본 nonce로 Supabase 세션을 만들고, FastAPI에는 Supabase access token만 전달해요.
- Supabase가 refresh token 저장과 rotate를 관리해요.
- 대화와 메시지는 `user_id`로 소유자를 분리해요.
- 모바일 앱은 백엔드 API와 HTTPS로 통신하는 별도 클라이언트로 취급해요.
- refresh 네트워크·5xx 실패는 세션 만료로 즉시 단정하지 않고 Supabase 세션 복구를 우선해요.


### iOS 미확인 답변 배지 v1 (2026-11-26)

서버는 메시지별 `read_at`과 소유자 조건의 존재 조회를 제공해요. Flutter의 `BadgeSyncController`는 읽음 API·존재값 조회·native 쓰기를 단일 경로로 조정하며 계정 유형·동기화 세대로 지연 응답을 버려요. 읽음과 배지 요청은 대화 응답 표시·재생·전송을 기다리게 하지 않아요. 회원별 기기 선택과 iOS 16 이상 배지 권한이 모두 있어야 1을 설정해요. 전경 UI의 전체 답변 공개, 중단된 요청만 복구, 회원 전용 권한과 검증 상태는 [배지 계약](_contracts/IOS_UNREAD_BADGE.md)을 참조해요.

### 대화 억양 v1 (2026-11-28)

`conversations.tts_accent`는 미국 기본값을 갖는 대화 설정이에요. 스트림 시작 입력에도 보존해 대화 생성 전 Roleplay 실패를 재시도할 수 있어요. TTS는 명시적 요청 쿼리 또는 대화에 저장된 억양으로 음성을 선택해요. Flutter는 영어 학습의 Topic Prep·Roleplay Setup·추천 확인창에서 공통 `AccentSelector`와 번들 국기 이미지를 사용해요.
