---
title: Mobile Chat and Subscription UI Fixes
type: fix
date: 2026-11-23
execution: code
---

# Mobile Chat and Subscription UI Fixes

## 목표

대화 작성기, FreeChat 주제 입력, 구독 화면의 현재 상태를 사용자가 보는 표시와 일치시켜요.

## 결정

- 대화 작성기의 보내기 화살표는 활성·비활성 상태 모두 원형 배경 없이 표시하고, 터치 영역과 접근성 tooltip은 유지해요.
- 구독 화면은 권한 조회가 완료되면 실제 `Free`·`Advance`·`Plus` 플랜을 처음 선택해요. 이후 사용자가 고른 유료 플랜은 재빌드가 덮어쓰지 않아요.
- FreeChat 입력창 위의 `하고 싶은 이야기로 대화해봐요` 설명은 제거하고 같은 문구를 입력 힌트로 옮겨요. 기존 `나누고 싶은 주제는 무엇인가요?` 문구는 제거해요.
- 추천 영역 제목은 `빠르게 골라보세요`로 바꿔요. 추천 카드를 고르면 입력값과 선택 상태를 함께 설정하고, 사용자가 입력창을 터치하면 입력값은 유지한 채 카드 선택 상태만 해제해요.

## 구현 범위

- `mobile/lib/features/conversation/presentation/widgets/chat_composer.dart`
- `mobile/lib/features/billing/paywall_screen.dart`
- `mobile/lib/features/topic_prep/presentation/topic_input_screen.dart`
- `mobile/lib/core/copy/app_copy.dart`
- 각 화면의 기존 Flutter 위젯 테스트

## 검증

- `conversation_widgets_test.dart`
- `paywall_screen_test.dart`
- `topic_input_screen_test.dart`
- `flutter analyze --no-pub`
