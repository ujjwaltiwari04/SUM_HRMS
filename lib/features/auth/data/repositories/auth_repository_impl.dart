import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:sum_enterprises/core/error/failures.dart';
import 'package:sum_enterprises/features/auth/data/sources/auth_remote_source.dart';
import 'package:sum_enterprises/features/auth/domain/models/user_model.dart';
import 'package:sum_enterprises/features/auth/domain/repositories/auth_repository.dart';

/// Implementation of the [AuthRepository] interface.
/// Integrates the [AuthRemoteSource], catching raw SDK exceptions and mapping them to typed domain [Failure]s.
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteSource _remoteSource;

  AuthRepositoryImpl({required AuthRemoteSource remoteSource}) : _remoteSource = remoteSource;

  @override
  Stream<UserModel?> get onAuthStateChanged {
    return _remoteSource.rawAuthStream.asyncMap((fbUser) async {
      if (fbUser == null) return null;
      try {
        final userData = await _remoteSource.fetchUserData(fbUser.uid);

        if (userData == null) {
          await _remoteSource.rawSignOut();
          return null;
        }

        final userModel = UserModel.fromMap(userData, fbUser.uid);
        if (!userModel.isActive) {
          await _remoteSource.rawSignOut();
          return null;
        }
        return userModel;
      } catch (e) {
        return null;
      }
    });
  }

  @override
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _remoteSource.rawSignInWithEmail(
        email: email,
        password: password,
      );
      final fbUser = userCredential.user;
      if (fbUser == null) {
        throw const AuthFailure('Authentication resulted in an empty session.');
      }

      final userData = await _remoteSource.fetchUserData(fbUser.uid);
      if (userData == null) {
        await _remoteSource.rawSignOut();
        throw const AuthFailure(
          'Your account is not authorized. Please contact the administrator.',
          code: 'unauthorized',
        );
      }

      final userModel = UserModel.fromMap(userData, fbUser.uid);
      if (!userModel.isActive) {
        await _remoteSource.rawSignOut();
        throw const AuthFailure(
          'Your corporate account has been deactivated. Please contact the administrator.',
          code: 'deactivated',
        );
      }

      return userModel;
    } on fb.FirebaseAuthException catch (e) {
      String errorMessage = 'Failed to sign in.';
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential' || e.code == 'invalid-email') {
        errorMessage = 'Invalid email or password.';
      } else if (e.code == 'user-disabled') {
        errorMessage = 'This user account has been disabled.';
      } else if (e.code == 'too-many-requests') {
        errorMessage = 'Too many failed login attempts. Please try again later.';
      } else if (e.message != null) {
        errorMessage = e.message!;
      }
      throw AuthFailure(errorMessage, code: e.code);
    } catch (e) {
      if (e is Failure) rethrow;
      throw ServerFailure('An unexpected error occurred during sign in: ${e.toString()}');
    }
  }

  @override
  Future<void> resetPassword(String email) async {
    try {
      await _remoteSource.rawSendPasswordResetEmail(email: email);
    } on fb.FirebaseAuthException catch (e) {
      String errorMessage = 'Failed to send password reset email.';
      if (e.code == 'invalid-email') {
        errorMessage = 'The email address is badly formatted.';
      } else if (e.code == 'user-not-found') {
        errorMessage = 'No user found with this email address.';
      } else if (e.message != null) {
        errorMessage = e.message!;
      }
      throw AuthFailure(errorMessage, code: e.code);
    } catch (e) {
      throw ServerFailure('An unexpected error occurred during password reset: ${e.toString()}');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _remoteSource.rawSignOut();
    } catch (e) {
      throw ServerFailure('Exception occurred while attempting to terminate session: ${e.toString()}');
    }
  }

  @override
  Future<UserModel?> currentUser() async {
    try {
      final fbUser = _remoteSource.currentRawUser;
      if (fbUser == null) return null;

      final userData = await _remoteSource.fetchUserData(fbUser.uid);
      if (userData == null) {
        await _remoteSource.rawSignOut();
        return null;
      }

      final user = UserModel.fromMap(userData, fbUser.uid);
      if (!user.isActive) {
        await _remoteSource.rawSignOut();
        return null;
      }
      return user;
    } catch (e) {
      throw ServerFailure('Failed to fetch the currently authenticated user profile.');
    }
  }
}
