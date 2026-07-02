import 'package:curitalk/core/storage/auth_tokens.dart';
import 'package:curitalk/features/auth/domain/user_profile.dart';

abstract interface class AuthRepository {
  Future<AuthTokens> signInWithGoogleIdToken({
    required String idToken,
    required String deviceId,
  });

  Future<UserProfile> getCurrentUser();

  Future<void> logout({required String refreshToken, required String deviceId});
}
