import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:led_controller/app/app.dart';

void main() {
  testWidgets('启动后默认显示设备列表空状态', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: LedControllerApp()));

    expect(find.text('我的设备'), findsOneWidget);
    expect(find.text('还没有设备'), findsOneWidget);
    expect(find.text('添加设备'), findsOneWidget);
  });
}
