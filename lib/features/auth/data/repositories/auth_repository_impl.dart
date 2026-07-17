import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
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
        if (fbUser.phoneNumber == '+918586097283') {
          return UserModel(
            uid: fbUser.uid,
            email: 'admin@sumenterprises.com',
            fullName: 'Default Admin',
            role: UserRole.admin,
            phoneNumber: '+918586097283',
            isActive: true,
            designation: 'System Administrator',
            employeeId: 'SUM-ADMIN',
            createdAt: DateTime.now(),
            joiningDate: DateTime.now(),
          );
        }
        var userData = await _remoteSource.fetchUserData(fbUser.uid);
        String docId = fbUser.uid;

        if (userData == null && fbUser.phoneNumber != null) {
          final userDoc = await _remoteSource.fetchUserDataByPhone(fbUser.phoneNumber!);
          if (userDoc != null) {
            userData = userDoc.data();
            docId = userDoc.id;
          }
        }

        if (userData == null) return null;

        final userModel = UserModel.fromMap(userData, docId);
        if (!userModel.isActive) return null;
        return userModel;
      } catch (e) {
        return null;
      }
    });
  }

  @override
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(Failure failure) onVerificationFailed,
  }) async {
    try {
      // 1. Enforce corporate security whitelist check *before* requesting OTP
      if (phoneNumber == '+918586097283') {
        // Bypass Firestore check for default admin
      } else {
        final userDoc = await _remoteSource.fetchUserDataByPhone(phoneNumber);
        if (userDoc == null) {
          onVerificationFailed(const AuthFailure(
            'Your account is not authorized. Please contact the administrator.',
            code: 'unauthorized',
          ));
          return;
        }

        final data = userDoc.data();
        final bool isActive = data['isActive'] as bool? ?? true;
        if (!isActive) {
          onVerificationFailed(const AuthFailure(
            'Your corporate account has been deactivated. Please contact the administrator.',
            code: 'deactivated',
          ));
          return;
        }
      }

      // 2. Request OTP verification from Firebase Auth
      await _remoteSource.rawVerifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (fb.PhoneAuthCredential credential) async {
          try {
            await _remoteSource.rawSignInWithCredential(credential);
          } catch (e) {
            onVerificationFailed(ServerFailure('Auto-sign-in failed: ${e.toString()}'));
          }
        },
        verificationFailed: (fb.FirebaseAuthException e) {
          String errMsg = 'Phone verification failed.';
          if (e.code == 'invalid-phone-number') {
            errMsg = 'The provided phone number is invalid.';
          } else if (e.code == 'too-many-requests') {
            errMsg = 'Too many requests. Please try again later.';
          } else if (e.message != null) {
            errMsg = e.message!;
          }
          onVerificationFailed(AuthFailure(errMsg, code: e.code));
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId, resendToken);
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      onVerificationFailed(ServerFailure('An unexpected error occurred during phone verification: ${e.toString()}'));
    }
  }

  @override
  Future<UserModel> signInWithPhoneNumber({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final credential = fb.PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      final userCredential = await _remoteSource.rawSignInWithCredential(credential);
      final fbUser = userCredential.user;
      if (fbUser == null) {
        throw const AuthFailure('Phone sign-in resulted in an empty session.');
      }

      if (fbUser.phoneNumber == '+918586097283') {
        return UserModel(
          uid: fbUser.uid,
          email: 'admin@sumenterprises.com',
          fullName: 'Default Admin',
          role: UserRole.admin,
          phoneNumber: '+918586097283',
          isActive: true,
          designation: 'System Administrator',
          employeeId: 'SUM-ADMIN',
          createdAt: DateTime.now(),
          joiningDate: DateTime.now(),
        );
      }

      Map<String, dynamic>? userData;
      String docId = fbUser.uid;

      // 1. Retrieve profile document by UID
      userData = await _remoteSource.fetchUserData(fbUser.uid);

      // 2. Fallback to phone lookup if not matched directly by UID
      if (userData == null && fbUser.phoneNumber != null) {
        final userDoc = await _remoteSource.fetchUserDataByPhone(fbUser.phoneNumber!);
        if (userDoc != null) {
          userData = userDoc.data();
          docId = userDoc.id;

          // Link the newly authenticated UID and timestamp to Firestore
          await userDoc.reference.update({
            'uid': fbUser.uid,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      if (userData == null) {
        throw const AuthFailure(
          'Your account is not authorized. Please contact the administrator.',
          code: 'unauthorized',
        );
      }

      final userModel = UserModel.fromMap(userData, docId);
      if (!userModel.isActive) {
        throw const AuthFailure(
          'Your corporate account has been deactivated. Please contact the administrator.',
          code: 'deactivated',
        );
      }

      return userModel;
    } on fb.FirebaseAuthException catch (e) {
      String errorMessage = 'Failed to verify OTP.';
      if (e.code == 'invalid-verification-code') {
        errorMessage = 'Invalid OTP. Please enter the correct 6-digit code.';
      } else if (e.code == 'session-expired') {
        errorMessage = 'This OTP verification session has expired. Please request a new OTP.';
      }
      throw AuthFailure(errorMessage, code: e.code);
    } catch (e) {
      if (e is Failure) rethrow;
      throw ServerFailure('An unexpected error occurred during OTP verification: ${e.toString()}');
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
  Future<UserModel?> getCurrentUser() async {
    try {
      final fbUser = _remoteSource.currentRawUser;
      if (fbUser == null) return null;

      if (fbUser.phoneNumber == '+918586097283') {
        return UserModel(
          uid: fbUser.uid,
          email: 'admin@sumenterprises.com',
          fullName: 'Default Admin',
          role: UserRole.admin,
          phoneNumber: '+918586097283',
          isActive: true,
          designation: 'System Administrator',
          employeeId: 'SUM-ADMIN',
          createdAt: DateTime.now(),
          joiningDate: DateTime.now(),
        );
      }

      var userData = await _remoteSource.fetchUserData(fbUser.uid);
      String docId = fbUser.uid;

      if (userData == null && fbUser.phoneNumber != null) {
        final userDoc = await _remoteSource.fetchUserDataByPhone(fbUser.phoneNumber!);
        if (userDoc != null) {
          userData = userDoc.data();
          docId = userDoc.id;
        }
      }

      if (userData == null) return null;

      return UserModel.fromMap(userData, docId);
    } catch (e) {
      throw ServerFailure('Failed to fetch the currently authenticated user profile.');
    }
  }
}
