import 'package:sum_enterprises/core/error/failures.dart';
import 'package:sum_enterprises/features/auth/domain/models/user_model.dart';

/// Contract interface defining the boundaries of SUM Enterprises authentication capabilities.
/// De-couples the presentation logic from specific client SDKs (like Firebase or REST API).
abstract class AuthRepository {
  /// Stream that emits the authenticated UserModel? whenever state changes.
  Stream<UserModel?> get onAuthStateChanged;

  /// Starts phone verification by sending OTP to the provided phone number.
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(Failure failure) onVerificationFailed,
  });

  /// Completes Phone OTP sign-in.
  Future<UserModel> signInWithPhoneNumber({
    required String verificationId,
    required String smsCode,
  });

  /// Request session termination from the auth provider.
  Future<void> signOut();

  /// Retrieve the current authenticated user's record from database.
  Future<UserModel?> getCurrentUser();
}
