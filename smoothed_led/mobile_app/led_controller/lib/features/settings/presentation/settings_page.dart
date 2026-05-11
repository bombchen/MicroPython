import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../pairing/application/pairing_coordinator.dart';
import '../../pairing/presentation/pairing_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  static const _steps = <String>[
    '连接设备热点 LED_Config',
    '连接后返回 APP',
    '输入家庭 WiFi 名称和密码',
    '等待设备重启并回到设备列表',
  ];

  static const _faqItems = <MapEntry<String, String>>[
    MapEntry('看不到 LED_Config', '如果手机搜不到热点，请先确认设备刚上电。'),
    MapEntry('手机提示该网络无互联网', '看到“无互联网”提示属于正常现象，可继续连接。'),
    MapEntry('Android 自动切回原 WiFi', '部分 Android 机型会自动回切，请重新连接设备热点后返回 APP。'),
    MapEntry('配网完成后列表里没有新设备', '请等待设备重启完成，再返回设备列表下拉刷新。'),
    MapEntry('进入控制页后设备无响应', '请确认手机和设备已经连接到同一家庭局域网。'),
  ];

  static const _systemNotes = <String>[
    '配网阶段必须手动切换到设备热点',
    'Android 的 WiFi 切换不完全由 APP 控制',
    '设备控制要求手机和设备在同一局域网',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('配网帮助')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '用于首次配网和常见问题排查',
                      style: textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 6),
                    FilledButton(
                      onPressed: () async {
                        final result =
                            await Navigator.of(context).push<PairingFlowResult>(
                          MaterialPageRoute(
                            builder: (_) => const PairingPage(),
                          ),
                        );
                        if (result != PairingFlowResult.paired ||
                            !context.mounted) {
                          return;
                        }
                        Navigator.of(context).pop(PairingFlowResult.paired);
                      },
                      child: const Text('去添加设备'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () async {
                        await ref.read(pairingCoordinatorProvider).resetConfiguration();
                        if (!context.mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('设备已重置，请重新连接 LED_Config 后重新配网'),
                          ),
                        );
                      },
                      child: const Text('重置设备配网'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 12),
              childrenPadding: const EdgeInsets.only(bottom: 4),
              initiallyExpanded: true,
              title: const Text('配网步骤'),
              children: _steps
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(item),
                      ),
                    ),
                  )
                  .toList(),
            ),
            ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 12),
              title: const Text('常见故障'),
              children: _faqItems
                  .map(
                    (item) => ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                      childrenPadding: const EdgeInsets.only(bottom: 4),
                      title: Text(item.key),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Text(item.value),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
            ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 12),
              childrenPadding: const EdgeInsets.only(bottom: 4),
              title: const Text('系统与权限说明'),
              children: _systemNotes
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(item),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
