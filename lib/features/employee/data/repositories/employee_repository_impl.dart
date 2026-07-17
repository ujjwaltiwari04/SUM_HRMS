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
  Future<void> registerEmployee(UserModel employee) async {
    // Check if the document already exists with the given phone
    final query = await _firestore
        .collection(AppConstants.collectionUsers)
        .where('phone', isEqualTo: employee.phoneNumber)
        .get();

    if (query.docs.isNotEmpty) {
      throw Exception('An employee with this phone number is already registered.');
    }

    // Insert new document. Let firestore auto-generate document ID if empty, or use uid if defined.
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
