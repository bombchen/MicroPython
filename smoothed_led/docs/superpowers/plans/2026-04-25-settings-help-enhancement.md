# Settings Help Enhancement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 Flutter 设置 / 帮助页从三段静态文案升级为结构化帮助中心，并支持从帮助页直接进入现有配网流程。

**Architecture:** 保持 `SettingsPage` 为轻量展示页，在同一文件内用少量私有常量和 `ExpansionTile` 组织内容，不新增 controller。导航上沿用现有 `MaterialPageRoute`，让帮助页可以把配网成功结果回传给设备列表页，由设备列表页统一刷新本地列表并提示成功。

**Tech Stack:** Flutter、Material 3、flutter_test、flutter_riverpod

---

## File Structure

### Existing files to modify

- `mobile_app/led_controller/lib/features/settings/presentation/settings_page.dart`
  - 将页面标题明确为 `配网帮助`
  - 新增顶部摘要区与唯一主按钮 `去添加设备`
  - 用 3 组 `ExpansionTile` 呈现 `配网步骤`、`常见故障`、`系统与权限说明`
  - 从帮助页跳转到现有 `PairingPage`，并在配网成功后 `Navigator.pop(true)`

- `mobile_app/led_controller/lib/features/devices/presentation/device_list_page.dart`
  - 设置按钮改为 `await` 帮助页返回结果
  - 当帮助页回传 `true` 时，复用现有刷新列表与成功提示逻辑

- `mobile_app/led_controller/test/features/settings/presentation/settings_page_test.dart`
  - 锁定帮助中心结构
  - 锁定 `去添加设备` 按钮导航到现有配网页

- `mobile_app/led_controller/test/features/devices/presentation/device_list_page_test.dart`
  - 更新设置页标题断言为 `配网帮助`
  - 新增“从帮助页进入配网成功后返回列表刷新并提示成功”的回归测试

### No new files

- 本次不新增 controller、provider、model 文件
- 本次不新增图片、文档或路由配置文件

---

### Task 1: 实现结构化帮助中心内容

**Files:**
- Modify: `mobile_app/led_controller/lib/features/settings/presentation/settings_page.dart`
- Test: `mobile_app/led_controller/test/features/settings/presentation/settings_page_test.dart`
- Test: `mobile_app/led_controller/test/features/devices/presentation/device_list_page_test.dart`

- [ ] **Step 1: 写失败测试，锁定帮助中心结构**

在 `mobile_app/led_controller/test/features/settings/presentation/settings_page_test.dart` 中，把当前单一测试扩成以下两个断言块，先锁定新的页面标题、摘要区和分组结构：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:led_controller/features/settings/presentation/settings_page.dart';

void main() {
  testWidgets('帮助页展示结构化帮助中心内容', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsPage()));

    expect(find.text('配网帮助'), findsOneWidget);
    expect(find.text('去添加设备'), findsOneWidget);

    // 默认展开的步骤分组
    expect(find.text('配网步骤'), findsOneWidget);
    expect(find.text('连接设备热点 LED_Config'), findsOneWidget);
    expect(find.text('等待设备重启并回到设备列表'), findsOneWidget);

    // 默认收起但标题可见的分组
    expect(find.text('常见故障'), findsOneWidget);
    expect(find.text('系统与权限说明'), findsOneWidget);
    expect(find.text('看不到 LED_Config'), findsOneWidget);

    // FAQ 详细答案默认不展示
    expect(find.text('如果手机搜不到热点，请先确认设备刚上电。'), findsNothing);
  });
}
```

同时把 `mobile_app/led_controller/test/features/devices/presentation/device_list_page_test.dart` 里现有设置入口测试的标题断言从：

```dart
expect(find.text('网络与权限说明'), findsOneWidget);
```

改成：

```dart
expect(find.text('配网帮助'), findsOneWidget);
```

- [ ] **Step 2: 运行测试，确认它先失败**

Run:

```bash
flutter test test/features/settings/presentation/settings_page_test.dart test/features/devices/presentation/device_list_page_test.dart -r expanded
```

Expected:

- `帮助页展示结构化帮助中心内容` 失败，因为页面仍是旧标题和三段静态文本
- `点击设置按钮后进入帮助页` 失败，因为标题仍是 `网络与权限说明`

- [ ] **Step 3: 写最小实现，补齐帮助中心结构**

将 `mobile_app/led_controller/lib/features/settings/presentation/settings_page.dart` 改成单页帮助中心。保持文件轻量，不拆 controller；直接在页面内部使用私有常量列表和 `ExpansionTile`。

最小实现骨架如下：

```dart
import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static const _steps = <String>[
    '连接设备热点 LED_Config',
    '连接后返回 APP',
    '输入家庭 WiFi 名称和密码',
    '等待设备重启并回到设备列表',
  ];

  static const _faqTitles = <String>[
    '看不到 LED_Config',
    '手机提示该网络无互联网',
    'Android 自动切回原 WiFi',
    '配网完成后列表里没有新设备',
    '进入控制页后设备无响应',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('配网帮助')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('用于首次配网和常见问题排查',
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: null,
                    child: const Text('去添加设备'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ExpansionTile(
            initiallyExpanded: true,
            title: const Text('配网步骤'),
            children: _steps
                .map((item) => ListTile(title: Text(item), dense: true))
                .toList(),
          ),
          ExpansionTile(
            title: const Text('常见故障'),
            children: const [
              ListTile(title: Text('看不到 LED_Config')),
              ListTile(title: Text('手机提示该网络无互联网')),
              ListTile(title: Text('Android 自动切回原 WiFi')),
              ListTile(title: Text('配网完成后列表里没有新设备')),
              ListTile(title: Text('进入控制页后设备无响应')),
            ],
          ),
          ExpansionTile(
            title: const Text('系统与权限说明'),
            children: const [
              ListTile(title: Text('配网阶段必须手动切换到设备热点')),
              ListTile(title: Text('Android 的 WiFi 切换不完全由 APP 控制')),
              ListTile(title: Text('设备控制要求手机和设备在同一局域网')),
            ],
          ),
        ],
      ),
    );
  }
}
```

然后把 FAQ 第一项改成真正的展开内容，确保详细答案默认隐藏、点击后出现：

```dart
ExpansionTile(
  title: const Text('常见故障'),
  children: const [
    ExpansionTile(
      title: Text('看不到 LED_Config'),
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text('如果手机搜不到热点，请先确认设备刚上电。'),
        ),
      ],
    ),
    ExpansionTile(
      title: Text('手机提示该网络无互联网'),
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text('看到“无互联网”提示属于正常现象，可继续连接。'),
        ),
      ],
    ),
    // 其余 3 个问题按同样结构补齐
  ],
)
```

按钮先保留文案和位置，`onPressed` 在下一任务接通，当前可以先用 `onPressed: () {}` 或暂时填空实现。

- [ ] **Step 4: 运行聚焦测试，确认帮助中心结构通过**

Run:

```bash
flutter test test/features/settings/presentation/settings_page_test.dart test/features/devices/presentation/device_list_page_test.dart -r expanded
```

Expected:

- `帮助页展示结构化帮助中心内容` PASS
- `点击设置按钮后进入帮助页` PASS
- 其他列表页测试继续通过

- [ ] **Step 5: 提交这一批结构化内容改动**

```bash
git add mobile_app/led_controller/lib/features/settings/presentation/settings_page.dart \
        mobile_app/led_controller/test/features/settings/presentation/settings_page_test.dart \
        mobile_app/led_controller/test/features/devices/presentation/device_list_page_test.dart
git commit -m "feat: expand settings help content"
```

---

### Task 2: 接通帮助页到配网流程的导航闭环

**Files:**
- Modify: `mobile_app/led_controller/lib/features/settings/presentation/settings_page.dart`
- Modify: `mobile_app/led_controller/lib/features/devices/presentation/device_list_page.dart`
- Test: `mobile_app/led_controller/test/features/settings/presentation/settings_page_test.dart`
- Test: `mobile_app/led_controller/test/features/devices/presentation/device_list_page_test.dart`

- [ ] **Step 1: 写失败测试，锁定“去添加设备”导航与回传刷新**

先在 `mobile_app/led_controller/test/features/settings/presentation/settings_page_test.dart` 中新增一个导航测试，确认按钮会进入现有配网页：

```dart
testWidgets('帮助页点击去添加设备后进入配网页', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: SettingsPage()));

  await tester.tap(find.text('去添加设备'));
  await tester.pumpAndSettle();

  expect(find.text('添加设备'), findsOneWidget);
  expect(find.text('开始配网'), findsOneWidget);
});
```

再在 `mobile_app/led_controller/test/features/devices/presentation/device_list_page_test.dart` 中新增完整回归测试，锁定“从帮助页进入配网成功后，列表刷新并提示成功”：

```dart
testWidgets('从帮助页进入配网成功后返回列表刷新并提示成功', (tester) async {
  final repository = FakeDeviceRepository(<LedDevice>[]);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        deviceRepositoryProvider.overrideWithValue(repository),
        udpClientProvider.overrideWithValue(FakeUdpClient()),
        pairingCoordinatorProvider
            .overrideWithValue(FakePairingCoordinator(repository)),
      ],
      child: const MaterialApp(home: DeviceListPage()),
    ),
  );

  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pumpAndSettle();

  expect(find.text('配网帮助'), findsOneWidget);

  await tester.tap(find.text('去添加设备'));
  await tester.pumpAndSettle();
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
  await tester.tap(find.text('完成'));
  await tester.pumpAndSettle();

  expect(find.text('新灯带'), findsOneWidget);
  expect(find.text('192.168.1.45'), findsOneWidget);
  expect(find.text('设备已添加'), findsOneWidget);
});
```

- [ ] **Step 2: 运行测试，确认导航闭环还没接通**

Run:

```bash
flutter test test/features/settings/presentation/settings_page_test.dart test/features/devices/presentation/device_list_page_test.dart -r expanded
```

Expected:

- `帮助页点击去添加设备后进入配网页` 失败，因为按钮还没有跳转逻辑
- `从帮助页进入配网成功后返回列表刷新并提示成功` 失败，因为设置页不会把 `true` 回传给设备列表页

- [ ] **Step 3: 写最小实现，接通帮助页与设备列表页之间的结果传递**

先在 `mobile_app/led_controller/lib/features/settings/presentation/settings_page.dart` 顶部引入现有配网页：

```dart
import '../../pairing/presentation/pairing_page.dart';
```

把按钮改成真正跳转，并在配网成功后向外层页面回传 `true`：

```dart
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
    Navigator.of(context).pop(true);
  },
  child: const Text('去添加设备'),
),
```

再把 `mobile_app/led_controller/lib/features/devices/presentation/device_list_page.dart` 的设置入口改成等待帮助页返回值，命中 `true` 时复用现有刷新逻辑：

```dart
IconButton(
  icon: const Icon(Icons.settings_outlined),
  onPressed: () async {
    final paired = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const SettingsPage(),
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
),
```

这里不要新建公共 helper，先复用现有最小逻辑，保持改动集中。

- [ ] **Step 4: 运行聚焦测试，确认帮助页导航闭环通过**

Run:

```bash
flutter test test/features/settings/presentation/settings_page_test.dart test/features/devices/presentation/device_list_page_test.dart -r expanded
```

Expected:

- `帮助页点击去添加设备后进入配网页` PASS
- `从帮助页进入配网成功后返回列表刷新并提示成功` PASS
- 现有 `配网成功返回后刷新设备列表并提示成功` 仍然 PASS

- [ ] **Step 5: 提交导航闭环改动**

```bash
git add mobile_app/led_controller/lib/features/settings/presentation/settings_page.dart \
        mobile_app/led_controller/lib/features/devices/presentation/device_list_page.dart \
        mobile_app/led_controller/test/features/settings/presentation/settings_page_test.dart \
        mobile_app/led_controller/test/features/devices/presentation/device_list_page_test.dart
git commit -m "feat: route help page into pairing flow"
```

---

### Task 3: 做全量回归，确认帮助页增强没有带出别的回归

**Files:**
- Verify only: `mobile_app/led_controller/lib/features/settings/presentation/settings_page.dart`
- Verify only: `mobile_app/led_controller/lib/features/devices/presentation/device_list_page.dart`
- Verify only: `mobile_app/led_controller/test/features/settings/presentation/settings_page_test.dart`
- Verify only: `mobile_app/led_controller/test/features/devices/presentation/device_list_page_test.dart`

- [ ] **Step 1: 运行 analyzer**

Run:

```bash
flutter analyze
```

Expected:

```text
No issues found!
```

- [ ] **Step 2: 运行全量测试**

Run:

```bash
flutter test -r expanded
```

Expected:

- 设置页测试全部 PASS
- 设备列表页测试全部 PASS
- 配网页、控制页和应用 smoke test 全部 PASS

- [ ] **Step 3: 记录回归结果并准备执行收尾**

在任务记录里确认以下结果：

```text
- SettingsPage 已升级为结构化帮助中心
- 去添加设备按钮可进入现有配网页
- 从帮助页进入配网成功后可回到设备列表并刷新
- 现有直接配网入口行为未回归
```

本步骤不修改代码，只整理验证结果，供后续执行收尾流程使用。

---

## Self-Review Checklist

- Spec coverage:
  - 单页帮助中心结构由 Task 1 覆盖
  - 顶部唯一主动作与帮助页文案风格由 Task 1 覆盖
  - 从帮助页进入配网流程并回传结果由 Task 2 覆盖
  - 全量验证与回归确认由 Task 3 覆盖
- Placeholder scan:
  - 无 `TODO` / `TBD`
  - 每个测试任务都给出了实际测试代码与命令
  - 每个实现任务都给出了实际代码骨架与提交命令
- Type consistency:
  - 页面名统一使用 `SettingsPage`
  - 配网页统一使用 `PairingPage`
  - 列表刷新统一使用 `deviceListProvider`

