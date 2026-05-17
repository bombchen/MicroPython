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
      failureType: null,
    );
  }

  void returnToApReconnect() {
    _state = _state.copyWith(
      step: PairingStep.returnToApp,
      errorMessage: null,
      diagnosticsMessage: null,
      resolvedIpAddress: null,
      failureType: null,
    );
  }

  void markSendingConfig(String ssid, String password) {
    _state = _state.copyWith(
      step: PairingStep.sendingConfig,
      ssid: ssid,
      password: password,
      errorMessage: null,
      diagnosticsMessage: null,
      resolvedIpAddress: null,
      failureType: null,
    );
  }

  void markWaitingReconnect() {
    _state = _state.copyWith(
      step: PairingStep.waitingReconnect,
      errorMessage: null,
      diagnosticsMessage: null,
      resolvedIpAddress: null,
      failureType: null,
    );
  }

  Future<void> submitCredentials({
    required String ssid,
    required String password,
  }) async {
    markSendingConfig(ssid, password);

    try {
      await _coordinator.sendCredentials(
        ssid: ssid,
        password: password,
      );
    } catch (error) {
      _fail(
        message: '$error',
        diagnostics: null,
        failureType: PairingFailureType.configSendFailed,
      );
      return;
    }

    await continueWaitingReconnect();
  }

  Future<void> retrySubmitCredentials() async {
    await submitCredentials(
      ssid: _state.ssid,
      password: _state.password,
    );
  }

  Future<void> continueWaitingReconnect() async {
    markWaitingReconnect();

    try {
      final ip = await _coordinator.waitForDeviceRegistration();
      _state = _state.copyWith(
        step: PairingStep.success,
        resolvedIpAddress: ip,
        errorMessage: null,
        diagnosticsMessage: null,
        failureType: null,
      );
    } on PairingFailure catch (error) {
      _fail(
        message: error.message,
        diagnostics: error.diagnostics,
        failureType: PairingFailureType.reconnectTimedOut,
      );
    } catch (error) {
      _fail(
        message: '$error',
        diagnostics: null,
        failureType: PairingFailureType.reconnectTimedOut,
      );
    }
  }

  void _fail({
    required String message,
    required String? diagnostics,
    required PairingFailureType failureType,
  }) {
    _state = _state.copyWith(
      step: PairingStep.failure,
      errorMessage: message,
      diagnosticsMessage: diagnostics,
      resolvedIpAddress: null,
      failureType: failureType,
    );
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
  Future<void> sendCredentials({
    required String ssid,
    required String password,
  }) {
    throw StateError('PairingCoordinator is required for runtime actions');
  }

  @override
  Future<String> waitForDeviceRegistration() {
    throw StateError('PairingCoordinator is required for runtime actions');
  }
}
