import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../screens/premium_screen.dart';
import '../theme.dart';
import 'env.dart';
import 'premium_service.dart';

/// Free version gate: watch a short rewarded ad before saving / sharing,
/// or to unlock AI for a while. Premium users never see this.
class AdGate {
  static final navigatorKey = GlobalKey<NavigatorState>();
  static final messengerKey = GlobalKey<ScaffoldMessengerState>();
  static RewardedAd? _ready;
  static bool _loading = false;
  static DateTime? _aiUntil;

  /// After one ad, AI stays unlocked this long.
  static const aiWindow = Duration(minutes: 15);

  static bool get _premium => PremiumService.instance?.isPremium ?? false;

  static bool get aiUnlocked =>
      _premium || (_aiUntil != null && DateTime.now().isBefore(_aiUntil!));

  static InterstitialAd? _interstitial;
  static AppOpenAd? _appOpen;
  static bool _fullScreenShowing = false;
  static int _actions = 0;
  static DateTime _lastFullScreen = DateTime.fromMillisecondsSinceEpoch(0);
  static DateTime? _pausedAt;
  // Held so the lifecycle listener stays registered for the app's lifetime.
  // ignore: unused_field
  static AppLifecycleListener? _lifecycle;
  static final _launchedAt = DateTime.now();

  /// Interstitial every Nth action, never closer than [_minGap].
  static const _every = 3;
  static const _minGap = Duration(seconds: 60);

  static Future<void> init() async {
    if (_premium) return;
    await MobileAds.instance.initialize();
    _preload();
    _loadInterstitial();
    _loadAppOpen(showWhenReady: true);
    _lifecycle = AppLifecycleListener(
      onPause: () => _pausedAt = DateTime.now(),
      onResume: () {
        final away = _pausedAt == null
            ? Duration.zero
            : DateTime.now().difference(_pausedAt!);
        // Short trips (camera, file picker, share sheet) don't trigger it.
        if (away > const Duration(minutes: 2)) _showAppOpen();
      },
    );
  }

  static void _loadInterstitial() {
    if (_premium || _interstitial != null) return;
    InterstitialAd.load(
      adUnitId: Env.interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (_) {},
      ),
    );
  }

  static void _loadAppOpen({bool showWhenReady = false}) {
    if (_premium || _appOpen != null) return;
    AppOpenAd.load(
      adUnitId: Env.appOpenId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpen = ad;
          // Cold start: only if it arrives quickly, never mid-task.
          if (showWhenReady &&
              DateTime.now().difference(_launchedAt) < const Duration(seconds: 6)) {
            _showAppOpen();
          }
        },
        onAdFailedToLoad: (_) {},
      ),
    );
  }

  static void _showAppOpen() {
    final ad = _appOpen;
    if (_premium || ad == null || _fullScreenShowing) return;
    _appOpen = null;
    _fullScreenShowing = true;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _fullScreenShowing = false;
        _lastFullScreen = DateTime.now();
        _loadAppOpen();
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose();
        _fullScreenShowing = false;
        _loadAppOpen();
      },
    );
    ad.show();
  }

  /// Call at natural breaks (opening a tool, finishing a conversion).
  /// Shows a full-screen ad on every [_every]th call, rate-limited.
  static Future<void> maybeInterstitial() async {
    if (_premium || _fullScreenShowing) return;
    _actions++;
    if (_actions % _every != 0) return;
    if (DateTime.now().difference(_lastFullScreen) < _minGap) return;
    final ad = _interstitial;
    if (ad == null) {
      _loadInterstitial();
      return;
    }
    _interstitial = null;
    _fullScreenShowing = true;
    final done = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _fullScreenShowing = false;
        _lastFullScreen = DateTime.now();
        _loadInterstitial();
        if (!done.isCompleted) done.complete();
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose();
        _fullScreenShowing = false;
        _loadInterstitial();
        if (!done.isCompleted) done.complete();
      },
    );
    await ad.show();
    await done.future;
  }

  static void _preload() {
    if (_premium || _loading || _ready != null) return;
    _loading = true;
    RewardedAd.load(
      adUnitId: Env.rewardedId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _ready = ad;
          _loading = false;
        },
        onAdFailedToLoad: (_) {
          _loading = false;
        },
      ),
    );
  }

  /// Download / save / share gate. Returns true when the action may run.
  static Future<bool> unlock(String action) =>
      _gate(title: 'Your file is ready ✨', body: 'Watch a short ad to $action.');

  /// AI gate (user-initiated AI with the built-in key).
  static Future<bool> unlockAi() async {
    if (aiUnlocked) return true;
    final ok = await _gate(
      title: 'Unlock AI ✨',
      body: 'Watch a short ad to use AI free for ${aiWindow.inMinutes} minutes.',
    );
    if (ok && !_premium) _aiUntil = DateTime.now().add(aiWindow);
    return ok;
  }

  static Future<bool> _gate({required String title, required String body}) async {
    if (_premium) return true;
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return true;
    final choice = await showModalBottomSheet<String>(
      context: ctx,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                  gradient: AppColors.aiGradient, shape: BoxShape.circle),
              child: const Icon(Icons.play_circle_fill_rounded,
                  color: Colors.white, size: 40),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(body, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(c, 'ad'),
                icon: const Icon(Icons.ondemand_video_rounded),
                label: const Text('Watch ad & continue'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 50)),
                onPressed: () => Navigator.pop(c, 'premium'),
                icon: const Icon(Icons.workspace_premium_rounded, color: Colors.amber),
                label: const Text('Go Premium — no ads'),
              ),
            ),
          ]),
        ),
      ),
    );
    if (choice == 'premium') {
      await navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const PremiumScreen()));
      return _premium;
    }
    if (choice != 'ad') return false;
    return _showRewarded();
  }

  static Future<bool> _showRewarded() async {
    // Give a just-started load a moment to finish.
    for (var i = 0; i < 16 && _ready == null; i++) {
      _preload();
      await Future.delayed(const Duration(milliseconds: 250));
    }
    final ad = _ready;
    _ready = null;
    if (ad == null) {
      _preload();
      return true; // No ad available (offline / no fill): never block the user.
    }
    final done = Completer<bool>();
    var earned = false;
    _fullScreenShowing = true;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _fullScreenShowing = false;
        _lastFullScreen = DateTime.now();
        _preload();
        if (!done.isCompleted) done.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose();
        _fullScreenShowing = false;
        _preload();
        if (!done.isCompleted) done.complete(true);
      },
    );
    await ad.show(onUserEarnedReward: (_, _) => earned = true);
    final ok = await done.future;
    if (!ok) {
      messengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Watch the full ad to continue')));
    }
    return ok;
  }
}

/// Banner shown on free screens; hidden for Premium.
class AdBanner extends StatefulWidget {
  const AdBanner({super.key});
  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (PremiumService.instance?.isPremium ?? false) return;
    _ad = BannerAd(
      size: AdSize.banner,
      adUnitId: Env.bannerId,
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _loaded = true),
        onAdFailedToLoad: (ad, _) => ad.dispose(),
      ),
      request: const AdRequest(),
    )..load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _ad == null || (PremiumService.instance?.isPremium ?? false)) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      width: _ad!.size.width.toDouble(),
      height: _ad!.size.height.toDouble(),
      child: AdWidget(ad: _ad!),
    );
  }
}
