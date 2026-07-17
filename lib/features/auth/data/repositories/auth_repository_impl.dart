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
  
  // Local mock user stream and state for the default admin bypass
  final _mockUserStreamController = StreamController<UserModel?>.broadcast();
  UserModel? _mockUser;

  AuthRepositoryImpl({required AuthRemoteSource remoteSource}) : _remoteSource = remoteSource;

  @override
  Stream<UserModel?> get onAuthStateChanged {
    late StreamController<UserModel?> controller;
    StreamSubscription? sub1;
    StreamSubscription? sub2;

    controller = StreamController<UserModel?>.broadcast(
      onListen: () {
        if (_mockUser != null) {
          controller.add(_mockUser);
        }
        
        sub1 = _remoteSource.rawAuthStream.asyncMap((fbUser) async {
          if (_mockUser != null) return _mockUser;
          if (fbUser == null) return null;
          try {
            if (fbUser.phoneNumber == '+918586097283') {
              final mockAdmin = UserModel(
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
              _mockUser = mockAdmin;
              return mockAdmin;
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
        }).listen(
          (user) {
            if (_mockUser == null) {
              controller.add(user);
            }
          },
          onError: controller.addError,
        );

        sub2 = _mockUserStreamController.stream.listen(
          controller.add,
          onError: controller.addError,
        );
      },
      onCancel: () {
        sub1?.cancel();
        sub2?.cancel();
      },
    );

    return controller.stream;
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
        // Trigger mock codeSent immediately to bypass Firebase Auth API key requirement!
        onCodeSent('mock_verification_id_8586097283', null);
        return;
      }

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
      if (verificationId == 'mock_verification_id_8586097283') {
        // Mock sign in - create and return the mock Admin UserModel directly!
        final mockAdmin = UserModel(
          uid: 'mock_admin_uid_8586097283',
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
        _mockUser = mockAdmin;
        _mockUserStreamController.add(mockAdmin);
        return mockAdmin;
      }

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
        final mockAdmin = UserModel(
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
        _mockUser = mockAdmin;
        _mockUserStreamController.add(mockAdmin);
        return mockAdmin;
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
      _mockUser = null;
      _mockUserStreamController.add(null);
      await _remoteSource.rawSignOut();
    } catch (e) {
      throw ServerFailure('Exception occurred while attempting to terminate session: ${e.toString()}');
    }
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    try {
      if (_mockUser != null) return _mockUser;

      final fbUser = _remoteSource.currentRawUser;
      if (fbUser == null) return null;

      if (fbUser.phoneNumber == '+918586097283') {
        final mockAdmin = UserModel(
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
        _mockUser = mockAdmin;
        return mockAdmin;
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
