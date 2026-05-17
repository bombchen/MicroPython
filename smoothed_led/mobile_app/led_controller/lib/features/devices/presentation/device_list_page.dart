import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/presentation/settings_page.dart';
import '../application/device_list_controller.dart';
import '../domain/device_status.dart';
import 'device_control_page.dart';
import '../../pairing/presentation/pairing_page.dart';

class DeviceListPage extends ConsumerStatefulWidget {
  const DeviceListPage({super.key});

  @override
  ConsumerState<DeviceListPage> createState() => _DeviceListPageState();
}

class _DeviceListPageState extends ConsumerState<DeviceListPage> {
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshDevices();
    });
  }

  void _handleSuccessfulPairing(BuildContext context, WidgetRef ref) {
    ref.invalidate(deviceListProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('设备已添加')),
    );
  }

  Future<void> _refreshDevices() async {
    if (_isRefreshing) {
      return;
    }

    setState(() {
      _isRefreshing = true;
    });

    try {
      await ref.read(deviceListRefresherProvider).refreshStatuses();
      ref.invalidate(deviceListProvider);
      await ref.read(deviceListProvider.future);
    } catch (_) {
      // Keep the page usable even if a background refresh cannot start.
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final devicesAsync = ref.watch(deviceListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的设备'),
        actions: [
          IconButton(
            tooltip: '刷新设备状态',
            icon: _isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _refreshDevices,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () async {
              final result =
                  await Navigator.of(context).push<PairingFlowResult>(
                MaterialPageRoute(
                  builder: (_) => const SettingsPage(),
                ),
              );
              if (result != PairingFlowResult.paired || !context.mounted) {
                return;
              }
              _handleSuccessfulPairing(context, ref);
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
                      _handleSuccessfulPairing(context, ref);
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
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(device.ipAddress),
                    const SizedBox(height: 4),
                    Text(_statusLabel(device.lastKnownStatus.connectionState)),
                    Text('最近同步: ${_formatDateTime(device.lastSeenAt)}'),
                  ],
                ),
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

  String _statusLabel(DeviceConnectionState state) {
    switch (state) {
      case DeviceConnectionState.online:
        return '在线';
      case DeviceConnectionState.offline:
        return '离线';
      case DeviceConnectionState.timeout:
        return '超时';
      case DeviceConnectionState.sending:
        return '发送中';
    }
  }

  String _formatDateTime(DateTime value) {
    String pad(int number) => number.toString().padLeft(2, '0');

    return '${value.year}-${pad(value.month)}-${pad(value.day)} '
        '${pad(value.hour)}:${pad(value.minute)}';
  }
}
