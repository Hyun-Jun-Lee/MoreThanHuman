# Curitalk Mobile

관심사 기반 AI 영어 회화 앱 Curitalk의 Flutter iOS·Android 클라이언트예요.

## 확인

```bash
flutter pub get
flutter analyze
flutter test
```

## 플랫폼 설정

- Android application ID: `com.morethanhuman.curitalk`
- iOS bundle ID: `com.morethanhuman.curitalk`
- Android minimum SDK: 23
- 실제 실행 전 Android SDK 또는 Xcode/CocoaPods 설정이 필요해요.

## 기반 패키지

| 패키지 | 역할 |
|--------|------|
| `flutter_riverpod` | 앱 상태와 비동기 상태 관리 |
| `go_router` | 화면 라우팅과 인증 redirect |
| `dio` | FastAPI HTTP client와 interceptor |
| `flutter_secure_storage` | access/refresh token과 device ID 보관 |
| `google_sign_in` | Google 모바일 로그인 |

## 현재 구조

```text
lib/
├── main.dart
├── app/
│   ├── app.dart
│   ├── router/
│   │   └── app_router.dart
│   └── theme/
└── core/
    └── widgets/
```

기능별 폴더는 실제 화면 구현을 시작할 때 `features/` 아래에 추가해요.
