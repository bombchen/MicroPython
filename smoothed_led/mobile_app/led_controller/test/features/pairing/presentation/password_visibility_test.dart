import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:led_controller/features/pairing/application/pairing_controller.dart';
import 'package:led_controller/features/pairing/application/pairing_coordinator.dart';
import 'package:led_controller/features/pairing/presentation/pairing_page.dart';

class FakePairingCoordinator implements PairingCoordinator {
  @override
  Future<void> openWifiSettings() async {}

  @override
  Future<void> resetConfiguration() async {}

  @override
  Future<void> sendCredentials({
    required String ssid,
    required String password,
  }) async {}

  @override
  Future<String> waitForDeviceRegistration() async => '192.168.1.23';
}

void main() {
  testWidgets('WiFi 密码输入框支持显示和隐藏密码', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PairingPage(
          controller: PairingController(coordinator: FakePairingCoordinator())
            ..moveToApJoin()
            ..markReturnToApp()
            ..confirmApJoined(),
        ),
      ),
    );

    EditableText passwordField() =>
        tester.widget<EditableText>(find.byType(EditableText).at(1));

    expect(passwordField().obscureText, isTrue);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();

    expect(passwordField().obscureText, isFalse);
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.visibility_off_outlined));
    await tester.pump();

    expect(passwordField().obscureText, isTrue);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
  });
}
