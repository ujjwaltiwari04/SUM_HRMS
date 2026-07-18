import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sum_enterprises/core/constants/app_constants.dart';

/// Reusable validation guard to check active user account status.
/// Prevents deactivated employees from executing backend processes.
class AccountStatusGuard {
  final FirebaseFirestore _firestore;

  AccountStatusGuard({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Queries the users database reference.
  /// If the account is deactivated (isActive == false), signs out of Firebase immediately
  /// and throws a standard deactivated account exception.
  Future<void> validateActiveStatus(String uid) async {
    if (uid.isEmpty) return;

    final doc = await _firestore.collection(AppConstants.collectionUsers).doc(uid).get();
    if (!doc.exists) {
      throw Exception('User profile not found.');
    }

    final data = doc.data();
    final isActive = data?['isActive'] as bool? ?? true;

    if (!isActive) {
      // Immediately terminate the Firebase Auth session
      await FirebaseAuth.instance.signOut();
      throw Exception(AppConstants.accountDeactivatedMessage);
    }
  }
}

/// Provider exposing the AccountStatusGuard instance for easy DI
final accountStatusGuardProvider = Provider<AccountStatusGuard>((ref) {
  return AccountStatusGuard();
});
