import 'dart:io';

/// Build-time configuration, passed with `--dart-define-from-file=keys.json`
/// (see build_release.ps1). Nothing secret lives in source code.
class Env {
  /// The paid "Pro" app: no ads, every feature unlocked.
  static const isProBuild = bool.fromEnvironment('PRO');

  /// Developer-supplied Gemini key used for Premium users (and for free
  /// users after a rewarded ad) when they haven't added their own key.
  static const geminiKey = String.fromEnvironment('GEMINI_KEY');

  static bool get hasBuiltInKey => geminiKey.isNotEmpty;

  // AdMob unit ids. Defaults are Google's official test ids — replace them
  // in keys.json with your real ids before publishing.
  static const _bannerAndroid = String.fromEnvironment('ADMOB_BANNER_ANDROID',
      defaultValue: 'ca-app-pub-3940256099942544/6300978111');
  static const _rewardedAndroid = String.fromEnvironment('ADMOB_REWARDED_ANDROID',
      defaultValue: 'ca-app-pub-3940256099942544/5224354917');
  static const _bannerIos = String.fromEnvironment('ADMOB_BANNER_IOS',
      defaultValue: 'ca-app-pub-3940256099942544/2934735716');
  static const _rewardedIos = String.fromEnvironment('ADMOB_REWARDED_IOS',
      defaultValue: 'ca-app-pub-3940256099942544/1712485313');

  static const _interstitialAndroid = String.fromEnvironment('ADMOB_INTERSTITIAL_ANDROID',
      defaultValue: 'ca-app-pub-3940256099942544/1033173712');
  static const _appOpenAndroid = String.fromEnvironment('ADMOB_APP_OPEN_ANDROID',
      defaultValue: 'ca-app-pub-3940256099942544/9257395921');
  static const _interstitialIos = String.fromEnvironment('ADMOB_INTERSTITIAL_IOS',
      defaultValue: 'ca-app-pub-3940256099942544/4411468910');
  static const _appOpenIos = String.fromEnvironment('ADMOB_APP_OPEN_IOS',
      defaultValue: 'ca-app-pub-3940256099942544/5575463023');

  static String get interstitialId => Platform.isIOS ? _interstitialIos : _interstitialAndroid;
  static String get appOpenId => Platform.isIOS ? _appOpenIos : _appOpenAndroid;
  static String get bannerId => Platform.isIOS ? _bannerIos : _bannerAndroid;
  static String get rewardedId => Platform.isIOS ? _rewardedIos : _rewardedAndroid;

  /// Play Console in-app product ids for the Premium upgrade.
  static const premiumLifetimeId = 'premium_lifetime';
  static const premiumMonthlyId = 'premium_monthly';
}
