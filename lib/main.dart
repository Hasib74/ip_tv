import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase initialization failed: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Premium theme for Sportzfy Clone
    final ColorScheme customColorScheme = ColorScheme.fromSeed(
      seedColor: Colors.cyanAccent,
      brightness: Brightness.dark,
      surface: const Color(0xFF0D1117),
      onSurface: Colors.white,
      primary: Colors.cyanAccent,
      secondary: Colors.cyan,
      onPrimary: Colors.black,
    );

    return MaterialApp(
      title: 'Sportzfy IPTV',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: customColorScheme,
        scaffoldBackgroundColor: customColorScheme.surface,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: Colors.white),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E2746),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
