import 'pairing_step.dart';

class PairingState {
  static const Object _unset = Object();

  const PairingState({
    required this.step,
    this.ssid = '',
    this.password = '',
    this.errorMessage,
    this.diagnosticsMessage,
    this.resolvedIpAddress,
  });

  final PairingStep step;
  final String ssid;
  final String password;
  final String? errorMessage;
  final String? diagnosticsMessage;
  final String? resolvedIpAddress;

  PairingState copyWith({
    PairingStep? step,
    String? ssid,
    String? password,
    Object? errorMessage = _unset,
    Object? diagnosticsMessage = _unset,
    Object? resolvedIpAddress = _unset,
  }) {
    return PairingState(
      step: step ?? this.step,
      ssid: ssid ?? this.ssid,
      password: password ?? this.password,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      diagnosticsMessage: identical(diagnosticsMessage, _unset)
          ? this.diagnosticsMessage
          : diagnosticsMessage as String?,
      resolvedIpAddress: identical(resolvedIpAddress, _unset)
          ? this.resolvedIpAddress
          : resolvedIpAddress as String?,
    );
  }
}
