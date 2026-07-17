import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sum_enterprises/core/constants/app_constants.dart';
import 'package:sum_enterprises/features/auth/domain/models/user_model.dart';

/// Low-level data source executing raw queries on Firebase Auth and Cloud Firestore.
/// Contains NO architectural error mapping; simply delivers raw payloads or bubbles up SDK exceptions.
class AuthRemoteSource {
  final fb.FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  AuthRemoteSource({
    fb.FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  })  : _firebaseAuth = firebaseAuth ?? fb.FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  /// Stream of raw firebase auth user emissions mapped to Firestore employee data
  Stream<fb.User?> get rawAuthStream => _firebaseAuth.authStateChanges();

  /// Fetch a complete employee document from Cloud Firestore using UID
  Future<Map<String, dynamic>?> fetchUserData(String uid) async {
    final docRef = _firestore.collection(AppConstants.collectionUsers).doc(uid);
    final docSnapshot = await docRef.get();
    return docSnapshot.data();
  }

  /// Fetch a complete employee document from Cloud Firestore using Phone Number
  Future<QueryDocumentSnapshot<Map<String, dynamic>>?> fetchUserDataByPhone(String phone) async {
    final querySnapshot = await _firestore
        .collection(AppConstants.collectionUsers)
        .where('phone', isEqualTo: phone)
        .limit(1)
        .get();
    if (querySnapshot.docs.isNotEmpty) {
      return querySnapshot.docs.first;
    }

    final querySnapshotAlt = await _firestore
        .collection(AppConstants.collectionUsers)
        .where('phoneNumber', isEqualTo: phone)
        .limit(1)
        .get();
    if (querySnapshotAlt.docs.isNotEmpty) {
      return querySnapshotAlt.docs.first;
    }

    return null;
  }

  /// Low level verification request
  Future<void> rawVerifyPhoneNumber({
    required String phoneNumber,
    required fb.PhoneVerificationCompleted verificationCompleted,
    required fb.PhoneVerificationFailed verificationFailed,
    required fb.PhoneCodeSent codeSent,
    required fb.PhoneCodeAutoRetrievalTimeout codeAutoRetrievalTimeout,
    int? forceResendingToken,
  }) async {
    await _firebaseAuth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
      forceResendingToken: forceResendingToken,
      timeout: const Duration(seconds: 60),
    );
  }

  /// Sign in with raw phone authentication credential
  Future<fb.UserCredential> rawSignInWithCredential(fb.AuthCredential credential) async {
    return await _firebaseAuth.signInWithCredential(credential);
  }

  /// Sign out
  Future<void> rawSignOut() async {
    await _firebaseAuth.signOut();
  }

  /// Get the current logged in Firebase User
  fb.User? get currentRawUser => _firebaseAuth.currentUser;
}
