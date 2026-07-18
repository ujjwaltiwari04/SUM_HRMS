import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:sum_enterprises/core/constants/app_constants.dart';
import 'package:sum_enterprises/core/error/failures.dart';
import 'package:sum_enterprises/features/auth/domain/models/user_model.dart';
import 'package:sum_enterprises/features/employee/domain/repositories/employee_repository.dart';

/// Concrete database adapter connecting Clean Architecture domain to Cloud Firestore.
class EmployeeRepositoryImpl implements EmployeeRepository {
  final FirebaseFirestore _firestore;

  EmployeeRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<List<UserModel>> streamEmployees() {
    return _firestore
        .collection(AppConstants.collectionUsers)
        .where('role', isEqualTo: 'employee')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return UserModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  @override
  Future<void> registerEmployee(UserModel employee, {String? tempPassword}) async {
    // 1. Check if the document already exists with the given email in Firestore
    if (employee.email.isNotEmpty) {
      final query = await _firestore
          .collection(AppConstants.collectionUsers)
          .where('email', isEqualTo: employee.email)
          .get();

      if (query.docs.isNotEmpty) {
        throw const AuthFailure('An employee with this email address is already registered.');
      }
    }

    // 2. Initialize secondary Firebase app instance to register the employee auth user
    // without interrupting/logging out the currently authenticated admin session.
    final String tempAppName = 'temp_registration_${DateTime.now().millisecondsSinceEpoch}';
    FirebaseApp? tempApp;
    
    try {
      tempApp = await Firebase.initializeApp(
        name: tempAppName,
        options: Firebase.app().options,
      );
      
      final tempAuth = fb.FirebaseAuth.instanceFor(app: tempApp);
      
      // Create user inside temporary authentication instance
      final credential = await tempAuth.createUserWithEmailAndPassword(
        email: employee.email,
        password: tempPassword ?? 'TempPass@123',
      );
      
      final String? newUid = credential.user?.uid;
      if (newUid == null) {
        throw const ServerFailure('Failed to obtain unique identifier for the registered employee account.');
      }
      
      // Get the currently logged-in administrator's uid from the primary Auth instance
      final currentAdminUid = fb.FirebaseAuth.instance.currentUser?.uid ?? 'system_admin';
      
      // Build updated employee profile with full timestamps, default fields, and author IDs
      final completeEmployee = employee.copyWith(
        uid: newUid,
        createdAt: DateTime.now(),
        lastUpdatedAt: DateTime.now(),
        createdBy: currentAdminUid,
      );
      
      // Create/Update Firestore document
      final docRef = _firestore.collection(AppConstants.collectionUsers).doc(newUid);
      final Map<String, dynamic> data = completeEmployee.toMap();
      data['uid'] = newUid; // Enforce document ID inside the data payload
      
      await docRef.set(data);
      
      // Sign out of the temporary auth session
      await tempAuth.signOut();
    } on fb.FirebaseAuthException catch (e) {
      String errorMessage = 'Registration failed.';
      if (e.code == 'email-already-in-use') {
        errorMessage = 'This email address is already in use by another account.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'The email address is invalid.';
      } else if (e.code == 'weak-password') {
        errorMessage = 'The password is too weak.';
      } else if (e.message != null) {
        errorMessage = e.message!;
      }
      throw AuthFailure(errorMessage, code: e.code);
    } catch (e) {
      if (e is Failure) rethrow;
      throw ServerFailure('An unexpected error occurred during employee registration: ${e.toString()}');
    } finally {
      if (tempApp != null) {
        await tempApp.delete();
      }
    }
  }

  @override
  Future<void> updateEmployee(UserModel employee) async {
    try {
      final docRef = _firestore.collection(AppConstants.collectionUsers).doc(employee.uid);
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) {
          throw const ServerFailure('Employee profile not found.');
        }

        // Get the currently logged-in administrator's uid from the primary Auth instance
        final currentAdminUid = fb.FirebaseAuth.instance.currentUser?.uid ?? 'system_admin';

        // Build updated employee profile with audit timestamps and author IDs
        final updatedEmployee = employee.copyWith(
          lastUpdatedAt: DateTime.now(),
          lastUpdatedBy: currentAdminUid,
        );

        transaction.update(docRef, updatedEmployee.toMap());
      });
    } catch (e) {
      if (e is Failure) rethrow;
      throw ServerFailure('An unexpected error occurred during employee update: ${e.toString()}');
    }
  }

  @override
  Future<void> setEmployeeActiveStatus({
    required String employeeUid,
    required bool isActive,
  }) async {
    try {
      final docRef = _firestore.collection(AppConstants.collectionUsers).doc(employeeUid);
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) {
          throw const ServerFailure('Employee profile not found.');
        }

        // Get the currently logged-in administrator's uid from the primary Auth instance
        final currentAdminUid = fb.FirebaseAuth.instance.currentUser?.uid ?? 'system_admin';

        transaction.update(docRef, {
          'isActive': isActive,
          'lastUpdatedAt': DateTime.now().toIso8601String(),
          'lastUpdatedBy': currentAdminUid,
        });
      });
    } catch (e) {
      if (e is Failure) rethrow;
      throw ServerFailure('An unexpected error occurred while toggling account status: ${e.toString()}');
    }
  }
}
