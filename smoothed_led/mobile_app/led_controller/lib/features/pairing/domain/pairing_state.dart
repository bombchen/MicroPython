import 'pairing_step.dart';

class PairingState {
  const PairingState({
    required this.step,
    this.ssid = '',
    this.password = '',
    this.errorMessage,
    this.resolvedIpAddress,
  });

  final PairingStep step;
  final String ssid;
  final String password;
  final String? errorMessage;
  final String? resolvedIpAddress;

  PairingState copyWith({
    PairingStep? step,
    String? ssid,
    String? password,
    String? errorMessage,
    String? resolvedIpAddress,
  }) {
    return PairingState(
      step: step ?? this.step,
      ssid: ssid ?? this.ssid,
      password: password ?? this.password,
      errorMessage: errorMessage,
      resolvedIpAddress: resolvedIpAddress ?? this.resolvedIpAddress,
    );
  }
}
