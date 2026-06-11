import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'services/firebase_service.dart';
import 'services/ad_service.dart';

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Handling a background message: ${message.messageId}");
}

void main()  async{
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  
  // Await Ads initialization and start background listeners
  await AdService.initialize();
  
  // Register your specific test device ID found in logs
  MobileAds.instance.updateRequestConfiguration(
    const RequestConfiguration(testDeviceIds: ["0C74070AAB4D1DF78357CC57AEDEB783"]),
  );

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize Local Notifications and Permissions
    await NotificationService.initialize();
    
    // Set background message listener
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Foreground notification listener
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint("Foreground message received: Title: ${message.notification?.title}, Data: ${message.data}");
      NotificationService.showNotification(message);
    });

    // Save user FCM token to Firestore for later use
    FirebaseService().saveDeviceToken();
    
    // Subscribe to a general topic for broadcast notifications
    FirebaseMessaging.instance.subscribeToTopic('all_users');

  } catch (e) {
    debugPrint("Firebase/Notification initialization failed: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});




  @override
  Widget build(BuildContext context) {
    // Premium theme based on the logo's Orange, White, and Dark Grey palette
    final ColorScheme customColorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFFF8000), // Logo Orange
      brightness: Brightness.dark,
      surface: const Color(0xFF0F0F0F), // Dark Grey from logo background
      onSurface: Colors.white,
      primary: const Color(0xFFFF8000), // Main Orange
      secondary: const Color(0xFFFFB300), // Secondary Amber/Orange
      onPrimary:Color(0xFF0B1A30),
    );

    return MaterialApp(
      title: 'SponT TV',
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
          color: const Color(0xFF1A1A1A), // Subtle grey card
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
