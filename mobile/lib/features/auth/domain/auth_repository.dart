import 'package:curitalk/features/auth/domain/user_profile.dart';
import 'package:curitalk/features/language/domain/learning_language.dart';

abstract interface class AuthRepository {
  Future<UserProfile> bootstrap(LearningLanguageContext? pendingLanguage);
  Future<UserProfile> getCurrentUser();
}

abstract interface class AppLocaleRepository {
  Future<UserProfile> updateAppLocale(String appLocale);
}

abstract interface class NicknameRepository {
  Future<UserProfile> updateNickname(String nickname);
}
