import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sum_enterprises/core/constants/app_constants.dart';

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

  /// Sign in with email and password
  Future<fb.UserCredential> rawSignInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Send password reset email
  Future<void> rawSendPasswordResetEmail({required String email}) async {
    await _firebaseAuth.sendPasswordResetEmail(email: email);
  }

  /// Sign out
  Future<void> rawSignOut() async {
    await _firebaseAuth.signOut();
  }

  /// Get the current logged in Firebase User
  fb.User? get currentRawUser => _firebaseAuth.currentUser;
}
