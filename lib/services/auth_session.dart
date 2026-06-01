import '../models/user_profile.dart';

/// In-memory auth state for the current app session.
class AuthSession {
  AuthSession._();

  static String? accessToken;
  static UserProfile? profile;

  static bool get isLoggedIn => accessToken != null && accessToken!.isNotEmpty;

  static String? get userEmail => profile?.email;

  static void setSession({required String token, required UserProfile userProfile}) {
    accessToken = token;
    profile = userProfile;
  }

  static void clear() {
    accessToken = null;
    profile = null;
  }
}
