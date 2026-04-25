# LED Controller Mobile App

## 目标

这是 `smoothed_led` 项目的 Flutter Android 控制端。

## 本地开发

```bash
cd mobile_app/led_controller
flutter pub get
flutter test
```

## Android 环境要求

- Flutter 3.13.8
- JDK 17
- Android SDK Platform 34
- Android Build-Tools 36.1.0
- 已连接 Android 真机或已启动模拟器

当前工程已在 `android/gradle.properties` 中固定 Gradle 使用 `Temurin 17`，用于兼容本地 Flutter 3.13.8 和 Android 集成测试构建。

## 真机集成测试

```bash
cd mobile_app/led_controller
flutter test integration_test -r expanded
```

已验证可在连接的 Android 设备上通过：

- `integration_test/pairing_flow_test.dart`
- `integration_test/device_control_flow_test.dart`

## 关键能力

- 配网向导
- 设备登记
- UDP 状态查询
- UDP 模式切换
- UDP 亮度调节
