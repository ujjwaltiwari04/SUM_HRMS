/// Standardized Failure abstractions for SUM Enterprises Clean Architecture.
/// Facilitates predictable, safe, and typed error handling throughout domain/presentation layers.
abstract class Failure {
  final String message;
  final String? code;

  const Failure(this.message, {this.code});

  @override
  String toString() => '$runtimeType: $message${code != null ? " ($code)" : ""}';
}

/// Handled failures occurring on Firebase or external API endpoints.
class ServerFailure extends Failure {
  const ServerFailure(super.message, {super.code});
}

/// Authentication related failures (e.g. invalid password, no such corporate user).
class AuthFailure extends Failure {
  const AuthFailure(super.message, {super.code});
}

/// Failures related to local data storage, cache misses, or permission denials.
class CacheFailure extends Failure {
  const CacheFailure(super.message, {super.code});
}

/// Location or Google Maps SDK failures (e.g. permission disabled, hardware timeout).
class LocationFailure extends Failure {
  const LocationFailure(super.message, {super.code});
}

/// General fallback failure when an unexpected local error occurs.
class UnknownFailure extends Failure {
  const UnknownFailure(super.message, {super.code});
}
