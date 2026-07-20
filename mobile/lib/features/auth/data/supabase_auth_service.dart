import 'dart:async';

import 'package:curitalk/core/config/app_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class AccessTokenProvider {
  Future<String?> readAccessToken();
}

abstract interface class SessionRefreshProvider {
  Future<String?> refreshAccessToken({required String? previousAccessToken});

  Future<void> expireSession();
}

enum SupabaseSessionEvent {
  initialSession,
  signedIn,
  signedOut,
  tokenRefreshed,
  userUpdated,
  error,
}

class SupabaseSessionChange {
  const SupabaseSessionChange({
    required this.event,
    required this.hasSession,
    this.error,
  });

  final SupabaseSessionEvent event;
  final bool hasSession;
  final Object? error;
}

abstract interface class SupabaseAuthService
    implements AccessTokenProvider, SessionRefreshProvider {
  Stream<SupabaseSessionChange> get authStateChanges;

  Future<bool> hasCurrentSession();

  Future<void> signInWithGoogleTokens({
    required String idToken,
    required String accessToken,
  });

  Future<void> signOut();
}

class SupabaseFlutterAuthService implements SupabaseAuthService {
  SupabaseFlutterAuthService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Stream<SupabaseSessionChange> get authStateChanges async* {
    try {
      await for (final AuthState state in _client.auth.onAuthStateChange) {
        yield SupabaseSessionChange(
          event: _mapEvent(state.event),
          hasSession: state.session != null,
        );
      }
    } on Object catch (error) {
      yield SupabaseSessionChange(
        event: SupabaseSessionEvent.error,
        hasSession: _client.auth.currentSession != null,
        error: error,
      );
    }
  }

  @override
  Future<bool> hasCurrentSession() async {
    return _client.auth.currentSession != null;
  }

  @override
  Future<String?> readAccessToken() async {
    return _client.auth.currentSession?.accessToken;
  }

  @override
  Future<void> signInWithGoogleTokens({
    required String idToken,
    required String accessToken,
  }) async {
    try {
      debugPrint(
        'CuritalkAuth Supabase sign-in: starting '
        'supabaseUrlSet=${AppConfig.supabaseUrl.trim().isNotEmpty} '
        'idTokenLength=${idToken.length} '
        'accessTokenLength=${accessToken.length}',
      );
      final AuthResponse response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
      debugPrint(
        'CuritalkAuth Supabase sign-in: success '
        'hasSession=${response.session != null} userId=${response.user?.id}',
      );
    } on AuthException catch (error, stackTrace) {
      debugPrint(
        'CuritalkAuth Supabase sign-in failed: '
        'message=${error.message} status=${error.statusCode} code=${error.code}',
      );
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    } on Object catch (error, stackTrace) {
      debugPrint('CuritalkAuth Supabase sign-in failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<String?> refreshAccessToken({
    required String? previousAccessToken,
  }) async {
    final Session? session = _client.auth.currentSession;
    if (session == null) {
      return null;
    }
    if (session.accessToken != previousAccessToken) {
      return session.accessToken;
    }
    final AuthResponse response = await _client.auth.refreshSession();
    return response.session?.accessToken;
  }

  @override
  Future<void> expireSession() async {
    await signOut();
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  SupabaseSessionEvent _mapEvent(AuthChangeEvent event) {
    return switch (event) {
      AuthChangeEvent.initialSession => SupabaseSessionEvent.initialSession,
      AuthChangeEvent.signedIn => SupabaseSessionEvent.signedIn,
      AuthChangeEvent.signedOut => SupabaseSessionEvent.signedOut,
      AuthChangeEvent.tokenRefreshed => SupabaseSessionEvent.tokenRefreshed,
      AuthChangeEvent.userUpdated => SupabaseSessionEvent.userUpdated,
      _ => SupabaseSessionEvent.userUpdated,
    };
  }
}

final Provider<SupabaseAuthService> supabaseAuthServiceProvider =
    Provider<SupabaseAuthService>((Ref ref) {
      return SupabaseFlutterAuthService();
    });

final Provider<AccessTokenProvider> accessTokenProvider =
    Provider<AccessTokenProvider>((Ref ref) {
      return ref.watch(supabaseAuthServiceProvider);
    });

final Provider<SessionRefreshProvider> sessionRefreshProvider =
    Provider<SessionRefreshProvider>((Ref ref) {
      return ref.watch(supabaseAuthServiceProvider);
    });
