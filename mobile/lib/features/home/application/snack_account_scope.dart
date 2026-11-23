import 'package:flutter_riverpod/flutter_riverpod.dart';

class SnackAccountScope {
  const SnackAccountScope({
    required this.userId,
    required this.language,
    required this.widgetEnabled,
  });

  final String? userId;
  final String language;
  final bool widgetEnabled;
}

/// 테스트와 임베디드 화면이 계정 범위를 주입할 수 있는 안정적인 경계예요.
/// 앱에서는 null이며 각 소비자가 인증 세션을 직접 구독해요.
final Provider<SnackAccountScope?> snackAccountScopeProvider =
    Provider<SnackAccountScope?>((ref) => null);
