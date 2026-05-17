import 'package:flutter_test/flutter_test.dart';
import 'package:led_controller/core/network/udp_led_protocol.dart';
import 'package:led_controller/features/devices/domain/device_status.dart';
import 'package:led_controller/features/devices/domain/effect_mode.dart';

void main() {
  test('正确拼装控制命令', () {
    final protocol = UdpLedProtocol();

    expect(protocol.statusCommand(), 'status');
    expect(protocol.modeCommand(EffectMode.fire), 'mode:fire');
    expect(protocol.modeCommand(EffectMode.music), 'mode:music');
    expect(protocol.nextModeCommand(), 'mode:next');
    expect(protocol.previousModeCommand(), 'mode:prev');
    expect(protocol.brightnessCommand(200), 'bright:200');
  });

  test('正确解析 status 响应', () {
    final protocol = UdpLedProtocol();
    final status = protocol.parseStatus('MODE:rainbow;BRIGHT:180');

    expect(status.mode, EffectMode.rainbow);
    expect(status.brightness, 180);
    expect(status.connectionState, DeviceConnectionState.online);
  });

  test('music 模式可被拼装和解析', () {
    final protocol = UdpLedProtocol();

    expect(protocol.modeCommand(EffectMode.music), 'mode:music');

    final status = protocol.parseStatus('MODE:music;BRIGHT:210');
    expect(status.mode, EffectMode.music);
    expect(status.brightness, 210);
  });

  test('无效 status 响应抛出 FormatException', () {
    final protocol = UdpLedProtocol();

    expect(
      () => protocol.parseStatus('MODE:rainbow'),
      throwsA(isA<FormatException>()),
    );
  });
}
