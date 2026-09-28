import 'package:flutter/material.dart';

import 'config.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const MaykelRepuestosApp());
}

class MaykelRepuestosApp extends StatelessWidget {
  const MaykelRepuestosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Maykel Repuestos',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const HomeScreen(),
    );
  }
}
