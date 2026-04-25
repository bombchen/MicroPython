import '../domain/pairing_state.dart';
import '../domain/pairing_step.dart';
import 'pairing_coordinator.dart';

class PairingController {
  PairingController({PairingCoordinator? coordinator})
      : _coordinator = coordinator ?? const _MissingPairingCoordinator();

  final PairingCoordinator _coordinator;
  PairingState _state = const PairingState(step: PairingStep.prepare);

  PairingState get state => _state;

  void moveToApJoin() {
    _state = _state.copyWith(step: PairingStep.joinAp);
  }

  void confirmApJoined() {
    _state = _state.copyWith(step: PairingStep.enterWifi);
  }

  Future<void> openWifiSettings() async {
    await _coordinator.openWifiSettings();
    _state = _state.copyWith(step: PairingStep.returnToApp);
  }

  void markWaitingReconnect(String ssid, String password) {
    _state = _state.copyWith(
      step: PairingStep.waitingReconnect,
      ssid: ssid,
      password: password,
      errorMessage: null,
      resolvedIpAddress: null,
    );
  }

  Future<void> submitCredentials({
    required String ssid,
    required String password,
  }) async {
    markWaitingReconnect(ssid, password);

    try {
      final ip = await _coordinator.submitCredentials(
        ssid: ssid,
        password: password,
      );
      _state = _state.copyWith(
        step: PairingStep.success,
        resolvedIpAddress: ip,
        errorMessage: null,
      );
    } catch (error) {
      _state = _state.copyWith(
        step: PairingStep.failure,
        errorMessage: '$error',
        resolvedIpAddress: null,
      );
    }
  }
}

class _MissingPairingCoordinator implements PairingCoordinator {
  const _MissingPairingCoordinator();

  @override
  Future<void> openWifiSettings() {
    throw StateError('PairingCoordinator is required for runtime actions');
  }

  @override
  Future<String> submitCredentials({
    required String ssid,
    required String password,
  }) {
    throw StateError('PairingCoordinator is required for runtime actions');
  }
}
