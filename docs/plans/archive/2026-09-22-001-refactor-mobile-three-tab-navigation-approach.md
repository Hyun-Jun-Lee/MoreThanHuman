---
title: 모바일 홈·대화·내 정보 3탭 전환 실행 순서
date: 2026-09-22
type: refactor
plan_kind: approach
status: completed
---

# 모바일 3탭 전환 실행 순서

## 목표와 합의된 화면

사용자가 목적지 이동과 새 대화 시작을 구분하고, 탭을 오가도 이전 화면 상태와 복귀 위치를 유지하도록 해요. 이 문서는 구현 전 접근 계획을 보관한 기록이에요. 2026-09-22 현재 브랜치에 반영했으며 현행 기준은 `mobile/README.md`, `.agent/architecture.md`, `docs/design/DESIGN_SYSTEM.md`예요. 홈의 새 대화 버튼은 최근 카드 아래, 대화 탭은 간결한 행 목록으로 확정했어요.

| 화면 | 합의된 구성 |
|---|---|
| 홈 | 기존 언어 스낵, 최근 대화 2개, 전체 보기, 본문의 `＋ 새 대화` 버튼 |
| 대화 | 전체 대화 목록, 상단 `＋` 버튼. 스낵은 없어요 |
| 내 정보 | 기존 계정·학습 언어·앱 언어·로그아웃 기능을 독립 화면으로 제공 |

최근 대화 카드를 누르면 이어 말해요. 별도의 `지난 대화 이어가기` 버튼은 만들지 않아요. 홈과 대화의 새 대화 버튼은 같은 자유 대화/롤플레이 선택 시트를 열어요. 홈 상단 아바타는 내 정보 탭으로 이동해요. 최근 대화 개수는 앞선 합의 범위인 1∼2개 중 2개를 기본값으로 정해요.

이번 범위는 3탭 구조와 이에 필요한 목록·화면·탐색 연결이에요. 자유 대화 준비 화면 재설계, 다크 테마 전체 도입, 스낵 디자인 변경, 새로운 통계·검색·필터는 별도 작업으로 남겨요. 2026-09-22 반영된 최신 메시지 진입·이전 메시지 조회는 유지하며 회귀 검증해요.

## 현재 구현에서 확인한 전제

- `mobile/lib/app/router/app_router.dart`: Home/History가 개별 route이며 History로 push해요. 탭별 상태를 보존하는 공통 shell은 없어요.
- `mobile/lib/features/history/presentation/history_screen.dart`: 홈의 `recentConversationsControllerProvider`를 재사용해요.
- `mobile/lib/features/home/data/api_home_repository.dart`: 기본 limit 5, offset 0만 요청하며 페이지 정보를 버려요. 현재 화면을 이름만 바꾸면 전체 목록 요구를 충족하지 못해요.
- `backend/domains/conversation/router.py`: 목록 GET은 이미 limit/offset과 페이지 응답을 지원해요. 우선 기존 계약으로 모바일 전체 목록을 연결해요.
- `mobile/lib/features/home/presentation/account_sheet.dart`: 설정 동작과 시트 닫기 동작이 묶여 있어 화면으로 옮길 때 분리해야 해요.
- `mobile/lib/features/home/presentation/widgets/language_snack_home_section.dart`: initState·앱 복귀·자정 타이머로 갱신해요. 탭이 유지되는 구조에서는 활성 탭 복귀도 갱신 계기로 고려해야 해요.
- Topic Prep/Roleplay 성공은 현재 `context.go`로 대화에 이동해요. 출발 탭을 보존하고 준비 화면만 제거하는 복귀 설계가 필요해요.

## 권장 실행 순서

### 1. 탐색 규칙과 검증 기준을 먼저 고정해요

하단 탭 순서를 홈·대화·내 정보로 고정하고, 라벨은 한글/영문 모두 준비해요. 빈 상태에서도 세 목적지를 유지해요. 준비 화면과 대화 화면에서는 탭을 숨기고, 뒤로 가면 출발한 탭으로 돌아오게 해요. 기존 대화 직접 진입처럼 출발 정보가 없는 경우의 복귀는 대화 목록으로 정해요.

같은 탭 재선택은 탭의 시작 화면으로 돌아가며 이미 시작 화면이면 맨 위로 이동해요. Android 최상위 뒤로가기는 탭 이동 이력을 되감지 않고 플랫폼 기본 앱 이탈 동작을 따르도록 해요. 실제 기기에서 시스템 뒤로가기와 화면 버튼이 서로 모순되지 않는지 확인해요.

### 2. 공통 탭·라우팅 기반을 만들어요

탭마다 navigation과 스크롤 상태를 보존하는 shell을 도입해요. 현재 go_router 버전에서 지원하는 `StatefulShellRoute.indexedStack`을 우선 적용 후보로 삼고, 구현 시 설치된 버전의 API를 확인해요. 하단 바는 공통 shell이 하나만 소유하고 Home/History 화면의 중복 바를 제거해요. 기존 `/history` 주소는 대화 탭 주소로 유지해 불필요한 URL 변경을 피하고, 내 정보 목적지를 추가해요.

인증 초기화/로그아웃 경계에서는 탭 상태를 적절히 초기화하고, 일반 탭 전환이나 설정 갱신 때문에 위치를 잃지 않도록 해요. 유지되는 숨은 Home에서 스낵 팝업·애니메이션이 다른 탭 위로 나타나지 않게 하고, 홈 활성화 시 기존 stale/date/reset 검사를 연결해요. 스낵 소비 횟수나 콘텐츠 정책은 바꾸지 않아요.

주요 대상: `mobile/lib/app/router/app_router.dart`, 신규 앱 shell, `mobile/lib/core/widgets/main_navigation_bar.dart`, Home/History의 Scaffold 연결부.

### 3. 계정 시트를 내 정보 화면으로 전환해요

기존 설정 본문을 독립 화면으로 옮기고, sheetContext를 닫는 동작을 설정 저장 처리에서 분리해요. 학습 언어 변경 확인·실패 처리·기존 대화 언어 유지 안내를 보존해요. 화면은 현재 profile 값을 관찰해 저장 후 선택 상태를 갱신해요. 앱 언어 변경은 현재 탭을 유지하며 문구를 갱신하고, 로그아웃은 기존 인증 라우팅을 통해 로그인으로 이동해요.

기존 `account_sheet.dart`의 재사용 가능한 내용을 신규 `mobile/lib/features/profile/`로 이동하는 방향이에요. 상단 아바타와 하단 내 정보는 같은 목적지를 가리켜요. 설정 기능을 중복 구현하지 않아요.

### 4. 대화 탭에 실제 전체 목록을 연결해요

기존 limit/offset API를 사용하는 페이지 모델·repository·controller를 대화 목록용으로 구성해요. 첫 페이지와 추가 페이지를 구분하고, 추가 조회 실패는 기존 목록을 유지한 채 재시도할 수 있게 해요. 응답의 pagination을 사용해 종료를 판단하며 중복 요청과 중복 ID를 막아요. 홈의 최근 목록과 전체 목록의 표시 범위를 분리해요.

새 대화 생성·대화 갱신·삭제 후 두 목록의 캐시를 함께 정합하게 갱신해요. offset 기반 목록의 순서가 바뀌는 변경 후에는 페이지 기준을 재설정해 누락·중복 위험을 줄여요. 계정 변경 시 이전 계정의 지연 응답과 캐시가 섞이지 않도록 해요. 목록 제목은 대화로 바꾸고 상단에 `＋`를 배치하며 tooltip/접근성 이름은 새 대화로 지정해요.

주요 대상: `mobile/lib/features/history/`, `mobile/lib/features/home/domain/home_repository.dart`, `mobile/lib/features/home/data/api_home_repository.dart`, 관련 목록 상태. 서버 API 신설은 현재 확인한 범위에서 필요하지 않아요.

### 5. 홈을 합의한 구성으로 정리해요

스낵을 유지하고 최근 대화는 최대 2개만 표시해요. `전체 보기`는 새 route를 push하지 않고 대화 탭으로 전환해요. 본문에 공간을 차지하는 `＋ 새 대화` 버튼을 배치하고, 중앙에 떠서 목록을 가리는 FAB를 제거해요. 최근 대화가 없거나 로딩·실패 상태여도 새 대화 버튼은 사용할 수 있어요. 기존 빈 상태 안의 시작 버튼과 새 버튼이 중복되지 않도록 해요.

주요 대상: `mobile/lib/features/home/presentation/home_screen.dart`, `mobile/lib/core/copy/`, 관련 최근 대화 위젯.

### 6. 새 대화·기존 대화의 복귀 경로를 연결해요

두 시작 버튼을 같은 선택 시트에 연결해요. 시트 취소는 출발 화면을 그대로 유지하고, 준비 과정 중 뒤로가기는 이전 준비 단계로 돌아가요. 생성 성공 시에는 준비 단계들을 제거하고 출발 탭 위에 대화 화면 하나를 남겨요. 준비 실패 시 입력과 선택을 유지해요. 생성 요청 도중 이탈했을 때 늦은 응답이 다른 탭을 덮지 않게 처리해요.

| 시작 위치 | 대화에서 뒤로가기 |
|---|---|
| 홈 최근 카드 또는 홈에서 새 대화 | 홈의 이전 위치 |
| 대화 목록 또는 대화 탭에서 새 대화 | 대화 목록의 이전 위치 |
| 출발 탭이 없는 기존 대화 직접 진입 | 대화 탭 |

주요 대상: router, `topic_input_screen.dart`, `topic_prep_screen.dart`, `roleplay_setup_screen.dart`, `conversation_screen.dart`, `conversation_start_sheet.dart`. 시트의 중복 손잡이도 이 단계에서 하나로 정리해요.

### 7. 시각적 마감·회귀 검증·문서를 마무리해요

세 탭을 같은 너비로 배치하고 라벨을 항상 표시해요. 라벨은 기본 UI 서체를 사용하고 선택 상태를 명확히 구분해요. 탭 전환에는 좌우 슬라이드를 추가하지 않아요. 버튼은 iOS 44pt/Android 48dp 이상 터치 영역, 하단 safe area와 긴 한글/영문 라벨을 확인해요. 기존 라이트 테마를 기반으로 마무리하며 다크 테마 지원을 완료했다고 선언하지 않아요.

관련 자동 검증을 각 단계에서 추가하고 마지막에 모바일 정적 분석·회귀 테스트를 실행해요. 실제 iOS Simulator/Android emulator에서 탭 전환, 준비·대화 복귀, 시트 취소, 키보드, 시스템 뒤로가기, 글자 확대를 확인해요. 전체 이동 흐름을 녹화해 관찰하고, release 성능 계측은 지원 기기에서 따로 수행해 증거 범위를 구분해요.

`mobile/README.md`, `.agent/architecture.md`, `docs/design/DESIGN_SYSTEM.md`의 탐색 구조·목록 범위·디자인 규칙을 같은 작업에서 갱신해요. 버전/변경 기록이 있는 문서는 함께 갱신해요. 예전 4탭 계획은 역사 문서로 유지하고 새 계획으로 연결해 현행 기준과 구분해요. 구현이 끝나면 본 문서의 결정을 기준 문서에 흡수하고 계획은 아카이브해요.

## 구현 완료 판단

- 홈 최근 2개와 전체 목록이 구분되고, 5개를 넘는 기존 대화도 목록에서 열 수 있어요.
- 탭을 오가도 스크롤·설정 표시가 유지되며 스낵 상태가 초기화되지 않아요.
- 홈과 대화의 시작 버튼은 같은 시트를 열고, 새 대화 후 뒤로가기에서 준비 화면이 재등장하지 않아요.
- 생성·삭제 후 홈과 전체 목록이 일치하며, 추가 조회 실패에도 이미 읽던 목록이 유지돼요.
- 기존 언어 변경·로그아웃·음성 입력·최신 메시지 진입 기능이 회귀하지 않아요.

검증 위치는 `mobile/test/app/app_test.dart`, 신규 router/shell 테스트, `mobile/test/features/home/presentation/home_screen_test.dart`, `mobile/test/features/history/`, 신규 profile 테스트, 기존 Topic Prep/Roleplay/Conversation 화면 테스트를 중심으로 잡아요.

## 근거

- 이 대화에서 합의한 3탭 구성 및 새 대화 버튼 역할.
- 기존 탐색의 역사: `docs/plans/2026-07-11-001-feat-mobile-main-navigation-plan.md`.
- 현재 서버 목록 계약: `backend/domains/conversation/router.py`의 `get_conversations`.
- [go_router StatefulShellRoute 공식 문서](https://pub.dev/documentation/go_router/latest/go_router/StatefulShellRoute-class.html): 탭별 Navigator 상태 유지와 애니메이션 없는 IndexedStack 구현. 최신 문서이므로 구현 시 현재 설치 버전과 대조해요.
