# LED 控制器产品化 UI 改造 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 Flutter `led_controller` 从工程感较强的控制工具界面改造成更像正规家居消费品的产品界面，同时保持现有配网、设备控制和帮助流程不回归。

**Architecture:** 保留现有 Riverpod、路由、配网状态机和控制器逻辑，只重构表现层。先建立统一主题，再依次重做设备列表页、控制页、配网页和帮助页的页面骨架与状态反馈，并通过现有 widget tests 的定向更新锁定视觉结构和核心交互。

**Tech Stack:** Flutter、Material 3 主题系统、Riverpod、widget tests、现有 Flutter test suite

---

## 文件边界

### 主题与应用壳

- Modify: `mobile_app/led_controller/lib/app/app.dart`
  责任：建立统一的消费品化主题系统和全局背景风格。

### 设备列表页

- Modify: `mobile_app/led_controller/lib/features/devices/presentation/device_list_page.dart`
  责任：把首页从平铺列表改成“家庭灯光首页”结构。
- Modify: `mobile_app/led_controller/test/features/devices/presentation/device_list_page_test.dart`
  责任：校验欢迎区、空状态卡、设备卡和刷新后的首页摘要。

### 设备控制页

- Modify: `mobile_app/led_controller/lib/features/devices/presentation/device_control_page.dart`
  责任：把控制页改成主操作优先的设备遥控页。
- Modify: `mobile_app/led_controller/test/features/devices/presentation/device_control_page_test.dart`
  责任：校验设备头卡、主控制区、音乐模式入口和更多操作入口。

### 配网页

- Modify: `mobile_app/led_controller/lib/features/pairing/presentation/pairing_page.dart`
  责任：把配网页改成陪伴式添加流程，强化步骤感和状态反馈。
- Modify: `mobile_app/led_controller/test/features/pairing/presentation/pairing_page_test.dart`
  责任：校验步骤头部、等待/失败/成功反馈和关键 CTA 仍然可用。

### 支持中心

- Modify: `mobile_app/led_controller/lib/features/settings/presentation/settings_page.dart`
  责任：把帮助页改成支持中心。
- Modify: `mobile_app/led_controller/test/features/settings/presentation/settings_page_test.dart`
  责任：校验支持中心头部、主操作卡和 FAQ 展开行为。

### 回归验证

- Modify: none expected

## 实施顺序

1. 先定全局主题，避免后续页面各自为战。
2. 再改设备列表页，先提升首页第一印象。
3. 然后改设备控制页，这是高频核心页面。
4. 接着改配网页，确保引导体验消费品化。
5. 最后改帮助页并做全量回归。

### Task 1: 建立全局消费品化主题

**Files:**
- Modify: `mobile_app/led_controller/lib/app/app.dart`
- Test: `mobile_app/led_controller/test/app/app_smoke_test.dart`

- [ ] **Step 1: 先补失败测试，锁定应用主题不再是默认种子色风格**

```dart
testWidgets('应用使用消费品化浅暖主题', (tester) async {
  await tester.pumpWidget(const LedControllerApp());

  final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
  final theme = materialApp.theme!;

  expect(theme.scaffoldBackgroundColor, isNot(Colors.white));
  expect(theme.cardTheme.shape, isNotNull);
  expect(theme.filledButtonTheme.style, isNotNull);
});
```

- [ ] **Step 2: 运行主题相关测试，确认新断言先失败**

Run: `flutter test test/app/app_smoke_test.dart`

Expected:

```text
Expected: not Colors.white
  Actual: <Color(0xffffffff)>
```

- [ ] **Step 3: 在 `app.dart` 中实现统一主题**

```dart
class LedControllerApp extends StatelessWidget {
  const LedControllerApp({super.key});

  static const _title = 'LED Controller';

  @override
  Widget build(BuildContext context) {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFFCB7A36),
      onPrimary: Colors.white,
      secondary: Color(0xFF8BA8A1),
      onSecondary: Colors.white,
      error: Color(0xFFB45E52),
      onError: Colors.white,
      background: Color(0xFFF6F1EA),
      onBackground: Color(0xFF2D241E),
      surface: Colors.white,
      onSurface: Color(0xFF2D241E),
      tertiary: Color(0xFFE1B85B),
      onTertiary: Color(0xFF2D241E),
      surfaceVariant: Color(0xFFF1E6D8),
      onSurfaceVariant: Color(0xFF5F544B),
      outline: Color(0xFFD9C8B5),
      outlineVariant: Color(0xFFEADFD2),
      shadow: Color(0x14000000),
      scrim: Color(0x52000000),
      inverseSurface: Color(0xFF332A25),
      onInverseSurface: Color(0xFFF6F1EA),
      inversePrimary: Color(0xFFF0B37A),
    );

    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.background,
      cardTheme: CardTheme(
        color: colorScheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.background,
        foregroundColor: colorScheme.onBackground,
        elevation: 0,
        centerTitle: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
      ),
    );

    return MaterialApp(
      title: _title,
      theme: theme,
      initialRoute: '/',
      onGenerateRoute: buildLedRoute,
    );
  }
}
```

- [ ] **Step 4: 重新运行主题测试，确认新主题生效**

Run: `flutter test test/app/app_smoke_test.dart`

Expected:

```text
All tests passed!
```

- [ ] **Step 5: 提交 Task 1**

```bash
git add \
  mobile_app/led_controller/lib/app/app.dart \
  mobile_app/led_controller/test/app/app_smoke_test.dart
git commit -m "feat: add consumer product theme"
```

### Task 2: 重做设备列表页为家庭灯光首页

**Files:**
- Modify: `mobile_app/led_controller/lib/features/devices/presentation/device_list_page.dart`
- Modify: `mobile_app/led_controller/test/features/devices/presentation/device_list_page_test.dart`

- [ ] **Step 1: 先补失败测试，锁定首页欢迎区、空状态卡和设备卡结构**

```dart
testWidgets('设备列表页展示家庭灯光首页头部和主按钮', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        deviceRepositoryProvider.overrideWithValue(FakeDeviceRepository(const [])),
      ],
      child: const MaterialApp(home: DeviceListPage()),
    ),
  );

  await tester.pumpAndSettle();

  expect(find.text('我的灯光'), findsOneWidget);
  expect(find.text('随时调出家里的氛围'), findsOneWidget);
  expect(find.text('添加第一台灯带'), findsOneWidget);
});
```

```dart
testWidgets('设备列表页用设备卡展示状态摘要', (tester) async {
  final devices = [
    LedDevice(
      id: 'device-1',
      name: '客厅灯带',
      ipAddress: '192.168.1.23',
      lastSeenAt: DateTime(2026, 4, 24, 21),
      lastKnownStatus: const DeviceStatus(
        mode: EffectMode.fire,
        brightness: 180,
        connectionState: DeviceConnectionState.online,
      ),
      createdAt: DateTime(2026, 4, 24, 20),
      updatedAt: DateTime(2026, 4, 24, 21),
    ),
  ];

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        deviceRepositoryProvider.overrideWithValue(FakeDeviceRepository(devices)),
        udpClientProvider.overrideWithValue(FakeUdpClient()),
      ],
      child: const MaterialApp(home: DeviceListPage()),
    ),
  );

  await tester.pumpAndSettle();

  expect(find.text('客厅灯带'), findsOneWidget);
  expect(find.text('火焰'), findsOneWidget);
  expect(find.text('在线'), findsOneWidget);
});
```

- [ ] **Step 2: 运行列表页测试，确认新首页文案和摘要断言先失败**

Run: `flutter test test/features/devices/presentation/device_list_page_test.dart`

Expected:

```text
Expected: exactly one matching node in the widget tree
  Actual: _TextFinder:<zero widgets with text "我的灯光">
```

- [ ] **Step 3: 重写 `device_list_page.dart` 的页面骨架，改成首页卡片结构**

```dart
return Scaffold(
  appBar: AppBar(
    title: const Text('我的灯光'),
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
          final result = await Navigator.of(context).push<PairingFlowResult>(
            MaterialPageRoute(builder: (_) => const SettingsPage()),
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
                  Text('我的灯光', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  Text('随时调出家里的氛围'),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () async {
                      final result = await Navigator.of(context).push<PairingFlowResult>(
                        MaterialPageRoute(builder: (_) => const PairingPage()),
                      );
                      if (result != PairingFlowResult.paired || !context.mounted) {
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
                  children: const [
                    Icon(Icons.light_outlined, size: 48),
                    SizedBox(height: 16),
                    Text('还没有设备'),
                    SizedBox(height: 8),
                    Text('添加灯带后，你就可以在这里查看状态并调整灯效。'),
                  ],
                ),
              ),
            )
          else
            ...devices.map((device) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _DeviceCard(
                device: device,
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => DeviceControlPage(device: device)),
                  );
                  ref.invalidate(deviceListProvider);
                },
              ),
            )),
        ],
      );
    },
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (error, _) => const Center(child: Text('加载设备失败')),
  ),
);
```

- [ ] **Step 4: 重新运行列表页测试，确认首页结构和既有刷新逻辑都通过**

Run: `flutter test test/features/devices/presentation/device_list_page_test.dart`

Expected:

```text
All tests passed!
```

- [ ] **Step 5: 提交 Task 2**

```bash
git add \
  mobile_app/led_controller/lib/features/devices/presentation/device_list_page.dart \
  mobile_app/led_controller/test/features/devices/presentation/device_list_page_test.dart
git commit -m "feat: refresh device list home ui"
```

### Task 3: 重做设备控制页为遥控器式布局

**Files:**
- Modify: `mobile_app/led_controller/lib/features/devices/presentation/device_control_page.dart`
- Modify: `mobile_app/led_controller/test/features/devices/presentation/device_control_page_test.dart`

- [ ] **Step 1: 先补失败测试，锁定设备头卡、主亮度卡和更多操作入口**

```dart
testWidgets('控制页展示设备头卡和主控制区', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        udpClientProvider.overrideWithValue(FakeUdpClient()),
        deviceRepositoryProvider.overrideWithValue(FakeDeviceRepository()),
      ],
      child: MaterialApp(home: DeviceControlPage(device: buildDevice())),
    ),
  );
  await tester.pumpAndSettle();

  expect(find.text('设备状态'), findsOneWidget);
  expect(find.text('亮度调节'), findsOneWidget);
  expect(find.text('常用灯效'), findsOneWidget);
});
```

```dart
testWidgets('控制页通过更多菜单暴露重命名和删除', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        udpClientProvider.overrideWithValue(FakeUdpClient()),
        deviceRepositoryProvider.overrideWithValue(FakeDeviceRepository()),
      ],
      child: MaterialApp(home: DeviceControlPage(device: buildDevice())),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.byIcon(Icons.more_horiz));
  await tester.pumpAndSettle();

  expect(find.text('重命名设备'), findsOneWidget);
  expect(find.text('删除设备'), findsOneWidget);
});
```

- [ ] **Step 2: 运行控制页测试，确认新结构断言先失败**

Run: `flutter test test/features/devices/presentation/device_control_page_test.dart`

Expected:

```text
Expected: exactly one matching node in the widget tree
  Actual: _TextFinder:<zero widgets with text "设备状态">
```

- [ ] **Step 3: 重写 `device_control_page.dart` 的页面结构**

```dart
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
          PopupMenuItem(value: 'rename', child: Text('重命名设备')),
          PopupMenuItem(value: 'delete', child: Text('删除设备')),
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
            Text(_statusLabel(status.connectionState)),
            const SizedBox(height: 8),
            Text('最近同步: ${_formatDateTime(_device.lastSeenAt)}'),
            const SizedBox(height: 8),
            Text('IP: ${_device.ipAddress}'),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _SectionCard(
        title: '当前模式',
        child: Text(_modeLabel(status.mode)),
      ),
      const SizedBox(height: 16),
      _SectionCard(
        title: '亮度调节',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${(_pendingBrightness ?? status.brightness.toDouble()).round()}'),
            Slider(
              value: (_pendingBrightness ?? status.brightness.toDouble()).clamp(0, 255).toDouble(),
              min: 0,
              max: 255,
              divisions: 255,
              onChanged: isBusy ? null : (value) {
                setState(() {
                  _pendingBrightness = value;
                });
              },
              onChangeEnd: isBusy ? null : (value) {
                _controller.setBrightness(_device.ipAddress, value.round());
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
              onSelected: isBusy ? null : (_) => _controller.setMode(_device.ipAddress, mode),
            );
          }).toList(),
        ),
      ),
    ],
  ),
);
```

- [ ] **Step 4: 重新运行控制页测试，确认音乐模式入口、菜单操作和主控制区通过**

Run: `flutter test test/features/devices/presentation/device_control_page_test.dart`

Expected:

```text
All tests passed!
```

- [ ] **Step 5: 提交 Task 3**

```bash
git add \
  mobile_app/led_controller/lib/features/devices/presentation/device_control_page.dart \
  mobile_app/led_controller/test/features/devices/presentation/device_control_page_test.dart
git commit -m "feat: refresh device control ui"
```

### Task 4: 重做配网页为陪伴式添加流程

**Files:**
- Modify: `mobile_app/led_controller/lib/features/pairing/presentation/pairing_page.dart`
- Modify: `mobile_app/led_controller/test/features/pairing/presentation/pairing_page_test.dart`

- [ ] **Step 1: 先补失败测试，锁定步骤头部、等待文案和成功页主按钮**

```dart
testWidgets('配网页面展示步骤头部和引导副标题', (tester) async {
  final coordinator = FakePairingCoordinator();

  await tester.pumpWidget(
    MaterialApp(
      home: PairingPage(
        controller: PairingController(coordinator: coordinator),
      ),
    ),
  );

  expect(find.text('添加新的灯带设备'), findsOneWidget);
  expect(find.textContaining('跟着步骤完成连接'), findsOneWidget);
});
```

```dart
testWidgets('配网成功页展示开始控制设备按钮', (tester) async {
  final coordinator = FakePairingCoordinator();

  await tester.pumpWidget(
    MaterialApp(
      home: PairingPage(
        controller: PairingController(coordinator: coordinator),
      ),
    ),
  );

  await tester.tap(find.text('开始配网'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('打开系统 WiFi 设置'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('我已连接，继续'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField).at(0), 'HomeWiFi');
  await tester.enterText(find.byType(TextFormField).at(1), '12345678');
  await tester.tap(find.text('发送配网信息'));
  await tester.pumpAndSettle();

  expect(find.text('开始控制设备'), findsOneWidget);
});
```

- [ ] **Step 2: 运行配网页测试，确认新头部和成功 CTA 先失败**

Run: `flutter test test/features/pairing/presentation/pairing_page_test.dart`

Expected:

```text
Expected: exactly one matching node in the widget tree
  Actual: _TextFinder:<zero widgets with text "添加新的灯带设备">
```

- [ ] **Step 3: 重写 `pairing_page.dart` 的页面头部和步骤表现层**

```dart
return Scaffold(
  appBar: AppBar(title: const Text('添加设备')),
  body: ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('添加新的灯带设备', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text('跟着步骤完成连接，通常只需要几十秒。'),
              const SizedBox(height: 16),
              Text(_stepTitle(state.step)),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: (_stepNumber(state.step)) / 5,
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_stepHeading(state.step), style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Text(_stepDescription(state.step)),
              const SizedBox(height: 24),
              ..._buildStepContent(context, state.step),
            ],
          ),
        ),
      ),
    ],
  ),
);
```

```dart
case PairingStep.success:
  return [
    const Icon(Icons.check_circle_outline, size: 56),
    const SizedBox(height: 16),
    const Text('配网成功'),
    const SizedBox(height: 12),
    Text('设备 IP：${_controller.state.resolvedIpAddress ?? '-'}'),
    const SizedBox(height: 24),
    FilledButton(
      onPressed: () {
        Navigator.of(context).pop(PairingFlowResult.paired);
      },
      child: const Text('开始控制设备'),
    ),
  ];
```

- [ ] **Step 4: 重新运行配网页测试，确认步骤头部、失败恢复和成功页 CTA 全部通过**

Run: `flutter test test/features/pairing/presentation/pairing_page_test.dart`

Expected:

```text
All tests passed!
```

- [ ] **Step 5: 提交 Task 4**

```bash
git add \
  mobile_app/led_controller/lib/features/pairing/presentation/pairing_page.dart \
  mobile_app/led_controller/test/features/pairing/presentation/pairing_page_test.dart
git commit -m "feat: refresh pairing flow ui"
```

### Task 5: 重做帮助页为支持中心

**Files:**
- Modify: `mobile_app/led_controller/lib/features/settings/presentation/settings_page.dart`
- Modify: `mobile_app/led_controller/test/features/settings/presentation/settings_page_test.dart`

- [ ] **Step 1: 先补失败测试，锁定支持中心头部和主操作卡**

```dart
testWidgets('帮助页展示支持中心头部和主操作区', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        pairingCoordinatorProvider.overrideWithValue(FakePairingCoordinator()),
      ],
      child: const MaterialApp(home: SettingsPage()),
    ),
  );

  expect(find.text('支持中心'), findsOneWidget);
  expect(find.text('我们会一步步帮你连接和排查设备'), findsOneWidget);
  expect(find.text('添加新设备'), findsOneWidget);
});
```

- [ ] **Step 2: 运行帮助页测试，确认新头部断言先失败**

Run: `flutter test test/features/settings/presentation/settings_page_test.dart`

Expected:

```text
Expected: exactly one matching node in the widget tree
  Actual: _TextFinder:<zero widgets with text "支持中心">
```

- [ ] **Step 3: 重写 `settings_page.dart` 的页面结构**

```dart
return Scaffold(
  appBar: AppBar(title: const Text('支持中心')),
  body: ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('支持中心', style: textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text('我们会一步步帮你连接和排查设备'),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('常用操作'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  final result = await Navigator.of(context).push<PairingFlowResult>(
                    MaterialPageRoute(builder: (_) => const PairingPage()),
                  );
                  if (result != PairingFlowResult.paired || !context.mounted) {
                    return;
                  }
                  Navigator.of(context).pop(PairingFlowResult.paired);
                },
                child: const Text('添加新设备'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () async {
                  await ref.read(pairingCoordinatorProvider).resetConfiguration();
                  if (!context.mounted) {
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('设备已重置，请重新连接 LED_Config 后重新配网')),
                  );
                },
                child: const Text('重置设备配网'),
              ),
            ],
          ),
        ),
      ),
    ],
  ),
);
```

- [ ] **Step 4: 重新运行帮助页测试，确认支持中心主操作和 FAQ 展开都通过**

Run: `flutter test test/features/settings/presentation/settings_page_test.dart`

Expected:

```text
All tests passed!
```

- [ ] **Step 5: 提交 Task 5**

```bash
git add \
  mobile_app/led_controller/lib/features/settings/presentation/settings_page.dart \
  mobile_app/led_controller/test/features/settings/presentation/settings_page_test.dart
git commit -m "feat: refresh support center ui"
```

### Task 6: 全量回归与手工验收

**Files:**
- Modify: none expected

- [ ] **Step 1: 运行与本次 UI 改造直接相关的 widget tests**

Run: `flutter test test/app/app_smoke_test.dart test/features/devices/presentation/device_list_page_test.dart test/features/devices/presentation/device_control_page_test.dart test/features/pairing/presentation/pairing_page_test.dart test/features/settings/presentation/settings_page_test.dart`

Expected:

```text
All tests passed!
```

- [ ] **Step 2: 运行 Flutter 全量测试**

Run: `flutter test`

Expected:

```text
All tests passed!
```

- [ ] **Step 3: 做静态核对，确认关键页面已经切到产品化文案和结构**

Run: `rg -n '我的灯光|添加第一台灯带|设备状态|亮度调节|添加新的灯带设备|开始控制设备|支持中心' lib test`

Expected:

```text
lib/...
test/...
```

- [ ] **Step 4: 做手工界面验收**

```text
1. 首页打开后先看到欢迎区和明确的主按钮。
2. 空状态页应像消费品首页，而不是纯文字提示。
3. 有设备时每个设备应以卡片显示，状态摘要易扫读。
4. 控制页第一屏应能看到设备状态、当前模式和亮度主控。
5. 配网页每一步都应有明显步骤感，不再像纯说明书。
6. 帮助页应先看到支持中心头部和主操作区。
7. 所有页面在窄屏下不应出现溢出或按钮挤压。
```

- [ ] **Step 5: 提交最终状态检查**

Run: `git status --short`

Expected:

```text
nothing to commit, working tree clean
```
