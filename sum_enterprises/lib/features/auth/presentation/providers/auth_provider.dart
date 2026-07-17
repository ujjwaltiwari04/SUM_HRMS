import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sum_enterprises/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:sum_enterprises/features/auth/data/sources/auth_remote_source.dart';
import 'package:sum_enterprises/features/auth/domain/models/user_model.dart';
import 'package:sum_enterprises/features/auth/domain/repositories/auth_repository.dart';

/// Provider exposing the decoupled [AuthRemoteSource].
final authRemoteSourceProvider = Provider<AuthRemoteSource>((ref) {
  return AuthRemoteSource();
});

/// Dependency Injection provider for our [AuthRepository] implementation.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final remoteSource = ref.watch(authRemoteSourceProvider);
  return AuthRepositoryImpl(remoteSource: remoteSource);
});

/// StreamProvider that tracks the active authentication session.
/// The App Router and top-level widgets listen to this stream to respond immediately to auth state changes.
final authProvider = StreamProvider<UserModel?>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  return authRepo.onAuthStateChanged;
});

/// Step enum for phone authentication flow tracking.
enum PhoneAuthStep {
  enteringPhone,
  enteringOtp,
  verified,
}

/// Immutable state containing the reactive values for the Phone OTP flow.
class PhoneAuthState {
  final PhoneAuthStep step;
  final String phoneNumber;
  final String verificationId;
  final int? resendToken;
  final bool isLoading;
  final String? errorMessage;
  final UserModel? user;

  const PhoneAuthState({
    this.step = PhoneAuthStep.enteringPhone,
    this.phoneNumber = '',
    this.verificationId = '',
    this.resendToken,
    this.isLoading = false,
    this.errorMessage,
    this.user,
  });

  PhoneAuthState copyWith({
    PhoneAuthStep? step,
    String? phoneNumber,
    String? verificationId,
    int? resendToken,
    bool? isLoading,
    String? errorMessage,
    UserModel? user,
    bool clearError = false,
  }) {
    return PhoneAuthState(
      step: step ?? this.step,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      verificationId: verificationId ?? this.verificationId,
      resendToken: resendToken ?? this.resendToken,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      user: user ?? this.user,
    );
  }
}

/// Controller handling the side-effects of Phone Auth (sending code, verifying code, sign out).
class PhoneAuthController extends StateNotifier<PhoneAuthState> {
  final AuthRepository _repository;

  PhoneAuthController({required AuthRepository repository})
      : _repository = repository,
        super(const PhoneAuthState()) {
    _initialize();
  }

  /// Initial user state sync
  Future<void> _initialize() async {
    try {
      final user = await _repository.getCurrentUser();
      if (user != null) {
        state = state.copyWith(
          user: user,
          step: PhoneAuthStep.verified,
        );
      }
    } catch (_) {
      // Graceful fallback
    }
  }

  /// Initiate phone verification by sending OTP
  Future<void> sendOtp(String phone) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      phoneNumber: phone,
    );

    await _repository.verifyPhoneNumber(
      phoneNumber: phone,
      onCodeSent: (verificationId, resendToken) {
        state = state.copyWith(
          verificationId: verificationId,
          resendToken: resendToken,
          step: PhoneAuthStep.enteringOtp,
          isLoading: false,
        );
      },
      onVerificationFailed: (failure) {
        state = state.copyWith(
          errorMessage: failure.message,
          isLoading: false,
        );
      },
    );
  }

  /// Verify entered 6-digit OTP code
  Future<void> verifyOtp(String smsCode) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _repository.signInWithPhoneNumber(
        verificationId: state.verificationId,
        smsCode: smsCode,
      );
      state = state.copyWith(
        user: user,
        step: PhoneAuthStep.verified,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
        isLoading: false,
      );
    }
  }

  /// Go back to phone number entry step
  void resetToPhoneEntry() {
    state = state.copyWith(
      step: PhoneAuthStep.enteringPhone,
      clearError: true,
    );
  }

  /// Clear the active error message
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Terminate the active authenticated session
  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    try {
      await _repository.signOut();
      state = const PhoneAuthState();
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Logout failed: ${e.toString()}',
        isLoading: false,
      );
    }
  }
}

/// Provider exposing the [PhoneAuthController] for the login and dashboard views.
final phoneAuthControllerProvider = StateNotifierProvider<PhoneAuthController, PhoneAuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return PhoneAuthController(repository: repository);
});
