import 'package:curitalk/features/language/language.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.name,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.language = LearningLanguageContext.defaultContext,
    this.appLocale,
    this.oauthProvider,
  });

  factory UserProfile.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('User profile must be a JSON object.');
    }

    final Object? id = json['id'];
    final Object? email = json['email'];
    final Object? name = json['name'];
    final Object? isActive = json['is_active'];
    final Object? oauthProvider = json['oauth_provider'];
    final Object? appLocale = json['app_locale'];
    final DateTime? createdAt = DateTime.tryParse('${json['created_at']}');
    final DateTime? updatedAt = DateTime.tryParse('${json['updated_at']}');
    if (id is! String || id.isEmpty) {
      throw const FormatException('User profile id is missing.');
    }
    if (email is! String || email.isEmpty) {
      throw const FormatException('User profile email is missing.');
    }
    if (name is! String || name.isEmpty) {
      throw const FormatException('User profile name is missing.');
    }
    if (isActive is! bool) {
      throw const FormatException('User profile active state is invalid.');
    }
    if (oauthProvider != null && oauthProvider is! String) {
      throw const FormatException('User profile OAuth provider is invalid.');
    }
    if (appLocale != null && appLocale is! String) {
      throw const FormatException('User profile app locale is invalid.');
    }
    if (appLocale != null && appLocale != 'ko' && appLocale != 'en') {
      throw const FormatException('User profile app locale is unsupported.');
    }
    if (createdAt == null || updatedAt == null) {
      throw const FormatException('User profile timestamp is invalid.');
    }

    return UserProfile(
      id: id,
      email: email,
      name: name,
      isActive: isActive,
      oauthProvider: oauthProvider as String?,
      appLocale: appLocale as String?,
      language: LearningLanguageContext.fromJson(json['language']),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  final String id;
  final String email;
  final String name;
  final bool isActive;
  final String? oauthProvider;
  final String? appLocale;
  final LearningLanguageContext language;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfile copyWith({String? appLocale}) {
    return UserProfile(
      id: id,
      email: email,
      name: name,
      isActive: isActive,
      oauthProvider: oauthProvider,
      language: language,
      appLocale: appLocale ?? this.appLocale,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
