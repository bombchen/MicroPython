class PairingFailure implements Exception {
  const PairingFailure({
    required this.message,
    this.diagnostics,
  });

  final String message;
  final String? diagnostics;

  @override
  String toString() => 'Exception: $message';
}
