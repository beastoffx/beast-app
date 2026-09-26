import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  static const String webClientId =
      '303787781202-pi1snm4h30j4immc10npj9hj7ptp819n.apps.googleusercontent.com';

  static bool _initialized = false;

  static Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await GoogleSignIn.instance.initialize(
        clientId: kIsWeb ? webClientId : null,
        serverClientId: webClientId,
      );
      _initialized = true;
    }
  }

  static Future<GoogleSignInAccount?> signIn() async {
    try {
      await _ensureInitialized();
      final account = await GoogleSignIn.instance.authenticate(
        scopeHint: const ['email', 'profile', 'openid'],
      );
      return account;
    } catch (e) {
      debugPrint('[GoogleAuthService] Sign-in error: $e');
      return null;
    }
  }

  static Future<String?> getIdToken(GoogleSignInAccount account) async {
    try {
      return account.authentication.idToken;
    } catch (e) {
      debugPrint('[GoogleAuthService] getIdToken error: $e');
      return null;
    }
  }

  static Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (e) {
      debugPrint('[GoogleAuthService] Sign-out error: $e');
    }
  }
}
