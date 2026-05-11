import '../domain/pairing_state.dart';
import '../domain/pairing_step.dart';
import 'pairing_coordinator.dart';
import 'pairing_failure.dart';

class PairingController {
  PairingController({PairingCoordinator? coordinator})
      : _coordinator = coordinator ?? const _MissingPairingCoordinator();

  final PairingCoordinator _coordinator;
  PairingState _state = const PairingState(step: PairingStep.prepare);

  PairingState get state => _state;

  void moveToApJoin() {
    _state = _state.copyWith(step: PairingStep.joinAp);
  }

  void markReturnToApp() {
    _state = _state.copyWith(step: PairingStep.returnToApp);
  }

  void confirmApJoined() {
    _state = _state.copyWith(step: PairingStep.enterWifi);
  }

  Future<void> openWifiSettings() async {
    await _coordinator.openWifiSettings();
    markReturnToApp();
  }

  void returnToWifiForm() {
    _state = _state.copyWith(
      step: PairingStep.enterWifi,
      errorMessage: null,
      diagnosticsMessage: null,
    );
  }

  void returnToApReconnect() {
    _state = _state.copyWith(
      step: PairingStep.returnToApp,
      errorMessage: null,
      diagnosticsMessage: null,
      resolvedIpAddress: null,
    );
  }

  void markWaitingReconnect(String ssid, String password) {
    _state = _state.copyWith(
      step: PairingStep.waitingReconnect,
      ssid: ssid,
      password: password,
      errorMessage: null,
      diagnosticsMessage: null,
      resolvedIpAddress: null,
    );
  }

  Future<void> submitCredentials({
    required String ssid,
    required String password,
    bool markWaiting = true,
  }) async {
    if (markWaiting) {
      markWaitingReconnect(ssid, password);
    }

    try {
      final ip = await _coordinator.submitCredentials(
        ssid: ssid,
        password: password,
      );
      _state = _state.copyWith(
        step: PairingStep.success,
        resolvedIpAddress: ip,
        errorMessage: null,
        diagnosticsMessage: null,
      );
    } on PairingFailure catch (error) {
      _state = _state.copyWith(
        step: PairingStep.failure,
        errorMessage: error.message,
        diagnosticsMessage: error.diagnostics,
        resolvedIpAddress: null,
      );
    } catch (error) {
      _state = _state.copyWith(
        step: PairingStep.failure,
        errorMessage: '$error',
        diagnosticsMessage: null,
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
  Future<void> resetConfiguration() {
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
