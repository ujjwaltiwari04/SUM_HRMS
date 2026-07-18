import 'package:sum_enterprises/features/auth/domain/models/user_model.dart';

/// Clean Architecture Repository interface managing employee directory queries.
abstract class EmployeeRepository {
  /// Stream emitting the list of all registered employees within SUM Enterprises Firestore database.
  Stream<List<UserModel>> streamEmployees();
  
  /// Helper to add a new employee profile to Firestore corporate directory.
  /// Support optional temporary password for future server-side auth registration.
  Future<void> registerEmployee(UserModel employee, {String? tempPassword});
}
