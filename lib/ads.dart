import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdMob, configured for a child-directed app (Google Play Families policy):
/// child age treatment, G-rated ads only, no personalization. Ads appear on menu screens and after every third
/// finished game, never while a child is learning, tracing or playing.
class Ads {
  Ads._();

  // Google's public test IDs. Real IDs come from --dart-define at build time
  // (see README); a build without them shows "Test Ad" banners.
  static const _testBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const _testInterstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const _banner = String.fromEnvironment('ADMOB_BANNER_ID');
  static const _interstitial = String.fromEnvironment('ADMOB_INTERSTITIAL_ID');

  static String get bannerId => _banner.isEmpty ? _testBanner : _banner;
  static String get interstitialId =>
      _interstitial.isEmpty ? _testInterstitial : _interstitial;

  /// How many finished games between full-screen ads.
  static const gamesPerInterstitial = 3;

  static bool _ready = false;
  static InterstitialAd? _interstitialAd;
  static int _gamesFinished = 0;

  static const request = AdRequest(nonPersonalizedAds: true);

  static Future<void> init() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(
          // Replaces the old child-directed + under-age-of-consent tags.
          ageRestrictedTreatment: AgeRestrictedTreatment.child,
          maxAdContentRating: MaxAdContentRating.g,
        ),
      );
      await MobileAds.instance.initialize();
      _ready = true;
      _loadInterstitial();
    } catch (_) {
      _ready = false;
    }
  }

  static void _loadInterstitial() {
    if (!_ready) return;
    InterstitialAd.load(
      adUnitId: interstitialId,
      request: request,
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitialAd = ad,
        onAdFailedToLoad: (_) => _interstitialAd = null,
      ),
    );
  }

  /// Call when a game ends. Every [gamesPerInterstitial] games a full-screen
  /// ad is shown first; [then] runs once it is closed (or straight away).
  static void afterGame(VoidCallback then) {
    _gamesFinished++;
    final ad = _interstitialAd;
    if (!_ready || ad == null || _gamesFinished % gamesPerInterstitial != 0) {
      then();
      return;
    }
    _interstitialAd = null;
    void done(InterstitialAd a) {
      a.dispose();
      _loadInterstitial();
      then();
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: done,
      onAdFailedToShowFullScreenContent: (a, _) => done(a),
    );
    ad.show();
  }
}

/// A 320×50 banner that takes no space until an ad has loaded.
class BannerAdSlot extends StatefulWidget {
  const BannerAdSlot({super.key});

  @override
  State<BannerAdSlot> createState() => _BannerAdSlotState();
}

class _BannerAdSlotState extends State<BannerAdSlot> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (!Ads._ready) return;
    _ad = BannerAd(
      adUnitId: Ads.bannerId,
      size: AdSize.banner,
      request: Ads.request,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          _ad = null;
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null || !_loaded) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: SizedBox(
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      ),
    );
  }
}
