import 'package:curitalk/core/network/network.dart';
import 'package:curitalk/core/storage/auth_tokens.dart';
import 'package:curitalk/features/auth/domain/auth_repository.dart';
import 'package:curitalk/features/auth/domain/user_profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ApiAuthRepository implements AuthRepository {
  const ApiAuthRepository(this.apiClient);

  final ApiClient apiClient;

  @override
  Future<AuthTokens> signInWithGoogleIdToken({
    required String idToken,
    required String deviceId,
  }) async {
    final ApiResponse<AuthTokens> response = await apiClient.post<AuthTokens>(
      'auth/google/mobile',
      requiresAuth: false,
      data: <String, String>{'id_token': idToken, 'device_id': deviceId},
      decodeData: AuthTokens.fromJson,
    );
    return response.data;
  }

  @override
  Future<UserProfile> getCurrentUser() async {
    final ApiResponse<UserProfile> response = await apiClient.get<UserProfile>(
      'auth/me',
      decodeData: UserProfile.fromJson,
    );
    return response.data;
  }

  @override
  Future<void> logout({
    required String refreshToken,
    required String deviceId,
  }) async {
    await apiClient.post<void>(
      'auth/logout',
      requiresAuth: false,
      data: <String, String>{
        'refresh_token': refreshToken,
        'device_id': deviceId,
      },
      decodeData: (_) {},
    );
  }
}

final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>((Ref ref) {
      return ApiAuthRepository(ref.watch(apiClientProvider));
    });
