# CHANGELOG — 완료된 작업 기록

- 2026-10-23: Codex — `customer-research` 스킬로 한국 영어학습자와 영어 설명이 가능한 한국어학습자의 공개 발언을 조사해 JTBD·불편·대안·전환 계기·인터뷰 질문을 `CUSTOMER_RESEARCH.md`에 기록했어요. 개별 관찰과 tomatalk 가설을 구분하고 PM 인덱스·마케팅 전략 링크를 동기화했어요.

- 2026-10-23: Codex — 현재 앱의 추천·직접 입력·롤플레이와 영어·한국어 학습 범위에 맞춰 `STRATEGY.md`를 갱신하고, 마케팅 전략 v0.1을 삭제한 뒤 고객 조사·포지셔닝·90일 실험·계측 계획의 v1.0으로 다시 작성했어요. PM 인덱스를 동기화했어요.

- 2026-10-23: Codex — Topic Prep 카드 생성 LLM에 검색 출처와 확장 검색어를 전달하지 않도록 바꾸고, 출처 평가 지시를 주제·카드 완성도 평가로 교체했어요. 검색과 출처 품질 판정 단계 및 응답의 출처 필드는 유지해요. 검색 도메인 테스트 53개가 통과했어요.

- 2026-10-23: Codex — Topic Prep 검색어 규칙에서 종목과 무관한 KBO 확장, 누락된 `요즘` 최신성, 과거 날짜에 붙는 현재 월 힌트, 영어·중국어 검색어에 붙는 한국어 여행 힌트를 수정했어요. 검색어의 결과·일정·뉴스 의도를 보존하면서 품질 판정용 필수 문구는 핵심 주제로 유지했고 검색 도메인 테스트 52개가 통과했어요.

- 2026-10-20: Codex — `SEARCH_BACKEND=google`과 동일한 조건으로 서울 로컬에서 웹 검색 10회를 재측정했어요. 지연 중앙값은 0.267초였지만 10회 모두 HTTP 200 응답에서 검색 결과 XPath 일치 항목 0개로 끝나 실제 검색 성공은 0/10회였어요. 서비스 설정은 변경하지 않았어요.

- 2026-10-20: Codex — 10월 19일 ddgs 검색 비교의 Bing 해석을 정정했어요. 설치된 ddgs 9.14.3은 Bing 단독 엔진을 비활성화했고 `backend=bing`을 조용히 `auto`로 대체해요. 따라서 성공한 두 그룹은 모두 `auto` 호출이었어요. DuckDuckGo는 HTTP 202, Brave는 429, Google은 HTTP 200이지만 파서 일치 항목 0개였어요. 실제 Yahoo 단독 검색은 10회 중 6회 성공, 성공 중앙값 1.29초였고 나머지는 결과 없음 오류였어요. 검색 설정은 변경하지 않았어요.

- 2026-10-19: Codex — 서울 로컬 환경에서 ddgs `auto`·DuckDuckGo·Brave·Bing 지정·Google을 동일한 두 주제와 6개 결과 상한으로 각 10회 호출했어요. `auto`와 Bing 지정 그룹은 모두 10/10회 성공했고 중앙값은 각각 3.21초·3.39초였지만 Bing 지정은 실제 `auto` 폴백이었어요. 나머지 세 엔진은 모두 결과 없음 오류였어요. 품질 판정 후 카드에 필요한 출처 3개 이상은 일반 주제에서 두 그룹 모두 5/5회, 최신 뉴스 주제에서 두 그룹 모두 1/5회였어요. 검색 설정은 변경하지 않았어요.

- 2026-10-19: Codex — 동일한 검색 출처 6개로 Topic Prep 카드 모델 Preview·GA를 각 10회 호출해 비교했어요. 두 모델 모두 카드 10/10개와 질문 9개를 완성했고 중앙값은 Preview 2.74초, GA 3.03초였어요. 카드 간 동일 질문은 각각 8개, 14개였으며 GA에서 11.98초 지연이 1회 발생했어요. 카드 모델 설정은 변경하지 않았어요.

- 2026-10-19: Codex — 검색 출처 품질 판정만 OpenRouter `google/gemini-3.1-flash-lite` 모델을 사용하도록 `SEARCH_QUALITY_JUDGE_MODEL`을 추가했어요. 검색 테스트 44개가 통과했고 임시 8011 서버에서 Topic Prep 3회 측정 시 판정 단계는 1.70~2.20초, 전체 응답은 9.85~17.32초였어요. 1회는 `ready=false`였어요.

- 2026-10-19: Codex — ddgs 검색의 로드·클라이언트 생성·검색 호출·결과 정규화 시간을 요청 ID별로 기록하고 결과 상한을 12개에서 6개로 줄였어요. 검색어와 출처 본문은 로그에서 제외하며 검색·로그 테스트 45개가 통과했어요.

- 2026-10-19: Codex — 메시지 목록의 소유권 조건을 개수·페이지 SQL에 결합해 별도 소유권 조회를 제거했어요. 빈 대화와 접근 불가 대화의 응답을 유지하고 관련 테스트 46개가 통과했어요. Topic Prep 로컬 재측정 1회는 15.31초였으며 단계별 로그를 확인했어요.

- 2026-10-19: Codex — Topic Prep의 전체·검색어 분석·웹 검색·출처 판정·카드 생성 시간을 요청 ID별 구조화 로그로 남겨요. 실패 단계도 기록하며 검색어·응답 본문은 제외해요. 관련 검색 테스트 30개가 통과했어요.

- 2026-10-19: Codex — 로컬 개발 계정으로 홈·주제 준비·대화 스트림·기존 대화 진입 API의 지연을 측정하는 CLI를 추가했어요. 요청 ID별 중앙값·p95와 스트림 첫 텍스트·오디오 시간을 보고하며 쓰기·외부 호출은 명시적 옵션으로 보호해요. 모의 HTTP 테스트 14개가 통과했어요.

- 2026-10-16: Codex — 추가 대화 잠금 팝업의 iOS 구독 버튼을 `SUBSCRIPT`로 바꾸고, 슬롯 해제 안내의 오래된 History 표기를 현재 대화 목록 `Conversations`로 교체했어요. 한국어 안내도 대화 목록으로 맞췄고 관련 Flutter 테스트 33개와 정적 분석이 통과했어요.

- 2026-10-16: Codex — iOS 구독 화면의 이용약관·개인정보처리방침 링크를 로그아웃과 같은 Freesentation 12px Medium 회색 텍스트 버튼으로 통일하고 월간 자동 갱신 안내 문단을 제거했어요. Flutter 정적 분석과 관련 테스트 47개가 통과했어요.

- 2026-10-16: Codex — 앱 언어·학습 언어 변경 확인 팝업의 영문 확인 버튼을 `CHANGE`로 표시했어요. 관련 Flutter 테스트 35개와 정적 분석을 통과했어요.

- 2026-10-16: Codex — 영어 내 정보 화면의 구독 상세 칩을 `Show more`, 앱 언어 칩을 `Korean`·`English`로 표시해 첫 글자만 대문자로 맞췄어요. 다른 선택 칩의 대문자 표시는 유지하며 관련 Flutter 테스트 38개와 정적 분석을 통과했어요.

- 2026-10-16: Codex — 내 정보의 플랜 칩을 `Free`·`Advance`·`Plus`처럼 첫 글자만 대문자로 표시하고 계정 제목·이메일을 제거했어요. 사용자 이름을 프로필 원 높이 이내의 20px Bold 한 줄로 제한했어요. 앱·프로필 위젯 테스트 34개와 Flutter 정적 분석을 통과했어요.

- 2026-10-16: Codex — 내 정보의 로그아웃을 배경 없는 옅은 회색 `로그 아웃` 텍스트 버튼으로 바꾸고, 여유 공간에서는 화면 하단에 붙이며 작은 화면에서는 스크롤해 접근할 수 있게 했어요. 앱·프로필 위젯 테스트 34개와 Flutter 정적 분석을 통과했어요.

- 2026-10-16: Codex — iOS 내 정보의 구독 행을 현재 플랜과 `더 보기` 칩으로 바꿨어요. 플랜은 영문 소문자와 선택 상태의 검은색 배경으로 표시하고, 흰색 `더 보기`는 기존 구독 상세 화면으로 연결해요. `free`·`advance`·`plus` 위젯 테스트를 포함한 25개 테스트와 Flutter 정적 분석을 통과했어요.

- 2026-10-16: Codex — 내 정보의 학습 언어를 앱 언어와 같은 내용 폭 칩으로 바꾸고 한국어 → 영어·영어 → 한국어 두 옵션을 가로 배치했어요. 중국어 옵션을 제외하고 화살표를 단일 `→` 문자로 표시해요. 320px 한국어·영어 화면을 포함한 관련 위젯 테스트 23개와 정적 분석이 통과했어요.

- 2026-10-16: Codex — 내 정보의 현재 플랜과 학습 언어 선택 텍스트를 앱 언어 버튼과 같은 Freesentation 12px Medium으로 맞췄어요. 온보딩 카드 제목과 섹션 제목은 유지하며 Flutter 정적 분석과 관련 위젯 테스트 28개가 통과했어요.

- 2026-10-16: Codex — 내 정보의 구독·앱 언어·학습 언어 제목과 콘텐츠 간격을 공통 16px 값으로 묶고 학습 언어 카드에서 왼쪽 아이콘과 대화·피드백 설명을 숨겼어요. 온보딩 상세 표시는 유지하며 관련 Flutter 테스트 23개와 정적 분석이 통과했어요.

- 2026-10-16: Codex — Flutter 앱의 Pretendard·Newsreader·JetBrains Mono를 Freesentation Light·Regular·Medium·Bold 네 파일로 교체하고 제목·본문·버튼·레이블 토큰과 문서를 동기화했어요. Light는 등록만 하고 현재 계층에는 사용하지 않아요. Flutter 정적 분석과 전체 테스트 361개가 통과했어요.

- 2026-10-16: Codex — 대화 목록 조회에서 슬롯 재조정·프로필 잠금·구독 조회·커밋을 제거하고 저장된 `slot_active`로 잠금 상태를 표시해요. 목록 서비스 SQL은 2개이며 대화 도메인 테스트 52개가 통과했어요. 로컬 10회 측정 중앙값은 2000.7ms에서 1245.0ms로 줄었어요.

- 2026-10-15: Codex — Supabase 인증 모드의 코드 기본값을 `auto`로 바꾸고 환경변수 문서와 기본값 테스트를 갱신했어요. JWKS 캐시는 5분을 유지해요. 관련 테스트 7개가 통과했어요.

- 2026-10-15: Codex — Supabase ES256 access token을 워커가 캐시한 JWKS 공개 키로 검증하는 `auto` 모드를 추가하고 로컬 개발 설정에 적용했어요. 기존 원격 검증과 롤백 모드를 유지하고 인증·HTTP 연결 테스트 55개와 실제 개발 token의 로컬 검증을 확인했어요. 로컬 대화 목록 5회 측정 중앙값은 1829ms예요.

- 2026-10-11: Codex — `GET /api/auth/me`와 언어 설정 GET이 인증 단계에서 읽은 프로필을 재사용하도록 바꿔 기존 프로필 기준 SELECT를 요청당 2개에서 1개로 줄였어요. 인증 도메인 테스트 20개와 로컬 8010 API의 두 경로 HTTP 200을 확인했어요.

- 2026-10-11: Codex — macOS 키체인의 별도 Supabase 개발 계정 비밀번호로 로컬 토큰을 매번 새로 발급하고 대화 목록을 반복 측정하는 CLI를 추가했어요. 클라이언트 중앙값·p95·느린 요청 ID를 출력하며 토큰과 본문은 숨겨요. 모의 API·인증 테스트 14개가 통과했어요.

- 2026-10-11: Codex — 새 대화 생성 사전 검사가 전체 권한 요약 대신 구독 한도·활성 대화 수·진행 중 역할극 수만 조회하게 변경했어요. 검사 후 잠금을 해제하고 한도 변경 재조정을 저장하며, 저장 시점의 원자적 검사는 유지해요. 대화 도메인 테스트 52개가 통과했어요.

- 2026-10-11: Codex — 대화 시작·이어 말하기의 생성 텍스트를 요청별 메모리에 보관하고 재생 차례의 문장만 타이핑으로 공개해 첫 글자 프레임 뒤 음성을 시작해요. 완료 이벤트의 전체 답변 조기 노출과 저장 메시지 중복 표시를 막고, 음성 실패 시 텍스트를 공개해요. 커밋 후보의 Flutter 전체 테스트 359개와 정적 분석이 통과했어요.

- 2026-10-11: Codex — 대화 목록 조회에서 반환값을 쓰지 않는 전체 권한 요약을 제거하고 슬롯 재조정만 유지했어요. 기존 페이지 응답·잠금 상태를 보존하며 정상 한도에서는 목록 서비스 SQL이 4개로 줄어든 것을 확인했어요. 대화 도메인 테스트 49개가 통과했어요.

- 2026-10-11: Codex — DB 연결 획득 시간을 풀의 블로킹 큐 대기·새 DBAPI 연결 생성·기타 획득 처리로 나눠 요청 완료 로그에 기록해요. 새 연결과 풀 포화 후 재사용을 포함한 관련 백엔드 테스트 17개가 통과했어요.

- 2026-10-11: Codex — 긴 대화 재진입 테스트에서 폐기된 문법 카드 `SHOW MORE` 조작을 제거하고 스크롤 검증을 유지했어요. 프로필 로그아웃 테스트는 버튼을 화면에 스크롤한 뒤 탭하게 수정했어요. Flutter 전체 테스트 357개와 정적 분석이 통과했어요. 첨부 스트림 로그에서는 첫 응답 헤더 9.83초, 텍스트 생성 완료 약 10.95초, 첫 음성 약 15.47초로 확인했어요.

- 2026-10-11: Codex — 대화 시작·이어 말하기의 AI 텍스트를 글자별로 점진 표시하고 문장별 음성은 해당 문장의 표시 프레임 뒤에 재생하도록 했어요. 서버 LLM·NDJSON 송출과 앱 수신·첫 화면 프레임의 trace 계측을 추가했어요. 관련 Flutter 테스트와 정적 분석, 백엔드 스트림 테스트를 통과했고 실기기 시간값은 로컬 실행에서 확인해야 해요.

- 2026-10-10: Codex — 호스트 FS 대화 음성 캐시와 DB manifest, 파일 누락 시 재합성, 재진입 스피커 재생, 30일 만료·고아 파일 재시도 정리를 구현했어요. 백엔드 229개 테스트와 Flutter 분석을 통과했고, 기존 문법 카드 테스트 1개는 변경 전 기준에서도 실패함을 확인했어요.

- 2026-10-10: Codex — 대화 시작 스트림에서 자유 대화는 사용자 발화 확정 시 대화창으로 이동하고 임시 AI 텍스트를 표시해요. 시작 오디오는 대화창의 첫 텍스트 프레임 뒤에 재생하며 역할극·주간 추천도 같은 순서를 적용했어요. 관련 Flutter 시작 테스트 9개, 스트림 화면 테스트 1개, Dart 정적 분석을 통과했어요.

- 2026-10-09: Codex — 현재 구독 플랜 제목 옆 세모를 2 논리 픽셀(dp) 아래로 옮겼어요. Flutter 정적 분석을 통과했어요.

- 2026-10-09: Codex — 현재 구독 플랜 제목의 왼쪽 세모를 텍스트 바로 옆으로 붙이고 28px에서 34px로 확대했어요. Flutter 정적 분석을 통과했어요.

- 2026-10-09: Codex — 현재 구독 플랜 카드 제목 오른쪽 표시를 선형 오른쪽 화살촉에서 왼쪽을 향한 채운 세모로 바꿨어요. Flutter 정적 분석을 통과했어요.

- 2026-10-09: Codex — 현재 구독 플랜 카드 제목 오른쪽에 몸통이 없는 오른쪽 화살촉을 표시했어요. 권한 확인 전과 다른 플랜에서는 숨기며 Flutter 정적 분석을 통과했어요.

- 2026-10-09: Codex — 현재 구독 플랜 카드 배경색을 `#CC4A36`에서 `#A7BF93`으로 바꿨어요. 다른 카드의 `#BBC87C`는 유지했고 Flutter 정적 분석을 통과했어요.

- 2026-10-09: Codex — iOS 구독 화면에 제목만 있는 Free 카드를 추가하고 서버가 확인한 현재 플랜 카드만 `#CC4A36`, 나머지 카드에는 `#BBC87C` 배경을 적용했어요. Flutter 정적 분석을 통과했어요.

- 2026-10-09: Codex — Advance·Plus 구독 카드의 혜택 문구 앞에 글머리표 `•`를 추가해 목록 형태로 표시했어요. Flutter 정적 분석을 통과했어요.

- 2026-10-09: Codex — Plus 구독 카드에 `비즈니스 대화 모드` 혜택 문구를 추가하고 영어 문구도 맞췄어요. 기능 자체는 향후 Plus 전용으로 구현할 계획이며 관련 Flutter 테스트 7개와 정적 분석을 통과했어요.

- 2026-10-09: Codex — Advance·Plus 구독 카드의 토마토 꼭지와 전용 상단 여백을 제거했어요. 같은 에셋을 쓰는 주간 주제 카드는 유지하고 Flutter 정적 분석을 통과했어요.

- 2026-10-09: Codex — 2배 크기의 토마토 꼭지를 Advance·Plus 구독 카드 상단 가로 중앙으로 다시 옮겼어요. Flutter 정적 분석을 통과했어요.

- 2026-10-09: Codex — Advance·Plus 카드의 토마토 꼭지를 2배 확대하고 각 카드 상단 가로 75% 지점으로 옮겼어요. Flutter 정적 분석을 통과했어요.

- 2026-10-09: Codex — Advance·Plus 구독 카드 상단 가로 중앙에 기존 토마토 꼭지 PNG를 겹쳐 표시했어요. Flutter 정적 분석을 통과했어요.

- 2026-10-09: Codex — 구독 화면의 Advance 카드 배경을 `#BBC87C`, Plus 카드 배경을 `#CC4A36`으로 지정했어요. Flutter 정적 분석을 통과했어요.

- 2026-10-09: Codex — iOS 구독 화면의 Advance 설명을 `전체 대화 슬롯의 절반 해금`, Plus 설명을 `전체 대화 슬롯 해금`으로 바꾸고 영어 문구도 맞췄어요. 플랜 권한은 유지했고 관련 Flutter 테스트 7개를 통과했어요.

- 2026-10-09: Codex — 내 정보의 `학습 언어 선택` 제목을 `학습 언어`로 줄이고 영어 표시도 `Learning Language`로 맞췄어요. 관련 Flutter 테스트 27개를 통과했어요.

- 2026-10-09: Codex — 내 정보의 로그아웃 버튼을 앱·학습 언어 설정 아래 마지막에 배치했어요. 관련 Flutter 테스트 21개와 정적 분석을 통과했어요.

- 2026-10-09: Codex — 대화 시작 선택 팝업의 두 제목을 앱 표시 언어와 관계없이 `Free Chat`·`Roleplay`로 표기했어요. 한국어 앱 표시 환경의 팝업 테스트를 통과했어요.

- 2026-10-09: Codex — 홈 최근 대화 카드를 길게 누르면 왼쪽 스와이프와 같은 삭제 버튼을 표시하도록 했어요. 버튼 클릭은 기존 삭제 확인 경로를 사용해요. 관련 위젯 테스트 4개를 통과했어요.

- 2026-10-09: Codex — API JSON 로그의 `ts`를 초 단위 UTC로 바꾸고 `schema_version`·`event` 출력을 제거했어요. 로그 조회 문서와 기존 테스트의 필드별 분류를 동기화했으며 테스트 실행은 하지 않았어요.

- 2026-10-09: Codex — 대화창 문법 피드백 카드의 `SHOW MORE`/`SHOW LESS`와 한 줄 제한을 제거했어요. 피드백 아이콘으로 카드를 열면 교정 문장과 설명 전체가 즉시 보여요. 관련 위젯 테스트 17개와 정적 분석을 통과했어요.

- 2026-10-09: Codex — 내 정보의 언어 선택 제목을 `학습 언어 선택`으로 바꾸고 새 대화 적용 설명문을 제거했어요. 관련 Flutter 테스트 27개가 통과했어요.

- 2026-10-09: Codex — 음성 스트림 409의 사전 확인·DB 예약 충돌 경로와 미해결 turn 조회의 pending/failed 개수를 구조화 로그에 추가했어요. 사용자·대화 식별자와 본문은 기록하지 않으며 실제 재현 로그로 원인 판별은 아직 필요해요.

- 2026-10-09: Codex — 음성 스트림의 409 원인 확인을 위해 HTTP 예외의 안전한 `detail.code`를 `http.exception.error_code`에 기록하도록 했어요. 응답 본문이나 토큰은 기록하지 않으며 로컬 재현은 아직 확인하지 않았어요.

- 2026-10-09: Codex — 음성 스트림의 409 오류에서 이전 미해결 turn을 조회하고 거절된 텍스트를 입력창에 복원하도록 모바일 복구 경로를 수정했어요. 스트림 오류 JSON의 세부 코드를 읽도록 했고 Dart 정적 분석·diff 형식 검사를 확인했어요. 운영 환경 재현과 테스트 실행은 아직 하지 않았어요.

- 2026-10-09: Codex — 모바일·웹·API 오류·현재 문서의 서비스 표시 이름을 `tomatalk`으로 통일했어요. 로고·아이콘, iOS·Android 앱 식별자, Flutter 패키지명, 기기 저장 키, 운영 도메인은 유지했어요. Flutter 화면 테스트 35개·정적 분석과 백엔드 구독 테스트 5개가 통과했어요.

- 2026-10-09: Codex — 음성 스트리밍 4~6단계를 `dev/mobile`에 구현했어요. Free Chat·Roleplay 시작과 기존 대화의 LLM 문장별 TTS, 확정 발화 보존, turn 상태 조회·수동 재시도·오디오 재합성, 모바일 오류·복구 UI와 계약 문서를 연결했어요. Python 모듈 import, Dart 정적 분석, diff 형식 검사를 확인했고 테스트·실기기 검증·DB migration 적용은 수행하지 않았어요.

- 2026-10-05: Codex — 홈 최근 대화 카드 제목에도 주간 주제와 같은 두 어절 단위 줄바꿈을 적용했어요. 대화 제목 원문·접근성 이름·선택/삭제 동작을 유지했고, 390px 화면에서 세 줄 표시와 관련 Flutter 테스트 31개·정적 분석을 확인했어요.

- 2026-10-05: Codex — 주간 주제 카드 표시 문구를 공백 기준 두 어절씩 묶어 줄바꿈하고 카드 높이·최대 줄 수를 세 줄에 맞췄어요. 대화 시작에 전달되는 원문과 접근성 이름을 유지했으며 관련 Flutter 테스트 28개와 정적 분석이 통과했어요.

- 2026-10-05: Codex — 주간 주제 카드에 `text_ko` 어절 단위 줄바꿈을 적용하고 움직이는 카드의 좌우 여백을 조정해 `내가 배우고 싶은 새로운 기술`의 `기술`이 함께 둘째 줄에 나오도록 했어요. 관련 Flutter 테스트 28개와 정적 분석 통과.

- 2026-10-05: Codex — Flutter Splash 이미지에 진입 시 한 번 0.96배로 눌렸다가 돌아오는 650ms 모션을 적용하고 완료 전에 다음 화면으로 이동하지 않도록 했어요. 동작 줄이기 설정에서는 생략했고 Splash·앱 흐름 테스트 14개와 Flutter 정적 분석이 통과했어요.

- 2026-10-05: Codex — Flutter Splash의 기존 텍스트·로딩 표시를 제거하고 제공된 Toma Talk 이미지를 중앙에 표시했어요. 복원 오류 시 텍스트 없는 재시도 아이콘을 유지했고 Splash·앱 흐름 테스트 11개와 Flutter 정적 분석이 통과했어요.

- 2026-10-03: Codex — 기존 작업 트리의 iOS Apple 로그인 연결을 검증하고 로그인 버튼의 중복 접근성 레이블을 정리했어요. Apple nonce·Supabase 세션·Home 진입 테스트, Flutter 전체 311개, 정적 분석, iOS 시뮬레이터 빌드가 통과했어요. 사용자가 실기기 Apple 계정 로그인을 확인했어요.

- 2026-10-01: Codex — 홈 잠금 카드와 대화 목록 잠금 행에 같은 원형 배지·채워진 자물쇠를 적용했어요. 홈 48px·목록 40px로 구분하고 설명 문구 없는 상태와 탭 안내를 유지했어요. 관련 Flutter 화면 테스트 24개·정적 분석 통과, 배지 렌더 미리보기 확인.
- 2026-10-01: Codex — 홈 파스텔 잠금 카드와 대화 탭 잠금 행의 노출 문구를 제거하고 자물쇠만 중앙에 배치했어요. 스크린리더 레이블과 탭 후 안내는 유지했고 관련 Flutter 위젯 테스트 24개·정적 분석을 통과했어요.
- 2026-10-01: Codex — iOS 앱이 연결하는 Supabase 프로젝트와 같은 DB에 대화 권한 migration `20261001_0001`을 적용하고 기존 3개 계정의 보장 슬롯을 스냅샷했어요. 원격 API 코드·권한 스위치는 변경하지 않았고 로컬 미리보기 서버는 종료했어요. 운영 전체 제한 또는 별도 UI 미리보기의 적용 범위 결정을 기다려요.
- 2026-10-01: Codex — [대화 권한 계약](../_contracts/CONVERSATION_ACCESS.md)에 따라 기본 비활성화 슬롯·대화별 15턴 서버 제한, 기존 보유 개수 스냅샷, 홈·대화 탭 잠금 자리와 15턴 읽기 전용 안내를 구현했어요. 백엔드 189개 통과·3개 건너뜀, Flutter 307개 통과·정적 분석 이상 없음. 결제·유료 플랜 권한과 운영 활성화는 후속 작업이에요.
- 2026-10-01: Codex — [무료 대화 권한·잠금 UI 계획](../../docs/plans/archive/2026-09-30-001-feat-conversation-access-plan.md)과 [제품 전략](../../STRATEGY.md)을 사용자 결정에 맞춰 갱신했어요. 동시 보유 1개, 기존 계정 보유 개수 유지, 대화별 15턴, 영구 추가 슬롯, 결제 전 정책 비활성화를 정리했으며 제품 코드는 변경하지 않았어요.

- 2026-09-22: Codex — [모바일 3탭 전환 실행 순서](../../../docs/plans/archive/2026-09-22-001-refactor-mobile-three-tab-navigation-approach.md) 작성. 상태 보존 라우팅, 전체 목록 페이지 조회, 내 정보 화면, 홈 CTA·복귀 경로 순서를 정리했어요. 제품 코드 변경·테스트 실행은 없어요.

## 2026-09-22

- **모바일 내비게이션 v2**: dev/mobile에 홈·대화·내 정보 상태 보존 3탭을 반영했어요. 홈은 스낵·최근 2개 파스텔 카드·그 아래 새 대화, 대화 탭은 전체 페이지 행 목록·상단 +, 내 정보는 기존 설정을 독립 화면으로 제공해요. 완료한 준비 단계 제거·출발 탭 복귀·삭제/복귀 후 목록 갱신·숨은 홈의 스낵 모션 취소를 연결했어요. Flutter 전체 303개·정적 분석·diff 검사 통과. 가상 데이터 iOS Simulator에서 3탭·시트 열기/취소를 확인하고 390px/200% 글자 위젯 렌더를 검증했어요. Android/실계정 종단 검증·커밋·푸시는 수행하지 않았어요. 실행 계획은 archive로 옮기고 모바일 README·아키텍처·디자인 시스템에 결정을 반영했어요.

- **대화 조회 단위 v1.1**: 최초·이전 기록 조회 단위를 메시지 40개(사용자·AI 한 쌍 기준 약 20턴)로 변경했어요. 40/41개 경계·부분 페이지·재진입을 포함한 관련 테스트 21개와 Flutter 정적 분석 통과. 문서 동기화 완료, 커밋 없음.

- **기존 대화 최신 위치 진입 v1**: 기존 offset API로 최신 50개 조회·이전 구간 추가 조회를 구현하고, 대화 화면 재진입 시 최신 메시지를 표시하도록 목록 방향과 스크롤 수명을 변경했어요. 이전 기록 조회 실패·재시도·중복 요청·전송/녹음 충돌을 처리하고 과거 열람·교정 확장 시 강제 이동을 방지했어요. Flutter 전체 290개 테스트·정적 분석·diff whitespace 검사 통과. 현재 dev/mobile 브랜치에 반영했고 API 계약 변경·실기기 검증·커밋은 없어요.

## 2026-09-20

- **Appllama 기준 모바일 UI 리뷰**: 현재 위젯의 390×844 렌더·글자 2배 시트·긴 대화 초기 스크롤·28px 삭제 터치 영역을 확인하고 학습 흐름·탭 의미·테마·시트 결함의 개선 순서를 제안했어요. 제품 코드 변경 없이 임시 렌더 테스트를 정리했으며 시뮬레이터 전체 모션·실기기 FPS는 미검증이에요.
- **Home 디버그 리셋 버튼**: 열람 수 옆 restart 아이콘으로 같은 카드·순서·서버 리셋 ID를 유지하며 현재 기기 진행을 0으로 저장하고 토마토 3개 바구니로 돌아가요. 디버그 전용이며 모션·팝업 중 비활성화, release/profile에는 UI·로컬 초기화 경로를 차단해요. Flutter 전체 282개·정적 분석 통과, 320/390/768px·글자 2배 캡처 생성과 작은/넓은 화면 확인, 로컬 코드 검토 이슈 없음. 백엔드 변경·운영 키 포함·실기기 실행·배포·커밋은 없어요.

## 2026-09-19

- **바구니 UI 정리·운영 리셋 API**: 제목과 바구니 점/체크를 제거하고, 운영 키로 사용자·학습 언어별 리셋 ID를 갱신하는 POST와 본인 조회 GET을 추가했어요. 앱 시작·Home 진입·복귀 시 같은 12개 카드의 진행을 한 번만 초기화하며 팝업·모션 중 지연, 오프라인 진행 보존, 계정 전환 응답 무시를 검증했어요. 리셋 테이블만 추가하는 migration과 운영 절차를 문서화했어요. Flutter 전체 275개·정적 분석, 백엔드 181개·Ruff 통과(외부 PostgreSQL 관련 3개 skip), UI 캡처 확인. 운영 DB migration·배포·실제 계정 리셋·실기기 검증은 수행하지 않았어요.
- **토마토 꺼내기 모션**: 기존 PNG와 컨트롤러로 400ms 바구니 페이드·토마토 이동·42%→100% 확대·반동을 추가했어요. 꺼내기 중 중복 입력·소비 방지, 모션 감소 즉시 전환, 화면 폐기와 자정 지연 처리를 검증했어요. Flutter 전체 268개·정적 분석 통과, 320/390/768px 중간 프레임·최종 렌더 캡처 확인. 추가 에셋·의존성·백엔드 변경·실기기 검증·배포는 없어요.
- **토마토 4입 진행 점 제거**: 토마토 하단 진행 점만 숨기고 바구니 완료 표시·접근성·영역 높이는 유지했어요. 위젯 테스트 19개·정적 분석 통과, 렌더 캡처 확인. 꺼내기 확대 효과는 Flutter 위치·크기 애니메이션으로 가능하다고 안내하고 미구현으로 남겼어요.
- **남은 토마토 바구니 단계**: `tomato_basket_leave_2/1/0.png`를 번들링하고 4·8·12번째 팝업 종료 후 해당 바구니로 복귀해요. 다음 토마토는 별도 터치로 꺼내고, 완료 경계 재진입·부분 소비 복원·자정까지 빈 바구니 유지 정책을 검증했어요. Home 74개·정적 분석 통과, 세 바구니 렌더 캡처 확인. 저장 형식·API 변경 및 배포는 없어요.
- **토마토 터치 배경·팝업 정리**: 투명 PNG 뒤에 비치는 InkWell 기본 물결·눌림 하이라이트를 제거하고 토마토 애니메이션·키보드 포커스는 유지했어요. 팝업의 페이지 번호만 제거하고 Home 진행 표시는 유지해요. 수정 전 흰색→회색 픽셀 변화를 재현한 뒤 배경 불변 회귀 테스트를 추가했으며 Home 69개·정적 분석 통과, 작은 화면·큰 글자 팝업 캡처 확인. 실기기 검증·배포는 수행하지 않았어요.

## 2026-09-18

- **토마토 스낵 자정 리필 v2**: 투명 바구니·수정된 3입 PNG를 반영하고 12개 소진 후 당일 재충전을 제거했어요. 재시작 후 소진 복원, 현지 자정·앱 복귀 갱신, 팝업 중 날짜 변경 지연을 검증했어요. Flutter 전체 255개·정적 분석 통과, 이미지 디코딩을 기다리는 캡처 검증 12개 통과. API 기본 최신순·Home 랜덤 요청과 seed 없이 응답 ID 중복을 막는 기존 계약을 유지하며, 운영 배포·실기기 검증은 수행하지 않았어요.
- **토마토 언어 스낵 UI**: 제공 PNG 6장을 번들링하고 바구니·토마토 3개 × 4입·팝업·동일 12개 복습을 구현했어요. API `order=random`으로 학습 언어별 전체 발행 목록에서 추출하며 사용자·언어·기기 날짜별 묶음과 진행을 로컬 저장해요. Flutter 252개·백엔드 177개 통과(외부 PostgreSQL 관련 3개 skip), 320/390/768px·글자 2배 렌더 캡처 검증. 운영 배포·실기기 검증·DB 변경·콘텐츠 생성은 수행하지 않았어요.

## 2026-09-15

- **마케팅 전략 제안 v0.1**: 현재 기능과 공식 시장·경쟁 자료를 바탕으로 [한국어·영어 학습자별 홍보 전략](../PM/MARKETING_STRATEGY.md), 8주 실험·예산·측정 기준과 PM 인덱스를 작성했어요. 출시 상태·가격·예산은 가정으로 구분했어요.

## 2026-09-13

- **AsyncClient 연결 풀 v1**: 워커별 AI·인증 풀과 전체 provider 주입, CLI 재사용, 문법 task 추적·종료 및 별도 DB session을 적용. 최대/유휴 연결·만료·종료 대기 설정과 [계측 문서](../../docs/VOICE_LATENCY.md)를 동기화. 실제 localhost 연결 재사용 포함 29개 신규 테스트·전체 175개 통과(3 skip). 유료 API 지연 실험·운영 배포는 미실행
- **음성 대화 지연 계측**: 서버 auth·STT·LLM·TTS·응답과 앱 녹음 종료·HTTP·첫 재생에 trace별 print 로그 추가. [반복 실험·연결 풀 검토](../../docs/VOICE_LATENCY.md)와 [스트리밍 설계 제안](../../docs/VOICE_STREAMING.md) 작성. 백엔드 146개·Flutter 232개 통과, 최종 관련 Flutter 19개 재검증·정적 분석 통과. 실제 API 10회 실험과 연결 풀·스트리밍 구현은 미실행
- **README 간소화**: 소개·준비·실행·CLI·문서 링크 중심으로 788줄을 139줄로 축소. 환경변수는 [ENVIRONMENT.md](../../docs/ENVIRONMENT.md), 배포·cron·복구는 [OPERATIONS.md](../../docs/OPERATIONS.md)로 이관하고 DSL·협업 규칙·관련 링크를 동기화. 내부 링크 40개, shell 블록 12개, Settings 필드 58개 문서 포함 여부 검증. 다른 진행 작업의 README 추가는 상세 설명 대신 문서 링크 중심으로 유지

## 2026-09-12

- **언어 스낵 v2 구현**: JSONB 세 유형·학습 언어별 조회, identity 중복 방지·LLM 검증·재개 가능한 주간 생성 CLI, PostgreSQL advisory lock, 운영 API, Flutter 언어별 캐시·5초 카드 전환과 배포 문서를 반영. 운영 DB 변경·LLM 실제 생성·cron 등록은 미실행
- **언어 스낵 JSONB·정기 생성 계획 초안 작성**: 세 유형 payload, 핵심 지식 중복 검사, 월요일 05시 생성·자동 발행, 학습 언어별 조회·캐시, backend/frontend 단계와 미확정 운영 질문을 [계획](../../docs/plans/2026-09-12-2219-feat-language-snack-generation-plan.md)에 정리

## 2026-09-06

- **Home 언어 스낵 API·캐러셀 구현**: 공통 발행 카드의 생성·조회 API와 운영 키 보호, Alembic migration, Flutter 마지막 성공 캐시, 5초 자동 전환·수동 탐색·접근성 상태, 문서와 회귀 테스트를 추가
- **Roleplay 수동 난이도 제거 구현**: 역할극 난이도 UI·모바일/백엔드 API·prompt·ORM·응답 모델을 제거하고 `conversations.roleplay_difficulty` 및 PostgreSQL enum 삭제 migration, 호환성·회귀 테스트와 문서·디자인 동기화를 추가
- **Roleplay 수동 난이도 제거·DB 컬럼 삭제 구현 계획 작성**: 수동 난이도 UI/API/prompt/ORM을 제거하고, PostgreSQL enum을 포함한 destructive migration, code-first 배포 순서, 모바일·백엔드·문서 검증 범위를 확정

## 2026-09-03

- **모바일 문법 피드백 아이콘 UI 수정**: 오류 없는 피드백은 초록 체크 아이콘만 표시하고, 오류 피드백은 빨간 느낌표 아이콘을 탭했을 때 상세 교정 카드가 열리도록 변경

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
- **Home·대화 삭제 UI 조정**: Home·History 대화 카드의 삭제 진입점을 작은 X 아이콘으로 바꾸고 삭제 성공 뒤 최근 대화 목록을 즉시 다시 불러오며, Home 인사말 대신 빈 상태의 대화 시작 안내를 한국어·영어로 표시
- **프로필 설정 저장 흐름 단순화**: 앱 언어와 언어쌍의 별도 저장 버튼을 제거하고, 선택 후 확인 팝업에서 승인하면 즉시 저장하도록 정리
- **음성 입력 로딩 정렬 조정**: 음성 전송 상태 문구와 응답 대기 점 표시를 중앙 정렬해 대화 화면의 로딩 균형을 맞춤

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

## 2026-08-28

- **Assistant 음성 재생 제어 개선**: 새 응답만 한 번 자동 재생하고, AI 말풍선 우하단 스피커 아이콘으로 재생·중단을 제어하도록 변경
- **대화 제어 아이콘 가시성 보정**: Home·History 카드 삭제 X를 우상단으로 고정하고, AI 말풍선 음성 아이콘의 대비와 위치를 강화
- **대화 삭제 로딩 즉시화**: 삭제 확인 직후 Home·History 목록을 로딩 상태로 전환하고, 삭제 완료 뒤 최신 목록을 표시하도록 변경

- 2026-09-16: Codex — [VoiceStudio의 GPU 없는 STT·TTS 활용 검토](../../docs/VOICESTUDIO_REVIEW.md): CPU 엔진 후보·현재 통합 제약·라이선스·평가 절차 기록, 구현·배포 없음.

## 2026-10-03

- **주간 대화 주제 구현 계획 작성**: 언어쌍별 발행, 홈 곡선 루프, AI 선발화 자유 대화, 운영·검증 단위를 문서화했어요.
- **주간 대화 추천 구현**: 수동 AI 발행 CLI·추천 목록과 멱등 시작 API·Flutter 곡선 루프·계정별 캐시를 연결하고 백엔드 199개, Flutter 317개 테스트를 통과했어요.
- **홈 추천 상시 표시**: 최근 대화의 개수·로딩 상태와 주간 추천 표시를 분리하고, 대화가 있어도 발행된 주제를 보여주도록 수정했어요. Flutter 318개 테스트를 통과했어요.
- **주간 주제 카드 정리**: 추천 제목·공통 배경 박스를 제거하고 주제별 파스텔 카드 색을 적용했어요. 관련 위젯 테스트 21개와 Dart 분석을 통과했어요.
- **추천 대화 첫 메시지 FK 수정**: 대화·AI 메시지를 순서대로 flush한 뒤 추천 시작 예약을 완료해 PostgreSQL 외래 키 오류를 해결했어요. FK 활성화 회귀 테스트와 백엔드 전체 199개 테스트를 통과했어요.
- **주간 주제 시작 확인·로딩**: 주제 탭 후 확인 팝업을 거쳐 API를 호출하고, AI 첫 질문을 기다리는 동안 로딩·실패 상태를 표시해요. Flutter 321개 테스트와 Dart 분석을 통과했어요.
- **홈 주간 주제 순서 조정**: 주간 주제를 최근 대화 위로 옮기고 빈 상태 제목을 축소했어요. 시작 로딩 문구를 ‘대화 시작을 준비하고 있어요’로 변경하고 Flutter 321개 테스트를 통과했어요.
- **주간 주제 좌우 슬라이드**: 홈의 주제 카드를 손가락으로 좌우 이동하고 놓은 위치에서 자동 흐름을 재개하도록 변경했어요. Flutter 322개 테스트와 Dart 분석을 통과했어요.

## 2026-10-04

- **iOS Apple 구독 연동**: Advance·Plus StoreKit paywall, 서버 거래·알림 검증, 무료/구독 대화 권한과 읽기 전용 기록을 구현했어요. 백엔드 210개·Flutter 322개 테스트, iOS 디버그 빌드를 통과했으며 Sandbox 실거래 검증과 운영 활성화는 남아 있어요.

- **주간 주제 첫 질문 선생성**: 주제·첫 질문을 함께 검증·발행하고 같은 주차를 활성 ID를 보존하며 재발행하는 CLI를 추가했어요. 추천 시작은 저장된 질문을 사용하며 백엔드 203개 테스트를 통과했어요.
- **주간 주제 재발행 복구**: 재발행 후보를 12쌍으로 늘려 검증 탈락 여유를 확보하고 CLI에 안전한 실패 코드와 개수를 표시했어요. 백엔드 204개 테스트를 통과했어요.
- **주간 주제 선택 색상**: 홈 주제 카드를 회색·검정 글자로 통일하고 탭한 주제를 즉시 빨간색으로 표시하며 취소·실패 시 복원해요. 관련 Flutter 테스트 26개와 Dart 분석을 통과했어요.
- **홈 주간 주제 위치 조정**: ‘최근 대화’ 제목과 대화 카드 사이로 주간 주제를 옮기고 간격을 조정했어요. 라이브 UI 확인을 위해 테스트 실행은 보류했어요.
- **주간 주제 카드 꼭지 이미지**: 각 주제 카드 상단 테두리 중앙에 초록 토마토 꼭지를 걸치고 원본 이미지의 투명 여백은 화면에서 잘라 표시해요. 꼭지 크기는 최초 시안의 약 ⅔로 조정했어요. 라이브 UI 확인을 위해 테스트 실행은 보류했어요.
- **주간 주제 확인 팝업 위치**: 선택한 카드의 빨간색 상태가 보이도록 대화 시작 확인 팝업을 화면 중심보다 위에 배치했어요. 라이브 UI 확인을 위해 테스트 실행은 보류했어요.
- **대화 잠금 팝업 위치**: 구독 화면으로 이어지는 대화 잠금 안내 팝업을 주간 주제 확인 팝업과 같은 높이에 배치했어요. 라이브 UI 확인을 위해 테스트 실행은 보류했어요.
- **모바일 2탭 내비게이션**: 하단 바를 홈·내 정보로 줄이고 전체 대화는 홈의 `전체 보기`에서 열도록 변경했어요. 대화 직접 진입의 뒤로가기는 홈으로 연결하고 관련 테스트·문서를 갱신했어요.

## 2026-10-05

- **API 구조화 로그 구현 계획**: 요청·단계·예외의 JSON stdout 로그, nginx 시간 계측, Docker 회전과 향후 Loki 수집 계약을 계획서에 정리했어요. 첫 구현의 모든 API 전체 시간·보호 API 인증 시간과 500 오류의 메시지 없는 안전한 스택 기록을 확정했어요.
- **음성 스트리밍 2~3단계**: `dev/mobile-stream`에서 turn·attempt 영속 기록과 상태 조회·재시도 전이 기반, 주간 추천 시작 NDJSON/Base64 문장 오디오, Flutter 증분 decoder·재생 큐·화면 이탈 취소를 연결했어요. DSL·아키텍처·앱 문서를 동기화했고 Flutter 정적 분석·Python 구문 및 라우터 import를 확인했어요. 다른 대화 흐름과 수동 재시도 UI는 후속 단계예요.
- **음성 스트리밍 1단계 계약**: `dev/mobile-stream` worktree에서 전용 `/stream/` 경로, NDJSON 이벤트, 발화 보존·재시도·상태 조회의 DRAFT 계약을 작성하고 설계 문서에 연결했어요.
- **음성 스트리밍 설계 갱신**: 기존 JSON 경로와 분리된 `/stream/` 경로, 문장별 NDJSON·Base64 오디오, 사용자 발화 보존·수동 재시도 계약과 권장 개발 순서를 제안 문서에 기록했어요.
- **인증 프로필 쓰기 제거**: 보호 API 인증 시 기존 프로필은 조회만 하고, 언어·표시 언어 값이 실제로 바뀔 때만 `updated_at`을 갱신해요. 백엔드 211개 테스트를 통과했어요.
- **홈 헤더 언어 쌍 배지 정렬**: 원형 프로필 아이콘을 제거하고 현재 언어 쌍 배지를 오른쪽 끝에 배치했어요. 내 정보 진입은 하단 탭으로 통일했어요.
- **홈 섹션 제목 변경**: `최근 대화`를 `오늘의 토마토`로 바꾸고 `전체 보기`와 같은 16px 서체·좌우 8px 여백을 적용했어요. 홈 화면 테스트 22개와 Dart 분석을 통과했어요.
- **홈 전체 보기 제거**: `오늘의 토마토` 옆의 `전체 보기` 버튼과 연결 콜백을 제거했어요. `/history` 직접 진입 경로는 유지하며 홈·앱 테스트 30개와 Dart 분석을 통과했어요.
- **오늘의 토마토 제목 정렬**: 홈 섹션 제목을 가운데 정렬하고 기존 글자 크기와 좌우 여백을 유지했어요. 홈 화면 테스트 21개와 Dart 분석을 통과했어요.
- **최근 대화 카드 스와이프 삭제**: 메시지 수·계속 대화하기·X 표시를 제거하고 왼쪽으로 밀면 `삭제`를 드러내 기존 확인 팝업으로 연결했어요. 잠긴 대화의 읽기 전용 표시는 유지해요. 관련 테스트 23개와 Dart 분석을 통과했어요.
- **최근 대화 유형 배지**: 카드의 왼쪽 제목 옆 오른쪽 공간에 Free Chat/Roleplay 흰색 태그 배지를 추가하고, 긴 제목은 남는 폭에서 최대 두 줄로 제한했어요. 홈·카드 테스트 23개와 Dart 분석을 통과했어요.
- **대화 유형 배지 문구 통일**: 한국어·영어 UI에서 배지를 소문자 `freechat`·`roleplaying`으로 표시하고 대문자 변환을 제거했어요. 관련 테스트 28개와 Dart 분석을 통과했어요.

## 2026-10-09

- **홈 헤더 로고 확정**: 미리보기 탭 전환을 제거하고 초록 가로형 Toma Talk 로고를 164 × 40pt로 왼쪽에 적용했어요. iPhone 17 시뮬레이터에서 일반 실행 화면을 확인했고 홈 테스트 21개와 Dart 분석을 통과했어요.
- **API 구조화 로그 구현**: 전체 API 요청·인증·기존 음성 단계와 예외를 개인정보를 제외한 JSON stdout 로그로 연결했어요. nginx 시간 로그와 Docker 회전·운영 문서를 추가하고 백엔드 221개 테스트를 통과했어요. 실제 nginx 컨테이너 검증은 Docker 데몬 실행 환경에서 확인해야 해요.

## 2026-10-11

- **음성 없는 API 지연 계측**: 인증 원격 호출·프로필 조회, 요청·응답 시점, DB 연결 획득·쿼리·commit, 대화 GET 경로와 모바일 GET 출처·재시도를 같은 요청 ID로 기록해요. 백엔드 234개 테스트와 모바일 네트워크 테스트 10개, 수정 파일 정적 분석을 통과했어요.

- **대화 응답 단계별 표시 계획**: 역할극 임시 화면 진입, 첫 문장 TTS 공급 시점, 지연 계측과 실기기 검증을 `docs/plans/2026-10-11-1526-feat-progressive-conversation-response-plan.md`에 정리했어요.
- **역할극 첫 응답 조기 표시·재생**: `turn_started`에서 임시 대화 화면에 진입해 텍스트 첫 프레임 뒤 음성을 재생하고, 완료 시 영속 화면으로 전환해요. 문장 경계와 서버·앱 첫 이벤트 계측을 보강했고 백엔드 233개 테스트 및 Flutter 정적 분석을 통과했어요. Flutter 전체 테스트의 기존 프로필 로그아웃·긴 대화 스크롤 실패 2건과 실기기·프록시 검증은 남아 있어요.

## 2026-10-18

- **첫 로그인 닉네임 설정**: 기존 프로필 이름 이관, 신규 계정의 필수 입력 팝업, 본인 닉네임 저장 API와 내 정보 수정을 구현했어요. 중복 검사는 제외했어요. 백엔드 263개·모바일 369개 테스트와 Flutter 정적 분석을 통과했고, 계획서는 `docs/plans/archive/2026-10-18-2007-feat-nickname-first-login-plan.md`에 보관했어요.
- **닉네임 수정 버튼 표시**: 내 정보의 닉네임 수정 버튼을 연필 아이콘에서 오른쪽 화살표로 변경했어요.
- **첫 닉네임 무작위 추천**: randino Dart 패키지로 기기 우선 시스템 언어가 한국어면 영어, 그 외에는 한국어 닉네임을 첫 설정 입력 칸에 채워요. 기존 닉네임 수정과 서버 저장 흐름은 유지하며 관련 Flutter 위젯 테스트와 정적 분석을 통과했어요.

## 2026-10-23

- **Topic Prep 검색 생략**: 검색어 분석의 `search_required` 판정에 따라 검색·출처 판정을 생략하고 카드를 생성해요. 명시적 최신 정보 요청과 분석 실패는 검색으로 처리하고 후속 질문·방향 재생성은 검색하지 않아요. 백엔드 304개 테스트와 모바일 관련 테스트 5개를 통과했어요.
