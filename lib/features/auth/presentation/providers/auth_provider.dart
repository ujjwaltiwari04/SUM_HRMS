import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:sum_enterprises/core/constants/app_constants.dart';
import 'package:sum_enterprises/core/error/failures.dart';
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

/// Status representing the state of Auth UI actions.
enum AuthUIStatus {
  initial,
  loading,
  success,
  error,
}

/// Immutable state containing the reactive values for Email/Password authentication.
class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;
  final AuthUIStatus status;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
    this.status = AuthUIStatus.initial,
  });

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
    AuthUIStatus? status,
    bool clearError = false,
    bool clearSuccess = false,
    bool clearUser = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
      status: status ?? this.status,
    );
  }
}

/// Controller handling the side-effects of Email Authentication (sign in, password reset, logout).
class AuthController extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  StreamSubscription<UserModel?>? _authStateSubscription;

  AuthController({required AuthRepository repository})
      : _repository = repository,
        super(const AuthState()) {
    _initialize();
    checkStartupUserStatus();
  }

  /// Check if the user is deactivated at startup and update error state
  Future<void> checkStartupUserStatus() async {
    try {
      final currentUser = await _repository.currentUser();
      if (currentUser == null) {
        final rawUser = fb.FirebaseAuth.instance.currentUser;
        if (rawUser != null) {
          state = state.copyWith(
            errorMessage: AppConstants.accountDeactivatedMessage,
            status: AuthUIStatus.error,
          );
        }
      }
    } catch (_) {}
  }

  /// Synchronize the active UserModel into this state notifier's state
  void _initialize() {
    _authStateSubscription?.cancel();
    _authStateSubscription = _repository.onAuthStateChanged.listen((user) {
      state = state.copyWith(user: user, clearUser: user == null);
    });
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }

  /// Sign in with email and password
  Future<void> loginWithEmail(String email, String password) async {
    state = state.copyWith(status: AuthUIStatus.loading, isLoading: true, clearError: true);
    try {
      final user = await _repository.signInWithEmail(email: email, password: password);
      state = state.copyWith(
        user: user,
        status: AuthUIStatus.success,
        isLoading: false,
      );
    } catch (e) {
      final message = e is Failure ? e.message : e.toString().replaceFirst('Exception: ', '');
      state = state.copyWith(
        errorMessage: message,
        status: AuthUIStatus.error,
        isLoading: false,
      );
    }
  }

  /// Send password reset email
  Future<void> sendPasswordReset(String email) async {
    state = state.copyWith(status: AuthUIStatus.loading, isLoading: true, clearError: true, clearSuccess: true);
    try {
      await _repository.resetPassword(email);
      state = state.copyWith(
        status: AuthUIStatus.success,
        successMessage: 'Password reset email sent. Please check your inbox.',
        isLoading: false,
      );
    } catch (e) {
      final message = e is Failure ? e.message : e.toString().replaceFirst('Exception: ', '');
      state = state.copyWith(
        errorMessage: message,
        status: AuthUIStatus.error,
        isLoading: false,
      );
    }
  }

  /// Clear active error message
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Clear active success message
  void clearSuccess() {
    state = state.copyWith(clearSuccess: true);
  }

  /// Terminate the active session
  Future<void> logout() async {
    state = state.copyWith(status: AuthUIStatus.loading, isLoading: true);
    try {
      await _repository.signOut();
      state = const AuthState();
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Logout failed: ${e.toString()}',
        isLoading: false,
        status: AuthUIStatus.error,
      );
    }
  }
}

/// Primary controller provider for Email/Password Auth
final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthController(repository: repository);
});

/// Compatibility alias to support dashboard and other modules watching phoneAuthControllerProvider
final phoneAuthControllerProvider = authControllerProvider;
