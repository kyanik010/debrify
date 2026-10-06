import 'package:flutter/material.dart';
import 'screens/home.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const IptvLiteApp());
}

class IptvLiteApp extends StatelessWidget {
  const IptvLiteApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'IPTV Lite',
    theme: ThemeData.dark(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: const Color(0xFF0B0D10),
      colorScheme: const ColorScheme.dark(primary: Color(0xFF6EA8FE)),
    ),
    home: const HomeScreen(),
  );
}
