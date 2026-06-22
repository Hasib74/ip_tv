import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../firebase_options.dart';
import '../services/ad_service.dart';
import '../services/firebase_service.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();
    
    // Background initialization start immediately
    _initApp();
  }

  Future<void> _initApp() async {
    // Start measuring time to ensure splash shows for at least 2 seconds
    final startTime = DateTime.now();

    try {
      // 1. Firebase Background Init
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      
      // 2. Check for Force Update
      await _checkUpdate();
      
      setState(() {
        _isInitialized = true;
      });

      // Calculate how much longer we should stay on splash
      final elapsed = DateTime.now().difference(startTime);
      final remaining = const Duration(seconds: 2) - elapsed;
      
      if (remaining > Duration.zero) {
        await Future.delayed(remaining);
      }
      
      if (mounted) {
        // App Open Ad showing logic
        AdService.showAppOpenAdIfAvailable();
        
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    } catch (e) {
      debugPrint("Background Initialization error: $e");
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    }
  }

  Future<void> _checkUpdate() async {
    final firebaseService = AppFirebaseService();
    final config = await firebaseService.getAppVersionConfig();
    
    if (config != null) {
      final latestVersionName = config['latest_version'] as String;
      final latestBuildNumber = config['latest_build_number'] as int;
      final downloadUrl = config['download_url'] as String;
      
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      int currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;
      
      // Compare build numbers (Version Code)
      if (currentBuildNumber < latestBuildNumber) {
        if (mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => WillPopScope(
              onWillPop: () async => false,
              child: AlertDialog(
                title: const Text('Update Required', style: TextStyle(fontWeight: FontWeight.bold)),
                content: Text('A new version ($latestVersionName) is available. Please update to continue using SponT TV.'),
                actions: [
                  TextButton(
                    onPressed: () async {
                      final url = Uri.parse(downloadUrl);
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    },
                    child: const Text('Update Now', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Premium Logo Container
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.03),
                        border: Border.all(color: colorScheme.primary.withOpacity(0.1)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(100),
                        child: Image.asset(
                          'assets/images/icon.jpeg',
                          height: 140,
                          width: 140,
                          fit: BoxFit.fill,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    // App Name with Spacing
                    Text(
                      "SponT TV",
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Subtle Loading Bar
                    SizedBox(
                      width: 100,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          backgroundColor: colorScheme.primary.withOpacity(0.05),
                          color: colorScheme.primary,
                          minHeight: 3,
                          // If not initialized, show indeterminate, else full
                          value: _isInitialized ? 1.0 : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
