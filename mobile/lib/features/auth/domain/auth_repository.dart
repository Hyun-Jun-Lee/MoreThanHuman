import 'package:curitalk/features/auth/domain/user_profile.dart';

abstract interface class AuthRepository {
  Future<UserProfile> getCurrentUser();
}
