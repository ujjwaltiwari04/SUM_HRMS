import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sum_enterprises/features/auth/domain/models/user_model.dart';
import 'package:sum_enterprises/features/employee/data/repositories/employee_repository_impl.dart';
import 'package:sum_enterprises/features/employee/domain/repositories/employee_repository.dart';

/// Provider exposing the EmployeeRepository adapter
final employeeRepositoryProvider = Provider<EmployeeRepository>((ref) {
  return EmployeeRepositoryImpl();
});

/// Reactive stream provider listening to real-time additions/modifications in corporate directory
final employeeListStreamProvider = StreamProvider<List<UserModel>>((ref) {
  final repo = ref.watch(employeeRepositoryProvider);
  return repo.streamEmployees();
});
