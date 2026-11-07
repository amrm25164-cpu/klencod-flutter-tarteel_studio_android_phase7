import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TarteelStudioApp());
}

class TarteelStudioApp extends StatelessWidget {
  const TarteelStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFFB78A45);
    return MaterialApp(
      title: 'Tarteel Studio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
          surface: const Color(0xFF151719),
        ),
        scaffoldBackgroundColor: const Color(0xFF101213),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF101213),
          centerTitle: false,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF222729),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}