import 'package:flutter_test/flutter_test.dart';
import 'package:sum_enterprises/features/auth/domain/models/user_model.dart';

void main() {
  group('UserModel Tests', () {
    test('fromMap parses admin role and active status correctly', () {
      final map = {
        'email': 'admin@sumenterprises.com',
        'name': 'Admin User',
        'role': 'admin',
        'phone': '+918586097283',
        'isActive': true,
        'designation': 'System Administrator',
      };

      final user = UserModel.fromMap(map, 'admin_uid');

      expect(user.uid, 'admin_uid');
      expect(user.email, 'admin@sumenterprises.com');
      expect(user.fullName, 'Admin User');
      expect(user.role, UserRole.admin);
      expect(user.isAdmin, true);
      expect(user.isEmployee, false);
      expect(user.phoneNumber, '+918586097283');
      expect(user.isActive, true);
    });

    test('fromMap defaults to employee role and fallback employeeId', () {
      final map = {
        'email': 'emp@sumenterprises.com',
        'name': 'Employee User',
        'role': 'employee',
        'phone': '+919999999999',
        'isActive': true,
      };

      final user = UserModel.fromMap(map, 'emp_uid_long');

      expect(user.uid, 'emp_uid_long');
      expect(user.role, UserRole.employee);
      expect(user.isAdmin, false);
      expect(user.isEmployee, true);
      expect(user.employeeId, 'SUM-EMP_U');
    });
  });
}
