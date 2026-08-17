/// Thrown when manifest or update validation fails.
class UpdateValidationException implements Exception {
  const UpdateValidationException(this.message);

  final String message;

  @override
  String toString() => 'UpdateValidationException: $message';
}

/// Thrown when download, install, or activation fails.
class UpdateOperationException implements Exception {
  const UpdateOperationException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() {
    if (cause == null) {
      return 'UpdateOperationException: $message';
    }
    return 'UpdateOperationException: $message ($cause)';
  }
}

/// Thrown when [HotUpdates] is used before [HotUpdates.initialize].
class HotUpdatesNotInitializedException implements Exception {
  const HotUpdatesNotInitializedException();

  @override
  String toString() =>
      'HotUpdatesNotInitializedException: call HotUpdates.initialize first';
}
