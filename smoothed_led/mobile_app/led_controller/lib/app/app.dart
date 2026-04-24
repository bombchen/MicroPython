import 'package:flutter/material.dart';

import 'router.dart';

class LedControllerApp extends StatelessWidget {
  const LedControllerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LED Controller',
      theme: ThemeData(colorSchemeSeed: Colors.orange),
      onGenerateRoute: buildLedRoute,
      initialRoute: '/',
    );
  }
}
