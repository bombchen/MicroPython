import 'package:flutter/material.dart';

import 'router.dart';

class LedControllerApp extends StatelessWidget {
  const LedControllerApp({super.key});

  static const String _title = 'LED Controller';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: _title,
      theme: ThemeData(colorSchemeSeed: Colors.orange),
      initialRoute: '/',
      onGenerateRoute: buildLedRoute,
    );
  }
}
