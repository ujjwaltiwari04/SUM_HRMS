import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sum_enterprises/core/constants/app_constants.dart';
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
    // EXTENSION POINT:
    // For Version 1, we assume the Firebase Authentication user account already exists.
    // In future backend integration, trigger server-side Firebase Auth account creation here.
    // E.g., send a request to a Cloud Function or private API endpoint:
    // final backendResult = await _backendService.createAuthAccount(email: employee.email, password: tempPassword);
    // final String newUid = backendResult.uid;
    // employee = employee.copyWith(uid: newUid);

    // 1. Check if the document already exists with the given email
    if (employee.email.isNotEmpty) {
      final query = await _firestore
          .collection(AppConstants.collectionUsers)
          .where('email', isEqualTo: employee.email)
          .get();

      if (query.docs.isNotEmpty) {
        throw Exception('An employee with this email address is already registered.');
      }
    }

    // 2. Insert new document. Use uid if defined, otherwise auto-generate.
    final docRef = employee.uid.isNotEmpty 
        ? _firestore.collection(AppConstants.collectionUsers).doc(employee.uid)
        : _firestore.collection(AppConstants.collectionUsers).doc();
        
    final Map<String, dynamic> data = employee.toMap();
    // Enforce matching doc ID if auto-generated
    if (employee.uid.isEmpty) {
      data['uid'] = docRef.id;
    }
    
    await docRef.set(data);
  }
}
