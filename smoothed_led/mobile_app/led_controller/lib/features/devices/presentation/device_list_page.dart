import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/presentation/settings_page.dart';
import '../application/device_list_controller.dart';
import 'device_control_page.dart';
import '../../pairing/presentation/pairing_page.dart';

class DeviceListPage extends ConsumerWidget {
  const DeviceListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devicesAsync = ref.watch(deviceListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的设备'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SettingsPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: devicesAsync.when(
        data: (devices) {
          if (devices.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('还没有设备'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () async {
                      final paired = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => const PairingPage(),
                        ),
                      );
                      if (paired != true || !context.mounted) {
                        return;
                      }
                      ref.invalidate(deviceListProvider);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('设备已添加')),
                      );
                    },
                    child: const Text('添加设备'),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            itemCount: devices.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final device = devices[index];
              return ListTile(
                title: Text(device.name),
                subtitle: Text(device.ipAddress),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DeviceControlPage(
                        device: device,
                      ),
                    ),
                  );
                  ref.invalidate(deviceListProvider);
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => const Center(child: Text('加载设备失败')),
      ),
    );
  }
}
