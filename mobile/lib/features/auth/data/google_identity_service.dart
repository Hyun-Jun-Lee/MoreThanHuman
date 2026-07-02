import 'package:curitalk/core/config/app_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

abstract interface class GoogleIdentityService {
  Future<String?> signIn();

  Future<void> signOut();
}

class GoogleSignInIdentityService implements GoogleIdentityService {
  GoogleSignInIdentityService({GoogleSignIn? googleSignIn})
    : _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final GoogleSignIn _googleSignIn;
  Future<void>? _initialization;

  @override
  Future<String?> signIn() async {
    try {
      await _initialize();
      if (!_googleSignIn.supportsAuthenticate()) {
        throw const GoogleIdentityException(
          'Google Sign-In is not supported on this platform.',
        );
      }
      final GoogleSignInAccount account = await _googleSignIn.authenticate();
      final String? idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const GoogleIdentityException(
          'Google did not return an identity token.',
        );
      }
      return idToken;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled ||
          error.code == GoogleSignInExceptionCode.interrupted) {
        return null;
      }
      throw GoogleIdentityException(
        error.description ?? 'Google Sign-In could not be completed.',
      );
    }
  }

  Future<void> _initialize() async {
    try {
      await (_initialization ??= _googleSignIn.initialize(
        clientId: AppConfig.optionalGoogleClientId,
        serverClientId: AppConfig.optionalGoogleServerClientId,
      ));
    } on Object {
      _initialization = null;
      rethrow;
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
