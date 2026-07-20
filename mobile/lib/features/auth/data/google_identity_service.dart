import 'dart:convert';

import 'package:curitalk/core/config/app_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

abstract interface class GoogleIdentityService {
  Future<GoogleIdentityTokens?> signIn();

  Future<void> signOut();
}

class GoogleIdentityTokens {
  const GoogleIdentityTokens({
    required this.idToken,
    required this.accessToken,
  });

  final String idToken;
  final String accessToken;
}

class GoogleSignInIdentityService implements GoogleIdentityService {
  GoogleSignInIdentityService({GoogleSignIn? googleSignIn})
    : _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final GoogleSignIn _googleSignIn;
  Future<void>? _initialization;
  static const List<String> _scopes = <String>['openid', 'email', 'profile'];

  @override
  Future<GoogleIdentityTokens?> signIn() async {
    try {
      debugPrint('CuritalkAuth Google sign-in: initializing');
      await _initialize();
      if (!_googleSignIn.supportsAuthenticate()) {
        throw const GoogleIdentityException(
          'Google Sign-In is not supported on this platform.',
        );
      }
      debugPrint('CuritalkAuth Google sign-in: requesting account');
      final GoogleSignInAccount account = await _googleSignIn.authenticate();
      final String? idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const GoogleIdentityException(
          'Google did not return an identity token.',
        );
      }
      _debugIdentityToken(idToken);
      final GoogleSignInClientAuthorization authorization =
          await account.authorizationClient.authorizationForScopes(_scopes) ??
          await account.authorizationClient.authorizeScopes(_scopes);
      final String accessToken = authorization.accessToken;
      if (accessToken.isEmpty) {
        throw const GoogleIdentityException(
          'Google did not return an access token.',
        );
      }
      debugPrint(
        'CuritalkAuth Google sign-in: tokens received '
        'idTokenLength=${idToken.length} accessTokenLength=${accessToken.length}',
      );
      return GoogleIdentityTokens(idToken: idToken, accessToken: accessToken);
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled ||
          error.code == GoogleSignInExceptionCode.interrupted) {
        debugPrint('CuritalkAuth Google sign-in: cancelled by user');
        return null;
      }
      debugPrint(
        'CuritalkAuth Google sign-in failed: '
        'code=${error.code.name} description=${error.description}',
      );
      throw GoogleIdentityException(
        error.description ?? 'Google Sign-In could not be completed.',
      );
    } on Object catch (error, stackTrace) {
      debugPrint('CuritalkAuth Google sign-in failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> _initialize() async {
    try {
      await (_initialization ??= _googleSignIn.initialize(
        clientId: AppConfig.optionalGoogleClientId,
        serverClientId: AppConfig.optionalGoogleServerClientId,
      ));
      debugPrint(
        'CuritalkAuth Google sign-in: initialized '
        'clientIdSet=${AppConfig.optionalGoogleClientId != null} '
        'serverClientIdSet=${AppConfig.optionalGoogleServerClientId != null}',
      );
    } on Object {
      _initialization = null;
      rethrow;
    }
  }

  void _debugIdentityToken(String idToken) {
    try {
      final List<String> parts = idToken.split('.');
      if (parts.length < 2) {
        debugPrint('CuritalkAuth Google idToken: malformed JWT');
        return;
      }
      final String normalizedPayload = base64Url.normalize(parts[1]);
      final Object? decoded = jsonDecode(
        utf8.decode(base64Url.decode(normalizedPayload)),
      );
      if (decoded is! Map<String, Object?>) {
        debugPrint('CuritalkAuth Google idToken: payload is not an object');
        return;
      }
      debugPrint(
        'CuritalkAuth Google idToken claims: '
        'aud=${decoded['aud']} azp=${decoded['azp']} '
        'iss=${decoded['iss']} email=${decoded['email']}',
      );
    } on Object catch (error) {
      debugPrint('CuritalkAuth Google idToken debug decode failed: $error');
    }
  }

  @override
  Future<void> signOut() async {
    await _initialize();
    await _googleSignIn.signOut();
  }
}

class GoogleIdentityException implements Exception {
  const GoogleIdentityException(this.message);

  final String message;

  @override
  String toString() => message;
}

final Provider<GoogleIdentityService> googleIdentityServiceProvider =
    Provider<GoogleIdentityService>((Ref ref) {
      return GoogleSignInIdentityService();
    });
