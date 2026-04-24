import 'udp_client.dart';
import 'udp_led_protocol.dart';

class PairingProbeService {
  PairingProbeService(this._udpClient, this._protocol);

  final UdpClient _udpClient;
  final UdpLedProtocol _protocol;

  Future<String?> resolveDeviceIp() {
    return _udpClient.sendBroadcast(
      port: 8888,
      payload: _protocol.statusCommand(),
    );
  }
}
