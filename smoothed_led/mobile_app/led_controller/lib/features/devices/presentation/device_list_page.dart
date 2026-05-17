import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/presentation/settings_page.dart';
import '../application/device_list_controller.dart';
import '../domain/device_status.dart';
import '../domain/effect_mode.dart';
import '../domain/led_device.dart';
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
        actions: [
          IconButton(
            tooltip: '刷新全部',
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
            icon: const Icon(Icons.tune_outlined),
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
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '我的灯光',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '随时调出家里的氛围',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 20),
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
                        child: Text(devices.isEmpty ? '添加第一台灯带' : '添加设备'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (devices.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(
                          Icons.light_outlined,
                          size: 48,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '还没有设备',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '添加灯带后，你就可以在这里查看状态并调整灯效。',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...devices.map((device) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _DeviceCard(
                      device: device,
                      statusLabel: _statusLabel(
                        device.lastKnownStatus.connectionState,
                      ),
                      modeLabel: _modeLabel(device.lastKnownStatus.mode),
                      lastSyncLabel: _formatDateTime(device.lastSeenAt),
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
                    ),
                  );
                }),
            ],
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

  String _modeLabel(EffectMode mode) {
    switch (mode) {
      case EffectMode.rainbow:
        return '彩虹';
      case EffectMode.breath:
        return '呼吸';
      case EffectMode.fire:
        return '火焰';
      case EffectMode.starry:
        return '星空';
      case EffectMode.wave:
        return '波浪';
      case EffectMode.chase:
        return '追逐';
      case EffectMode.sparkle:
        return '闪烁';
      case EffectMode.snake:
        return '蛇形';
      case EffectMode.music:
        return '音乐律动';
    }
  }

  String _formatDateTime(DateTime value) {
    String pad(int number) => number.toString().padLeft(2, '0');

    return '${value.year}-${pad(value.month)}-${pad(value.day)} '
        '${pad(value.hour)}:${pad(value.minute)}';
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.device,
    required this.statusLabel,
    required this.modeLabel,
    required this.lastSyncLabel,
    required this.onTap,
  });

  final LedDevice device;
  final String statusLabel;
  final String modeLabel;
  final String lastSyncLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      device.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Text(statusLabel),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                modeLabel,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(device.ipAddress),
              const SizedBox(height: 8),
              Text('最近同步: $lastSyncLabel'),
            ],
          ),
        ),
      ),
    );
  }
}
