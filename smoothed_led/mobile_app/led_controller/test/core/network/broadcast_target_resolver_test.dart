import 'package:flutter_test/flutter_test.dart';
import 'package:led_controller/core/network/broadcast_target_resolver.dart';

void main() {
  test('会从本机 IPv4 地址推导定向广播地址并保留通用广播地址', () {
    final targets = resolveBroadcastTargets(<String>[
      '192.168.1.23',
      '10.0.0.8',
    ]);

    expect(
      targets,
      <String>[
        '255.255.255.255',
        '192.168.1.255',
        '10.0.0.255',
      ],
    );
  });

  test('会忽略无效地址并去重', () {
    final targets = resolveBroadcastTargets(<String>[
      '192.168.1.23',
      '192.168.1.99',
      '127.0.0.1',
      'fe80::1',
      'bad-ip',
    ]);

    expect(
      targets,
      <String>[
        '255.255.255.255',
        '192.168.1.255',
      ],
    );
  });
}
