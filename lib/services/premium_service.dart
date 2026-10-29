import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'env.dart';

/// Premium = the paid Pro build, or a Premium purchase inside the free app.
class PremiumService extends ChangeNotifier {
  static PremiumService? instance;

  final _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  late SharedPreferences _p;

  bool _purchased = false;
  bool storeAvailable = false;
  bool busy = false;
  String? error;
  List<ProductDetails> products = [];

  bool get isPremium => Env.isProBuild || _purchased;

  Future<void> load() async {
    instance = this;
    _p = await SharedPreferences.getInstance();
    _purchased = _p.getBool('premium') ?? false;
    if (Env.isProBuild) return;
    _sub = _iap.purchaseStream.listen(_onPurchases, onError: (e) {
      error = '$e';
      busy = false;
      notifyListeners();
    });
    _initStore();
  }

  Future<void> _initStore() async {
    try {
      storeAvailable = await _iap.isAvailable();
      if (!storeAvailable) return;
      final r = await _iap.queryProductDetails(
          {Env.premiumLifetimeId, Env.premiumMonthlyId});
      products = r.productDetails
        ..sort((a, b) => a.id == Env.premiumMonthlyId ? -1 : 1);
      notifyListeners();
    } catch (e) {
      debugPrint('store init failed: $e');
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final p in list) {
      if (p.status == PurchaseStatus.purchased ||
          p.status == PurchaseStatus.restored) {
        await _setPurchased(true);
      } else if (p.status == PurchaseStatus.error) {
        error = p.error?.message ?? 'Purchase failed';
      }
      if (p.pendingCompletePurchase) await _iap.completePurchase(p);
    }
    busy = false;
    notifyListeners();
  }

  Future<void> _setPurchased(bool v) async {
    _purchased = v;
    await _p.setBool('premium', v);
    notifyListeners();
  }

  Future<void> buy(ProductDetails product) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      await _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: product));
    } catch (e) {
      busy = false;
      error = '$e';
      notifyListeners();
    }
  }

  Future<void> restore() async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      await _iap.restorePurchases();
    } catch (e) {
      error = '$e';
    }
    // Restore emits on the purchase stream; stop the spinner either way.
    Future.delayed(const Duration(seconds: 6), () {
      busy = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
