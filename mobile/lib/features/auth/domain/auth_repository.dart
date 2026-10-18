import 'package:curitalk/features/auth/domain/user_profile.dart';

abstract interface class AuthRepository {
  Future<UserProfile> getCurrentUser();
}

abstract interface class AppLocaleRepository {
  Future<UserProfile> updateAppLocale(String appLocale);
}

abstract interface class NicknameRepository {
  Future<UserProfile> updateNickname(String nickname);
}
