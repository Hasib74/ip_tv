import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class AdService {
  static AppOpenAd? _appOpenAd;
  static bool _isShowingAd = false;
  static InterstitialAd? _interstitialAd;
  static int _interstitialCounter = 0;

  // Ad Unit IDs
  static String get appOpenUnitId => kDebugMode 
      ? 'ca-app-pub-3940256099942544/9257395923' // Android Test ID
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
  }

  // --- App Open Ad ---
  static void loadAppOpenAd() {
    AppOpenAd.load(
      adUnitId: appOpenUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAd = ad;
          showAppOpenAdIfAvailable();
        },
        onAdFailedToLoad: (error) {
          debugPrint('AppOpenAd failed to load: $error');
        },
      ),
    );
  }

  static void showAppOpenAdIfAvailable() {
    if (_appOpenAd == null || _isShowingAd) return;

    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) => _isShowingAd = true,
      onAdDismissedFullScreenContent: (ad) {
        _isShowingAd = false;
        ad.dispose();
        _appOpenAd = null;
        loadAppOpenAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
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
    
    // Show ad every 4th time (after 3 changes)
    if (_interstitialCounter % 6 == 0 && _interstitialAd != null) {
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
