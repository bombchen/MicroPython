import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/device_control_controller.dart';
import '../application/device_list_controller.dart';
import '../domain/device_status.dart';
import '../domain/effect_mode.dart';
import '../domain/led_device.dart';

class DeviceControlPage extends ConsumerStatefulWidget {
  const DeviceControlPage({
    super.key,
    required this.device,
  });

  final LedDevice device;

  @override
  ConsumerState<DeviceControlPage> createState() => _DeviceControlPageState();
}

class _DeviceControlPageState extends ConsumerState<DeviceControlPage> {
  late LedDevice _device;
  late DeviceControlController _controller;
  late AsyncValue<DeviceStatus> _controlState;
  late void Function() _removeControlListener;
  double? _pendingBrightness;

  @override
  void initState() {
    super.initState();
    _device = widget.device;
    _controller = DeviceControlController(
      ref.read(udpClientProvider),
      ref.read(udpLedProtocolProvider),
      initialStatus: _device.lastKnownStatus,
      deviceRepository: ref.read(deviceRepositoryProvider),
      deviceId: _device.id,
    );
    _controlState = AsyncValue.data(_device.lastKnownStatus);
    _pendingBrightness = _device.lastKnownStatus.brightness.toDouble();
    _removeControlListener = _controller.addListener(
      (state) {
        if (!mounted) {
          return;
        }

        setState(() {
          _controlState = state;
          final status = state.value;
          if (status != null) {
            final now = DateTime.now();
            _device = _device.copyWith(
              lastKnownStatus: status,
              lastSeenAt: now,
              updatedAt: now,
            );
            if (status.connectionState != DeviceConnectionState.sending) {
              _pendingBrightness = status.brightness.toDouble();
            }
          }
        });
      },
      fireImmediately: false,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.refresh(_device.ipAddress);
    });
  }

  @override
  void dispose() {
    _removeControlListener();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = _controlState.value ?? _device.lastKnownStatus;
    final isLoading = _controlState is AsyncLoading<DeviceStatus>;
    final isSending = status.connectionState == DeviceConnectionState.sending;
    final isBusy = isLoading || isSending;

    return Scaffold(
      appBar: AppBar(
        title: Text(_device.name),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz),
            onSelected: (value) {
              if (value == 'rename') {
                _renameDevice();
              } else if (value == 'delete') {
                _deleteDevice();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                value: 'rename',
                child: Text('重命名设备'),
              ),
              PopupMenuItem<String>(
                value: 'delete',
                child: Text('删除设备'),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SectionCard(
            title: '设备状态',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Chip(
                      label: Text(_statusLabel(status.connectionState)),
                      backgroundColor: _statusColor(
                        context,
                        status.connectionState,
                      ).withOpacity(0.12),
                    ),
                    Text('最近同步: ${_formatDateTime(_device.lastSeenAt)}'),
                  ],
                ),
                const SizedBox(height: 12),
                Text('IP: ${_device.ipAddress}'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: '当前模式',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _modeLabel(status.mode),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                if (_controlState is AsyncError<DeviceStatus>)
                  const Text('设备暂时没有响应，你可以稍后重试。'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: '亮度调节',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${(_pendingBrightness ?? status.brightness.toDouble()).round()}',
                ),
                Slider(
                  value: (_pendingBrightness ?? status.brightness.toDouble())
                      .clamp(0, 255)
                      .toDouble(),
                  min: 0,
                  max: 255,
                  divisions: 255,
                  label:
                      '${(_pendingBrightness ?? status.brightness.toDouble()).round()}',
                  onChanged: isBusy
                      ? null
                      : (value) {
                          setState(() {
                            _pendingBrightness = value;
                          });
                        },
                  onChangeEnd: isBusy
                      ? null
                      : (value) {
                          _controller.setBrightness(
                            _device.ipAddress,
                            value.round(),
                          );
                        },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: '常用灯效',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: EffectMode.values.map((mode) {
                return ChoiceChip(
                  label: Text(_modeLabel(mode)),
                  selected: status.mode == mode,
                  onSelected: isBusy
                      ? null
                      : (_) => _controller.setMode(_device.ipAddress, mode),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: '更多操作',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: isBusy
                      ? null
                      : () => _controller.refresh(_device.ipAddress),
                  icon: const Icon(Icons.refresh),
                  label: const Text('刷新状态'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isBusy
                            ? null
                            : () => _controller.previousMode(_device.ipAddress),
                        child: const Text('上一个灯效'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isBusy
                            ? null
                            : () => _controller.nextMode(_device.ipAddress),
                        child: const Text('下一个灯效'),
                      ),
                    ),
                  ],
                ),
                if (isLoading || isSending) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _renameDevice() async {
    var draftName = _device.name;
    final renamed = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('重命名设备'),
          content: TextFormField(
            initialValue: _device.name,
            autofocus: true,
            decoration: const InputDecoration(labelText: '设备名称'),
            onChanged: (value) {
              draftName = value.trim();
            },
            onFieldSubmitted: (value) {
              Navigator.of(context).pop(value.trim());
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(draftName);
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    if (renamed == null || renamed.isEmpty || !mounted) {
      return;
    }

    final updated = _device.copyWith(
      name: renamed,
      updatedAt: DateTime.now(),
    );
    await ref.read(deviceRepositoryProvider).saveDevice(updated);

    if (!mounted) {
      return;
    }

    setState(() {
      _device = updated;
    });
  }

  Future<void> _deleteDevice() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除设备'),
          content: const Text('只会删除本地记录，不会修改设备固件。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    await ref.read(deviceRepositoryProvider).deleteDevice(_device.id);

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop(true);
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

  Color _statusColor(BuildContext context, DeviceConnectionState state) {
    final scheme = Theme.of(context).colorScheme;
    switch (state) {
      case DeviceConnectionState.online:
        return scheme.primary;
      case DeviceConnectionState.offline:
        return scheme.error;
      case DeviceConnectionState.timeout:
        return scheme.tertiary;
      case DeviceConnectionState.sending:
        return scheme.secondary;
    }
  }

  String _formatDateTime(DateTime value) {
    String pad(int number) => number.toString().padLeft(2, '0');

    return '${value.year}-${pad(value.month)}-${pad(value.day)} '
        '${pad(value.hour)}:${pad(value.minute)}';
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
