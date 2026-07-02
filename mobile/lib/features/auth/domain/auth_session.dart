import 'package:curitalk/features/auth/domain/user_profile.dart';

enum AuthStatus { authenticated, unauthenticated }

class AuthSession {
  const AuthSession._({required this.status, this.user});

  const AuthSession.authenticated(UserProfile user)
    : this._(status: AuthStatus.authenticated, user: user);

  const AuthSession.unauthenticated()
    : this._(status: AuthStatus.unauthenticated);

  final AuthStatus status;
  final UserProfile? user;

  bool get isAuthenticated => status == AuthStatus.authenticated;
}
