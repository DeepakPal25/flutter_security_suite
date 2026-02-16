import '../exceptions/security_exception.dart';

/// A sealed result type for security operations.
///
/// Use [fold] for exhaustive handling of success/failure cases.
sealed class SecurityResult<T> {
  const SecurityResult();

  /// Pattern-matches on this result, returning a value from the
  /// appropriate callback.
  R fold<R>({
    required R Function(T data) onSuccess,
    required R Function(SecurityException error) onFailure,
  }) {
    return switch (this) {
      Success<T>(:final data) => onSuccess(data),
      Failure<T>(:final error) => onFailure(error),
    };
  }

  /// Returns the data if [Success], otherwise `null`.
  T? get dataOrNull => switch (this) {
    Success<T>(:final data) => data,
    Failure<T>() => null,
  };

  /// Returns `true` if this result is a [Success].
  bool get isSuccess => this is Success<T>;

  /// Returns `true` if this result is a [Failure].
  bool get isFailure => this is Failure<T>;
}

/// A successful result containing [data].
class Success<T> extends SecurityResult<T> {
  final T data;
  const Success(this.data);
}

/// A failed result containing a [SecurityException].
class Failure<T> extends SecurityResult<T> {
  final SecurityException error;
  const Failure(this.error);
}
