import 'package:flutter/material.dart';
import 'screens.dart';

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'GymProgress',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
            useMaterial3: true, brightness: Brightness.dark, colorSchemeSeed: Colors.green),
        home: const Shell(),
      );
}
