import 'package:flutter/material.dart';

import 'services/services.dart';
import 'ui/screens/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Services.init();
  runApp(const RabbitApp());
}

class RabbitApp extends StatelessWidget {
  const RabbitApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFFD55E00); // warm orange, Apollo-adjacent
    return MaterialApp(
      title: 'Rabbit',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        visualDensity: VisualDensity.comfortable,
      ),
      darkTheme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
        visualDensity: VisualDensity.comfortable,
      ),
      themeMode: ThemeMode.system,
      home: const HomeShell(),
    );
  }
}
