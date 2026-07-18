import 'package:sum_enterprises/features/auth/domain/models/user_model.dart';

/// Contract interface defining the boundaries of SUM Enterprises authentication capabilities.
/// De-couples the presentation logic from specific client SDKs (like Firebase or REST API).
abstract class AuthRepository {
  /// Stream that emits the authenticated UserModel? whenever state changes.
  Stream<UserModel?> get onAuthStateChanged;

  /// Sign in with Email and Password.
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  });

  /// Request session termination from the auth provider.
  Future<void> signOut();

  /// Send password reset email.
  Future<void> resetPassword(String email);

  /// Retrieve the current authenticated user's record from database.
  Future<UserModel?> currentUser();
}
