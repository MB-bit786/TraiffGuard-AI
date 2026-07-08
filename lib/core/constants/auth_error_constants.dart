class AuthErrorConstants {
  AuthErrorConstants._();

  static const String defaultError = 'Connection failure. Please try again later.';
  static const String emailInUse = '⚠️ This email address is already registered to a corporate account.';
  static const String invalidCredentials = '❌ Invalid email or password credentials. Please try again.';
  static const String weakPassword = '⚠️ Password must be stronger. Use letters, numbers, and symbols.';
  static const String networkFailed = '🌐 System offline. Check your network infrastructure.';

  static String getMessage(String errorCode) {
    switch (errorCode) {
      case 'email-already-in-use':
        return emailInUse;
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
      case 'invalid-email':
        return invalidCredentials;
      case 'weak-password':
        return weakPassword;
      case 'network-request-failed':
        return networkFailed;
      default:
        return defaultError;
    }
  }
}
