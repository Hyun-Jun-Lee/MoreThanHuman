# CHANGELOG — 완료된 작업 기록

## 2026-08-28

- **프로필 앱 표시 언어·대화 완전 삭제 구현 계획 작성**: profile 기반 `ko`/`en` locale override, 기존 system fallback, 대화·메시지·문법 피드백의 복구 없는 삭제 UI와 검증 범위를 정리
- **Topic Prep 입력 언어·직접 주제 구현 계획 작성**: 설명 언어 resolver, 세 추천 방향, custom focus 질문 생성·대화 handoff, 한국어·영어 copy와 검증 범위를 정리
- **Topic Prep 계획 구현 결정 확정**: `interview_qa` 제거, custom focus 질문 3개, 주제와 무관한 focus의 recovery 정책을 확정
- **Topic Prep 방향 재생성 범위 추가**: 준비 완료된 주제에서 summary·출처를 유지하며 추천 대화 방향 세 개와 첫 질문을 새로 만드는 흐름을 계획에 포함
- **Topic Prep CTA 언어 정책 확정**: custom focus 제출과 추천 방향 재생성 버튼은 한국어 화면에서도 영어 CTA로 고정
- **시스템 locale UI copy 구현 계획 작성**: 공통 `AppCopy`, 오류 reason, 모국어 기준 예시 검색어, 학습 콘텐츠 경계, 레거시 `zh` 호환과 검증 범위를 구현 단위로 정리
- **모바일 온보딩·로그인 copy 조정**: 온보딩 3/4페이지 문구와 로그인 화면 한국어·영어 locale copy를 정렬
- **시스템 locale UI copy 구현**: `AppCopy` 공통 계층으로 앱 chrome·접근성·클라이언트 오류를 한국어/영어로 분기하고, native language 기반 Topic Input 예시 검색어와 관련 테스트·문서를 추가
- **OpenRouter STT 실패 진단 로그 보강**: 전사 HTTP 오류에 모델·파일 메타데이터·응답 본문 일부·요청 추적 ID를 안전하게 기록하고 단위 테스트를 추가
- **Topic Prep·프로필 언어·대화 삭제 구현**: 입력 언어 우선 요약/방향 설명, 세 방향 재생성·직접 focus 질문 및 handoff, profile `ko`/`en` 앱 언어 override, 대화 완전 삭제 UI·API 계약을 구현하고 문서와 검증을 정렬

## 2026-08-27

- **검색 최신성 날짜 힌트 정리**: recency 쿼리의 날짜 보강을 언어 중립 ISO 월 힌트로 통일하고 중국어 최신성 토큰 인식을 보강

## 2026-08-26

- **모바일 온보딩 언어쌍/locale copy 정리**: 중국어 포함 언어쌍을 선택 불가로 표시하고 온보딩 문구를 한국어 시스템 locale이면 한국어, 그 외에는 영어로 표시

## 2026-08-14

- **Home 최근 대화 갱신 indicator 추가**: 새 대화 생성 후 최근 목록을 재조회하는 동안 기존 목록을 유지하고 `Recent` 헤더에 작은 loading indicator를 표시
- **대화 생성 후 Home 최근 목록 갱신**: free chat/roleplay 생성 성공 시 최근 대화 provider를 invalidate해 Home 복귀 직후 새 대화가 보이도록 수정
- **Roleplay 난이도 분리 구현**: `role_character`와 `roleplay_difficulty`를 별도 저장/전송하도록 백엔드 schema·migration·prompt, 모바일 payload, 문서/테스트를 동기화
- **Home/Profile UI 피드백 반영**: Home 대화 추가 버튼을 중앙 하단으로 이동하고 최근 대화 4개 접기/펼치기 및 Profile sheet `CANCEL` 제거를 적용
- **Swagger 테스트용 Supabase 토큰 helper 추가**: `/api/auth/swagger/token`에서 Supabase password grant 기반 access token을 발급하고 dev 외 환경은 enable+secret으로 보호
- **Home 대화 추가 CTA와 언어쌍 약식 표기**: 모바일 Home 화면에 시작 시트로 연결되는 + 버튼을 추가하고 상단 언어쌍 badge를 `KR -> EN` 형식으로 축약
- **Search quality judge JSON 안정화**: 품질 판정 LLM 출력 schema에서 source별 reject 사유 요구를 제거하고 기본 token budget을 1000으로 상향
- **짧은 음성 녹음 차단과 STT 진단 로그**: 모바일 음성 녹음이 700ms 미만이면 업로드하지 않고 안내를 표시하며 STT 업로드/빈 transcript 로그를 추가

## 2026-08-06

- **AI 응답 음성 자동재생 구현**: 모바일 Conversation 화면에서 AI TTS 응답을 자동 재생하고 replay 버튼을 제공하며, free chat/roleplay 시작 응답까지 `include_audio_response=true`로 연결
- **OpenRouter 음성 provider 전환**: STT/TTS 기본 provider를 OpenRouter로 전환하고 Microsoft MAI-Voice-2-Flash TTS, OpenRouter STT/TTS 테스트와 문서를 동기화

## 2026-07-23

- **프리미엄 구독 BM 전략 문서화**: `STRATEGY.md`에 무료 Topic Prep 2회, 대화 5 user turns, 무료 체험 중 STT/TTS 제공, Premium 구독 가치 축을 추가

## 2026-07-21

- **U1-U4 diff HTML 설명서 작성**: 모바일 copy, 콘텐츠 튜닝, prompt policy, 언어쌍 변경 정책 UX를 각각 self-contained HTML로 설명
- **U5 모델 라우팅 설계 계획 작성**: Gemini/Qwen/DeepSeek 후보 평가, task별 routing 기준, fallback 정책을 문서화하는 implementation-ready 계획 추가
- **U4 언어쌍 변경 정책 UX 구현**: Account sheet에 새 대화 적용·기존 대화 snapshot 유지 안내를 추가하고 profile refresh/문서/테스트를 정렬
- **U4 언어쌍 변경 정책 UX 계획 작성**: 계정 설정의 언어쌍 변경이 새 대화에만 적용되고 기존 대화는 snapshot을 유지한다는 UX·문서 구현 계획 추가
- **U3 언어쌍 prompt policy 구현**: target-language prompt policy helper를 추가하고 conversation/roleplay/grammar/Topic Prep prompt에 언어별 연습·교정 기준을 적용
- **U3 언어쌍 prompt policy 계획 작성**: conversation, roleplay, grammar, Topic Prep prompt의 target-language 학습 정책을 정렬하는 backend 구현 계획 추가
- **U2 언어쌍 콘텐츠 튜닝 구현**: target language 기반 roleplay preset/custom/difficulty copy, backend roleplay examples, Topic Prep retry/example fallback과 문서/테스트를 정렬
- **U2 언어쌍 콘텐츠 튜닝 계획 작성**: roleplay preset/difficulty/custom prompt, backend roleplay scenario examples, Topic Prep low-quality examples를 target language 기준으로 조정하는 구현 계획 추가
- **U1 모바일 언어쌍 copy 구현**: 언어쌍 helper copy, Topic Prep language 파싱, target-language 첫 답변 힌트, localized fallback, 온보딩/Topic Input 문구와 모바일 문서를 정리
- **U1 모바일 언어쌍 copy 계획 작성**: 상위 후속 계획의 U1을 온보딩, Topic Prep, Home/start sheet, selector, 모바일 문서 중심의 구현 단위로 분리
- **언어쌍 후속 경험 개선 계획 작성**: STT/TTS와 테스트 확대를 제외하고 UX copy, 콘텐츠 프리셋, 프롬프트 품질, 설정 변경 정책, 모델 라우팅 설계 후속 작업을 계획으로 정리

## 2026-07-20

- **언어쌍 일급 도메인 리팩터 계획 작성**: 프로필 기본값, 대화 스냅샷, 프롬프트, 문법 피드백, Topic Prep, 모바일 온보딩과 검증 범위를 구현 계획으로 정리
- **언어쌍 리팩터 사용자 결정 반영**: 4개 초기 언어쌍 고정, 중국어 UX 최소범위 채택, 모델 라우팅 후속화, 기존 DB 데이터 보존 제외 결정을 계획에 반영
- **언어쌍 일급 도메인 리팩터 구현**: 프로필 언어 선호, conversation snapshot, 언어-aware prompt/grammar/search, 모바일 온보딩·설정 UX와 문서/테스트를 동기화

## 2026-07-18

- **Alembic env.py 연결**: Alembic migration이 기존 SQLAlchemy `Base.metadata`와 `DATABASE_URL`을 사용하도록 설정
- **Supabase Auth 전환 계획 작성**: FastAPI JWT에서 Supabase Auth 세션으로 전환하는 모바일/백엔드/스키마 구현 계획 추가
- **Supabase Auth 전환 구현**: 백엔드 Supabase access token 검증, profiles 스키마, Flutter Supabase Google 로그인·session refresh 흐름과 문서/테스트를 동기화

## 2026-05-20

- **AI Native 마이그레이션**: EstreGenesis v1.6.0 기반 `.agent/` 스캐폴딩 + `AGENTS.md` SSoT 생성 (Migration A)

## 2026-05-25

- **문서 최신화**: 백엔드 API + 향후 Flutter 모바일 앱 기준으로 `AGENTS.md`, 아키텍처, README, DSL, 피드백 문서 정리

## 2026-05-26

- **Refresh token 계약 확정**: `README.md`, `docs/DSL.md`에 refresh token + `device_id`(installation ID) 기반 인증 계약 반영
- **Refresh token 구현(초안)**: refresh token 발급/rotate, `device_id` 기반 1세션 정책, Google OAuth `state`에 `device_id` 전달
- **문서 정리 원칙 확정**: `README.md`/`docs/DSL.md`/`.agent/architecture.md`를 핵심 축으로 유지하고 임시 plan/feedback 문서를 제거
- **Pagination 메타 도입**: conversation/message 목록 API를 `results/pagination` 응답 구조와 정확 count 메타로 확장

## 2026-05-27

- **제품 전략 작성**: Convia의 핵심 문제, 접근, 사용자, 지표, 작업 트랙을 `STRATEGY.md`에 정리
- **주제 준비 카드 기획**: 대화 전 주제 준비 카드 요구사항을 `docs/brainstorms/2026-05-27-topic-prep-card-requirements.md`에 정리
- **주제 준비 카드 구현 계획**: 검색 품질 gate, 준비 카드 API, 대화 handoff, 모바일 연동 계약 구현 계획을 `docs/plans/2026-05-27-001-feat-topic-prep-card-plan.md`에 정리

## 2026-05-28

- **주제 준비 카드 계획 조정**: 웹 UI 범위를 제외하고 백엔드 API + Flutter 모바일 연동 계약 중심으로 구현 계획 수정
- **주제 준비 카드 백엔드 구현**: 검색 품질 gate, 준비 카드 API, 자유 대화 handoff, 모바일 계약 문서, pytest 커버리지 추가

## 2026-06-03

- **Swagger 개발 토큰 API 추가**: `ENV=dev`에서만 동작하는 `/api/auth/dev/token`과 문서/테스트 추가
- **검색 품질 파이프라인 구현 계획**: `ddgs` 전환, 검색 쿼리 보강, relevance score, LLM 품질 판단 조합 계획 작성
- **검색 품질 계획 보정**: rule 기반 핵심어 추출, 날짜 주입 정책, 모바일-first API 계약 전제를 계획에 반영
- **LLM output invariant learning 문서화**: `docs/solutions/`와 `CONCEPTS.md`에 topic prep ready 검증 패턴 기록

## 2026-06-04

- **검색 품질 계획 보정**: 검색 품질 파이프라인 계획에 hybrid query analysis, LLM query analyzer fallback, 날짜 주입 정책을 반영
- **검색 품질 파이프라인 구현**: ddgs adapter, hybrid query analysis, relevance filter, LLM quality judge, API 계약/테스트 반영
- **검색 LLM 진단 로그 추가**: query analysis, quality judge, summarization 단계별 로그와 fallback stack trace를 추가
- **OpenRouter 기본 provider 통일**: `.env`, `.env.example`, 설정 기본값, 환경변수 문서를 OpenRouter 우선으로 정리

## 2026-06-05

- **LLM source judge 리팩터링 계획**: deterministic relevance score 중심 필터를 LLM source selection 중심으로 바꾸는 후속 구현 계획 작성
- **LLM source judge 리팩터링 구현**: deterministic relevance score를 최종 판단에서 제거하고 LLM accepted sources 기반 검색 품질 판정으로 전환
- **LLM source judge 응답 보정**: 숫자 rating과 rejected source id 배열을 parser에서 정규화하고 curl 재검증으로 `ready=true` 확인
- **모바일 인증/피드백 결정 문서화**: Flutter Google SDK 기반 OAuth와 문법 피드백 polling 우선 결정을 README, DSL, UX, architecture 문서에 반영
- **문법 피드백 polling 계획 작성**: 기존 grammar feedback 조회 endpoint를 모바일 polling 계약으로 공식화하는 구현 계획 추가

## 2026-06-07

- **Google 모바일 로그인 API 구현**: Flutter Google SDK `id_token` 검증용 `/api/auth/google/mobile`과 테스트/문서 계약 추가
- **문법 피드백 polling 계약 구현**: `/api/grammar/message/{message_id}/`를 모바일 polling primary path로 공식화하고 message ownership 검증/문서/테스트 추가

## 2026-06-11

- **모바일 UX flow/wireframe 문서 작성**: Flutter v1 화면 목록, 사용자 흐름, API 연결 지점을 `docs/mobile-flow-spec.md`에 정리

## 2026-06-20

- **모바일 chat/grammar 디자인 레퍼런스 정리**: 생성 이미지를 `docs/design/references/`에 저장하고 Google Stitch용 프롬프트 문서를 추가
- **Convia 컬러 팔레트 대안 정리**: Stitch 디자인 시스템의 Sage 계열을 대체할 녹색 제외 컬러 조합 3가지를 이미지로 정리
- **Stitch 화면 생성 TODO 작성**: Flutter v1 화면을 Stitch로 다시 생성하기 위한 체크리스트 문서를 추가
- **Stitch 온보딩 프롬프트 작성**: Warm Terracotta & Sand 기준의 온보딩 3장 생성 프롬프트를 추가
- **Stitch login/home 프롬프트 작성**: Warm Terracotta & Sand 기준의 Login, Home, Home Empty 생성 프롬프트를 추가
- **Stitch 남은 화면 프롬프트 작성**: Start/Topic, Roleplay, Conversation State, Utility 화면 생성 프롬프트를 추가

## 2026-06-21

- **Stitch 디자인 산출물 정리 사전 점검**: `docs/design/stitch_design/` 파일 구조와 계획 화면명 매핑 후보를 확인
- **Stitch 디자인 산출물 이름 정리**: 화면 폴더와 HTML/PNG 파일명을 계획 화면명 기준으로 변경하고 산출물 README를 추가
- **Stitch 화면 산출물 누락 점검**: `start_conversation_sheet` 포함 모든 계획 화면의 PNG/HTML 산출물 존재를 확인하고 TODO를 최신화
- **모바일 wireframe 문서 필요성 점검**: Stitch 산출물 이후에도 UX flow/API 연결 기준 문서로 유지 가치가 있음을 확인

## 2026-06-22

- **Curitalk Flutter 프로젝트 초기화**: `dev/mobile` 브랜치에서 `mobile/` iOS·Android 프로젝트와 application ID `com.morethanhuman.curitalk`을 생성하고 문서를 동기화
- **Curitalk Flutter 기반 의존성 추가**: Riverpod, go_router, Dio, secure storage, Google Sign-In을 추가하고 Android minSdk 23 및 문서를 동기화
- **Curitalk Flutter 최소 구조 생성**: ProviderScope 앱 진입점, go_router 앱 골격, theme/core 위치, 기본 widget test를 추가
- **Curitalk 디자인 시스템 재정의**: Figma 편집형 원칙과 Stitch 화면을 대조해 monochrome core, pastel block, typography, 모바일 컴포넌트 및 Flutter 적용 기준을 정규화
- **Curitalk Flutter 기본 토큰 구현**: palette, typography, spacing, radius, border, size token과 번들 font, 단위 테스트를 추가
- **Curitalk Flutter 의미 토큰 구현**: Material 3 ColorScheme과 대화·문법·검색 상태 ThemeExtension을 정의하고 앱 light theme에 연결
- **Curitalk Flutter 컴포넌트 토큰 구현**: 버튼·입력창·Chip·카드·Bottom sheet·Bottom navigation theme과 상태별 테스트를 추가

## 2026-06-23

- **Curitalk Flutter 1차 공통 컴포넌트 구현**: 페이지 골격, 핵심 CTA, 컬러 블록, 비동기 상태, modal sheet, page indicator, 주 내비게이션 공통 위젯과 테스트 추가
- **Curitalk Flutter 2차 도메인 컴포넌트 구현**: 선택 UI, 최근 대화 카드, 역할별 chat bubble, 인라인 문법 피드백, Reduce Motion 대응 typing indicator와 테스트 추가
- **Curitalk Flutter 3차 입력·상태 컴포넌트 구현**: 기본 입력창, 검색 출처·재시도 UI, 빈 메시지 차단 chat composer, 자연스러운 문장 badge와 테스트 추가
- **Flutter API·secure storage 기반 구현**: Dio 공통 envelope parser와 오류 매핑, Bearer interceptor, token pair·installation ID 보안 저장, Riverpod provider와 테스트 추가
- **Flutter 인증 상태·token refresh 구현**: Riverpod 세션 복원·Google token 로그인·로그아웃과 단일화 refresh, rotate 저장, stale session 경쟁 방지 및 테스트 추가
- **Flutter 앱 시작 흐름 구현**: Stitch 기반 Splash·3장 Onboarding·Google Login·Home 화면과 go_router 인증 redirect, 최근 대화 API 상태 및 flow 테스트 추가
- **Flutter Topic Prep 구현 계획 작성**: Home Free Chat에서 Topic Input·Topic Prep까지 연결하는 모바일 구현 범위, 2자 validation, source link defer, ready/low-quality 상태와 테스트 계획 정리
- **Flutter Topic Prep 화면 구현**: Home Free Chat에서 Topic Input과 Topic Prep API 상태를 연결하고, 2자 validation, 준비 카드 ready/low-quality/error UI, 방향·첫 질문 선택과 테스트 추가
- **Flutter Roleplay Setup 구현 계획 작성**: Home Roleplay에서 상황·난이도 선택 화면까지 연결하는 모바일 구현 범위와 테스트 계획 정리
- **Flutter Roleplay Setup 화면 구현**: Home Roleplay route, preset/custom 상황 선택, 난이도 선택, role_character 합성 helper와 테스트 추가
- **Flutter Conversation 구현 계획 작성**: Free Chat·Roleplay 시작, 메시지 화면, 전송, grammar polling, 최근 대화 진입 범위와 테스트 계획 정리
- **Flutter Conversation 화면 구현**: Free Chat·Roleplay 시작 API, 최근 대화 route, 메시지 전송·refresh, grammar feedback polling, Conversation UI와 테스트 추가

## 2026-07-11

- **Flutter 수동 QA 피드백 반영**: Conversation 뒤로가기, AI 응답 표시 formatter, Roleplay 난이도 상단 한 줄 배치, custom roleplay 상대역 prompt 합성을 개선
- **Flutter 문법 피드백 표시 개선**: GrammarFeedbackCard의 교정 문장과 설명에도 표시 formatter를 적용해 붙어 있는 문장을 읽기 좋게 보정
- **Flutter 메인 네비게이션 구현 계획 작성**: 햄버거 제거, account sheet/logout, Chat/Profile/History 탭 동작, History 화면 구현 계획을 추가
- **Flutter 메인 네비게이션 구현**: 햄버거 제거, account sheet/logout, Chat/Profile 탭 sheet 연결, History route/screen과 테스트를 추가

## 2026-07-17

- **Flutter UI 피드백 반영 계획 작성**: Pretendard+Newsreader 폰트 조합, 문단-aware 텍스트, 문법 피드백 접기/강조, 대화 타입 뱃지 제거 계획을 추가
- **Flutter UI 피드백 반영 구현**: Pretendard+Newsreader 폰트 asset, 문단-aware 채팅 텍스트, 접기 가능한 문법 피드백, 대화 타입 뱃지 제거를 적용
- **멀티모달 대화 API 구현**: free-chat 음성 시작과 conversation turn 텍스트/음성 입력, OpenAI STT/TTS provider, 문서/테스트를 추가
- **Flutter 멀티모달 turn 연동 계획 작성**: 모바일 텍스트 `/turn/` migration, multipart audio turn, transcript reconciliation, optional TTS playback 계획을 추가
- **Flutter 멀티모달 turn 연동 구현**: Conversation composer를 `/turn/` 텍스트·음성 입력으로 전환하고 녹음 업로드, transcript 표시, optional TTS 재생을 연결
- **Flutter 음성 녹음·재생 UX 계획 작성**: 녹음 상태, 취소·권한 실패, 임시 파일 정리, assistant audio playback 상태 강화 계획을 추가
- **Flutter 음성 녹음·재생 UX 구현**: 녹음 타이머·취소·권한/빈 녹음 오류, 임시 파일 정리, assistant audio playback 상태와 중복 재생 방지를 적용
