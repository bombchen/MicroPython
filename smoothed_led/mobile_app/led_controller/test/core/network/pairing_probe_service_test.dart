import 'package:flutter_test/flutter_test.dart';
import 'package:led_controller/core/network/pairing_probe_service.dart';
import 'package:led_controller/core/network/udp_client.dart';
import 'package:led_controller/core/network/udp_led_protocol.dart';

class FakeUdpClient implements UdpClient {
  FakeUdpClient({required this.broadcastResponses});

  final List<String?> broadcastResponses;
  int broadcastCallCount = 0;

  @override
  Future<String> send({
    required String host,
    required int port,
    required String payload,
    Duration timeout = const Duration(seconds: 2),
  }) {
    throw UnimplementedError();
  }

  @override
  Future<String?> sendBroadcast({
    required int port,
    required String payload,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final index = broadcastCallCount;
    broadcastCallCount += 1;
    if (index >= broadcastResponses.length) {
      return null;
    }
    return broadcastResponses[index];
  }
}

void main() {
  test('设备重连较慢时会持续探测直到拿到局域网 IP', () async {
    final udpClient = FakeUdpClient(
      broadcastResponses: <String?>[
        null,
        '192.168.1.23',
      ],
    );
    final service = PairingProbeService(udpClient, UdpLedProtocol());

    final ip = await service.resolveDeviceIp();

    expect(ip, '192.168.1.23');
    expect(udpClient.broadcastCallCount, greaterThan(1));
  });
}
