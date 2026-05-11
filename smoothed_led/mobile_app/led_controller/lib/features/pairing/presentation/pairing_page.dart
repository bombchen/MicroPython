import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/pairing_controller.dart';
import '../application/pairing_coordinator.dart';
import '../domain/pairing_step.dart';

enum PairingFlowResult {
  paired,
}

const _defaultProvisioningSsid = 'CU_3S2p';
const _defaultProvisioningPassword = 'qpgmfy';

class PairingPage extends ConsumerStatefulWidget {
  const PairingPage({
    super.key,
    this.controller,
  });

  final PairingController? controller;

  @override
  ConsumerState<PairingPage> createState() => _PairingPageState();
}

class _PairingPageState extends ConsumerState<PairingPage> {
  late final PairingController _controller;
  late final TextEditingController _ssidController;
  late final TextEditingController _passwordController;
  Timer? _waitingTimer;
  int _waitingSeconds = 0;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ??
        PairingController(coordinator: ref.read(pairingCoordinatorProvider));
    _ssidController = TextEditingController(
      text: _controller.state.ssid.isNotEmpty
          ? _controller.state.ssid
          : _defaultProvisioningSsid,
    );
    _passwordController = TextEditingController(
      text: _controller.state.password.isNotEmpty
          ? _controller.state.password
          : _defaultProvisioningPassword,
    );
  }

  @override
  void dispose() {
    _waitingTimer?.cancel();
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;
    _syncWaitingFeedback(state.step);

    if (_ssidController.text != state.ssid && state.ssid.isNotEmpty) {
      _ssidController.text = state.ssid;
    }
    if (_passwordController.text != state.password &&
        state.password.isNotEmpty) {
      _passwordController.text = state.password;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('添加设备')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            _stepTitle(state.step),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Text(
            _stepHeading(state.step),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(_stepDescription(state.step)),
          const SizedBox(height: 24),
          ..._buildStepContent(context, state.step),
        ],
      ),
    );
  }

  List<Widget> _buildStepContent(BuildContext context, PairingStep step) {
    switch (step) {
      case PairingStep.prepare:
        return [
          const Text('开始前请确认设备已上电，并且当前处于可配网状态。'),
          const SizedBox(height: 12),
          const Text('如果手机提示目标热点“无互联网”，这是正常现象。'),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              setState(_controller.moveToApJoin);
            },
            child: const Text('开始配网'),
          ),
        ];
      case PairingStep.joinAp:
        return [
          const Text('请前往系统 WiFi 设置，连接设备热点 `LED_Config`。'),
          const SizedBox(height: 12),
          const Text('如果没有看到该热点，请确认设备刚上电或尚未连入其他 WiFi。'),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () async {
              await _controller.openWifiSettings();
              if (!mounted) {
                return;
              }
              setState(() {});
            },
            child: const Text('打开系统 WiFi 设置'),
          ),
        ];
      case PairingStep.returnToApp:
        return [
          const Text('连接设备热点后返回 APP，再继续下一步。'),
          const SizedBox(height: 12),
          const Text('如果 Android 自动切回原 WiFi，请重新连接 `LED_Config` 后再继续。'),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () {
              setState(_controller.confirmApJoined);
            },
            child: const Text('我已连接，继续'),
          ),
        ];
      case PairingStep.enterWifi:
        return [
          TextFormField(
            controller: _ssidController,
            decoration: const InputDecoration(
              labelText: '家庭 WiFi 名称',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: '家庭 WiFi 密码',
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            obscureText: _obscurePassword,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () async {
              final ssid = _ssidController.text.trim();
              final password = _passwordController.text.trim();
              setState(() {
                _controller.markWaitingReconnect(ssid, password);
              });
              await _controller.submitCredentials(
                ssid: ssid,
                password: password,
                markWaiting: false,
              );
              if (!mounted) {
                return;
              }
              setState(() {});
            },
            child: const Text('发送配网信息'),
          ),
        ];
      case PairingStep.waitingReconnect:
        return [
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 16),
          const Text('正在等待设备重启并重新接入局域网，请稍候。'),
          const SizedBox(height: 12),
          Text('目标 WiFi：${_controller.state.ssid}'),
          const SizedBox(height: 8),
          Text('已等待 $_waitingSeconds 秒'),
        ];
      case PairingStep.success:
        return [
          const Text('配网成功'),
          const SizedBox(height: 12),
          Text('设备 IP：${_controller.state.resolvedIpAddress ?? '-'}'),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop(PairingFlowResult.paired);
            },
            child: const Text('完成'),
          ),
        ];
      case PairingStep.failure:
        return [
          const Text('配网失败'),
          const SizedBox(height: 12),
          Text(_controller.state.errorMessage ?? '请稍后重试'),
          if (_controller.state.diagnosticsMessage
              case final diagnostics?) ...<Widget>[
            const SizedBox(height: 16),
            Text(
              '诊断信息',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            SelectableText(diagnostics),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              setState(_controller.returnToApReconnect);
            },
            child: const Text('重新连接设备热点'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              setState(_controller.moveToApJoin);
            },
            child: const Text('重新开始'),
          ),
        ];
    }
  }

  String _stepTitle(PairingStep step) {
    switch (step) {
      case PairingStep.prepare:
        return '步骤 1/5';
      case PairingStep.joinAp:
        return '步骤 2/5';
      case PairingStep.returnToApp:
        return '步骤 3/5';
      case PairingStep.enterWifi:
      case PairingStep.failure:
        return '步骤 4/5';
      case PairingStep.waitingReconnect:
      case PairingStep.success:
        return '步骤 5/5';
    }
  }

  String _stepHeading(PairingStep step) {
    switch (step) {
      case PairingStep.prepare:
        return '准备连接设备热点';
      case PairingStep.joinAp:
        return '连接 `LED_Config`';
      case PairingStep.returnToApp:
        return '返回 APP 确认';
      case PairingStep.enterWifi:
        return '输入家庭 WiFi';
      case PairingStep.waitingReconnect:
        return '等待设备重启';
      case PairingStep.success:
        return '设备已完成配网';
      case PairingStep.failure:
        return '需要重新尝试';
    }
  }

  String _stepDescription(PairingStep step) {
    switch (step) {
      case PairingStep.prepare:
        return '这个向导会引导你完成半自动配网，并把设备登记到本地列表。';
      case PairingStep.joinAp:
        return '系统不会自动完成 WiFi 切换，你需要手动连接设备热点。';
      case PairingStep.returnToApp:
        return '确认手机已经连接到设备热点后，再继续发送家庭 WiFi。';
      case PairingStep.enterWifi:
        return 'APP 会通过 UDP 8889 将家庭 WiFi 信息发送给设备。';
      case PairingStep.waitingReconnect:
        return '设备会断开热点并重新尝试接入你的局域网。';
      case PairingStep.success:
        return '现在可以返回设备列表，进入控制页。';
      case PairingStep.failure:
        return '保留已输入内容，方便你原地重试。';
    }
  }

  void _syncWaitingFeedback(PairingStep step) {
    if (step == PairingStep.waitingReconnect) {
      _waitingTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _waitingSeconds += 1;
        });
      });
      return;
    }

    _waitingTimer?.cancel();
    _waitingTimer = null;
    _waitingSeconds = 0;
  }
}
