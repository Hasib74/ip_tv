import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

class AdService {
  static AppOpenAd? _appOpenAd;
  static bool _isShowingAd = false;
  static bool _isLoadingAppOpenAd = false;
  static DateTime? _lastAppOpenShownTime;
  
  static InterstitialAd? _interstitialAd;
  static int _interstitialCounter = 0;

  // Ad Unit IDs
  static String get appOpenUnitId => kDebugMode 
      ? 'ca-app-pub-3940256099942544/9257395921' // Corrected Android Test ID
      : 'ca-app-pub-9914807097694036/1810668479';

  static String get bannerUnitId => kDebugMode 
      ? 'ca-app-pub-3940256099942544/6300978111' // Android Test ID
      : 'ca-app-pub-9914807097694036/4367559370';

  static String get interstitialUnitId => kDebugMode 
      ? 'ca-app-pub-3940256099942544/1033173712' // Android Test ID
      : 'ca-app-pub-9914807097694036/9114443425';

  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
    loadAppOpenAd();
    loadInterstitialAd();

    // 1. App Resume হলে অ্যাড দেখানোর জন্য (Standard App Open Behavior)
    AppLifecycleListener(
      onStateChange: (state) {
        if (state == AppLifecycleState.resumed) {
          debugPrint('AppLifecycle: Resumed, checking for AppOpenAd...');
          showAppOpenAdIfAvailable();
        }
      },
    );

    // 2. অ্যাপের ভেতরে থাকা অবস্থায় প্রতি ১ মিনিট পর পর চেক করবে ১৫ মিনিট হয়েছে কি না
    // যদি ১৫ মিনিট হয়ে যায়, তবে অটো অ্যাড দেখাবে (আপনার চাওয়া অনুযায়ী)
    Timer.periodic(const Duration(minutes: 1), (timer) {
      debugPrint('AdTimer: Checking if 15 mins passed for auto ad...');
      showAppOpenAdIfAvailable();
    });
  }

  // --- App Open Ad ---
  static void loadAppOpenAd() {
    if (_appOpenAd != null || _isLoadingAppOpenAd) return;

    _isLoadingAppOpenAd = true;
    debugPrint('AppOpenAd: Loading started with ID: $appOpenUnitId');
    AppOpenAd.load(
      adUnitId: appOpenUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('AppOpenAd: Loaded successfully');
          _appOpenAd = ad;
          _isLoadingAppOpenAd = false;
          
          // যদি এটি প্রথমবার লোড হয় এবং এখনও দেখানো না হয়ে থাকে, তবে সাথে সাথে দেখাবে
          if (_lastAppOpenShownTime == null) {
            showAppOpenAdIfAvailable();
          }
        },
        onAdFailedToLoad: (error) {
          _isLoadingAppOpenAd = false;
          debugPrint('AppOpenAd failed to load: ${error.message}');
          debugPrint('AppOpenAd error code: ${error.code}');
          // If error code is 3 (No Fill), it's a Google server issue, not code.
        },
      ),
    );
  }

  static void showAppOpenAdIfAvailable() {
    final now = DateTime.now();

    debugPrint('AppOpenAd: Attempting to show...');

    // যদি আগে দেখানো হয়ে থাকে, তবে ১৫ মিনিট পার হয়েছে কিনা চেক করা হবে
    if (_lastAppOpenShownTime != null) {
      final diff = now.difference(_lastAppOpenShownTime!).inMinutes;
      debugPrint('AppOpenAd: Last shown $diff minutes ago');
      if (diff < 15) {
        debugPrint('AppOpenAd skip: 15 minutes not passed yet');
        return;
      }
    }

    if (_appOpenAd == null) {
      debugPrint('AppOpenAd: Not available yet, loading now...');
      loadAppOpenAd();
      return;
    }

    if (_isShowingAd) {
      debugPrint('AppOpenAd: Already showing an ad');
      return;
    }

    debugPrint('AppOpenAd: Showing now...');
    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        _isShowingAd = true;
        _lastAppOpenShownTime = DateTime.now(); // দেখানোর সময় সেভ করা হলো
        debugPrint('AppOpenAd: Full screen content showed');
      },
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('AppOpenAd: Ad dismissed');
        _isShowingAd = false;
        ad.dispose();
        _appOpenAd = null;
        loadAppOpenAd(); // পরবর্তী ব্যবহারের জন্য লোড করে রাখা হবে
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('AppOpenAd: Failed to show: $error');
        _isShowingAd = false;
        ad.dispose();
        _appOpenAd = null;
        loadAppOpenAd();
      },
    );
    _appOpenAd!.show();
  }

  // --- Interstitial Ad ---
  static void loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: interstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitialAd = ad,
        onAdFailedToLoad: (error) => _interstitialAd = null,
      ),
    );
  }

  static void showInterstitialAd(BuildContext context, VoidCallback onAdClosed) {
    _interstitialCounter++;
    
    // Show ad every 8th time
    if (_interstitialCounter % 8 == 0 && _interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          loadInterstitialAd();
          onAdClosed();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          loadInterstitialAd();
          onAdClosed();
        },
      );
      _interstitialAd!.show();
    } else {
      onAdClosed();
    }
  }

  // --- Banner Ad Widget ---
  static Widget getBannerWidget(ColorScheme colorScheme, {Key? key}) {
    return _BannerAdWidget(colorScheme: colorScheme, key: key);
  }
}

class _BannerAdWidget extends StatefulWidget {
  final ColorScheme colorScheme;
  const _BannerAdWidget({required this.colorScheme, super.key});

  @override
  State<_BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<_BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    _bannerAd = BannerAd(
      adUnitId: AdService.bannerUnitId,
      size: AdSize.largeBanner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('BannerAd failed to load: $error');
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return Container(
      alignment: Alignment.center,
      margin: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: widget.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        border: Border.symmetric(
          horizontal: BorderSide(
            color: widget.colorScheme.primary.withOpacity(0.1),
          ),
        ),
      ),
      width: double.infinity,
      height: _bannerAd!.size.height.toDouble(),
      child: SizedBox(
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      ),
    );
  }
}
