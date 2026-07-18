import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sum_enterprises/core/error/failures.dart';
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

/// Immutable UI action state for employee administrative modifications.
class EmployeeActionState {
  final bool isLoading;
  final bool isSuccess;
  final String? successMessage;
  final String? errorMessage;

  const EmployeeActionState({
    this.isLoading = false,
    this.isSuccess = false,
    this.successMessage,
    this.errorMessage,
  });

  EmployeeActionState copyWith({
    bool? isLoading,
    bool? isSuccess,
    String? successMessage,
    String? errorMessage,
    bool clearSuccess = false,
    bool clearError = false,
  }) {
    return EmployeeActionState(
      isLoading: isLoading ?? this.isLoading,
      isSuccess: isSuccess ?? this.isSuccess,
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EmployeeActionState &&
        other.isLoading == isLoading &&
        other.isSuccess == isSuccess &&
        other.successMessage == successMessage &&
        other.errorMessage == errorMessage;
  }

  @override
  int get hashCode => Object.hash(isLoading, isSuccess, successMessage, errorMessage);
}

/// Controller coordinating employee business logic modifications.
/// Implements standard Clean Architecture bounds, never accessing low-level data sources.
class EmployeeActionController extends StateNotifier<EmployeeActionState> {
  final EmployeeRepository _employeeRepository;

  EmployeeActionController({required EmployeeRepository employeeRepository})
      : _employeeRepository = employeeRepository,
        super(const EmployeeActionState());

  /// Coordinates registering a new employee credential via the repository.
  Future<void> registerEmployee({
    required UserModel employee,
    required String password,
  }) async {
    state = state.copyWith(
      isLoading: true,
      isSuccess: false,
      clearSuccess: true,
      clearError: true,
    );

    try {
      await _employeeRepository.registerEmployee(employee, tempPassword: password);

      state = state.copyWith(
        isLoading: false,
        isSuccess: true,
        successMessage: 'Employee ${employee.fullName} successfully registered.',
      );
    } catch (e) {
      String displayError = 'Registration failed.';

      if (e is Failure) {
        displayError = e.message;
      } else {
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('network') || errorStr.contains('connectivity')) {
          displayError = 'Network unavailable. Please check your internet connection.';
        } else if (errorStr.contains('unexpected')) {
          displayError = 'An unexpected error occurred during employee registration.';
        }
      }

      state = state.copyWith(
        isLoading: false,
        isSuccess: false,
        errorMessage: displayError,
      );
    }
  }

  /// Coordinates updating an existing employee's details.
  Future<void> updateEmployee({
    required UserModel employee,
  }) async {
    state = state.copyWith(
      isLoading: true,
      isSuccess: false,
      clearSuccess: true,
      clearError: true,
    );

    try {
      await _employeeRepository.updateEmployee(employee);

      state = state.copyWith(
        isLoading: false,
        isSuccess: true,
        successMessage: 'Employee ${employee.fullName} successfully updated.',
      );
    } catch (e) {
      String displayError = 'Update failed.';

      if (e is Failure) {
        displayError = e.message;
      } else {
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('network') || errorStr.contains('connectivity')) {
          displayError = 'Network unavailable. Please check your internet connection.';
        } else if (errorStr.contains('unexpected')) {
          displayError = 'An unexpected error occurred during employee update.';
        }
      }

      state = state.copyWith(
        isLoading: false,
        isSuccess: false,
        errorMessage: displayError,
      );
    }
  }

  /// Activates the employee profile.
  Future<void> activateEmployee(String employeeUid) async {
    state = state.copyWith(
      isLoading: true,
      isSuccess: false,
      clearSuccess: true,
      clearError: true,
    );

    try {
      await _employeeRepository.setEmployeeActiveStatus(
        employeeUid: employeeUid,
        isActive: true,
      );

      state = state.copyWith(
        isLoading: false,
        isSuccess: true,
        successMessage: 'Employee account successfully activated.',
      );
    } catch (e) {
      String displayError = 'Activation failed.';
      if (e is Failure) {
        displayError = e.message;
      }
      state = state.copyWith(
        isLoading: false,
        isSuccess: false,
        errorMessage: displayError,
      );
    }
  }

  /// Deactivates the employee profile.
  Future<void> deactivateEmployee(String employeeUid) async {
    state = state.copyWith(
      isLoading: true,
      isSuccess: false,
      clearSuccess: true,
      clearError: true,
    );

    try {
      await _employeeRepository.setEmployeeActiveStatus(
        employeeUid: employeeUid,
        isActive: false,
      );

      state = state.copyWith(
        isLoading: false,
        isSuccess: true,
        successMessage: 'Employee account successfully deactivated.',
      );
    } catch (e) {
      String displayError = 'Deactivation failed.';
      if (e is Failure) {
        displayError = e.message;
      }
      state = state.copyWith(
        isLoading: false,
        isSuccess: false,
        errorMessage: displayError,
      );
    }
  }

  /// Clears notifications messages without affecting the active loading state.
  void clearMessages() {
    state = state.copyWith(
      isSuccess: false,
      clearSuccess: true,
      clearError: true,
    );
  }
}

/// Provider of EmployeeActionController coordinating register notifications.
final employeeActionControllerProvider =
    StateNotifierProvider<EmployeeActionController, EmployeeActionState>((ref) {
  final repo = ref.watch(employeeRepositoryProvider);
  return EmployeeActionController(employeeRepository: repo);
});
