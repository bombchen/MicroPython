import 'package:android_intent_plus/android_intent.dart';

import 'wifi_settings_launcher.dart';

class AndroidWifiSettingsLauncher implements WifiSettingsLauncher {
  @override
  Future<void> openWifiSettings() async {
    const intent = AndroidIntent(action: 'android.settings.WIFI_SETTINGS');
    await intent.launch();
  }
}
