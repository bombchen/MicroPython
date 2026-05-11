import 'udp_client.dart';
import 'udp_led_protocol.dart';

class PairingProbeService {
  PairingProbeService(
    this._udpClient,
    this._protocol, {
    Duration probeWindow = const Duration(seconds: 20),
    Duration attemptTimeout = const Duration(seconds: 1),
    Duration retryInterval = const Duration(milliseconds: 250),
  })  : _probeWindow = probeWindow,
        _attemptTimeout = attemptTimeout,
        _retryInterval = retryInterval;

  final UdpClient _udpClient;
  final UdpLedProtocol _protocol;
  final Duration _probeWindow;
  final Duration _attemptTimeout;
  final Duration _retryInterval;

  Future<String?> resolveDeviceIp() async {
    final deadline = DateTime.now().add(_probeWindow);

    while (true) {
      final ip = await _udpClient.sendBroadcast(
        port: 8888,
        payload: _protocol.statusCommand(),
        timeout: _attemptTimeout,
      );
      if (ip != null) {
        return ip;
      }

      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        return null;
      }

      await Future<void>.delayed(
        remaining < _retryInterval ? remaining : _retryInterval,
      );
    }
  }
}
