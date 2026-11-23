import 'package:curitalk/features/auth/domain/user_profile.dart';

enum AuthStatus { member, guest, unauthenticated }

class AuthSession {
  const AuthSession._({required this.status, this.user});

  const AuthSession.member(UserProfile user)
    : this._(status: AuthStatus.member, user: user);

  const AuthSession.guest(UserProfile user)
    : this._(status: AuthStatus.guest, user: user);

  factory AuthSession.fromProfile(UserProfile user) =>
      user.isGuest ? AuthSession.guest(user) : AuthSession.member(user);

  const AuthSession.unauthenticated()
    : this._(status: AuthStatus.unauthenticated);

  final AuthStatus status;
  final UserProfile? user;

  bool get isAuthenticated =>
      status == AuthStatus.member || status == AuthStatus.guest;
  bool get isMember => status == AuthStatus.member;
  bool get isGuest => status == AuthStatus.guest;
}
