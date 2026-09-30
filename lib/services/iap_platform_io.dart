import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../config.dart';
import 'iap_demo.dart';

IapService createIapService() =>
    (Platform.isAndroid || Platform.isIOS) ? StoreIapService() : DemoIapService();

/// Real Google Play Billing / StoreKit purchases.
class StoreIapService implements IapService {
  final _iap = InAppPurchase.instance;
  final _details = <String, ProductDetails>{};
  @override
  final Map<String, String> prices = {};
  late GrantCallback _grant;
  // ignore: unused_field
  StreamSubscription<List<PurchaseDetails>>? _sub;

  @override
  Future<void> init(GrantCallback onGrant) async {
    _grant = onGrant;
    if (!await _iap.isAvailable()) return;
    _sub = _iap.purchaseStream.listen(_onPurchases, onError: (_) {});
    final resp = await _iap.queryProductDetails(Sku.all);
    for (final d in resp.productDetails) {
      _details[d.id] = d;
      prices[d.id] = d.price;
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final p in list) {
      if (p.status == PurchaseStatus.purchased || p.status == PurchaseStatus.restored) {
        _grant(p.productID);
      }
      if (p.pendingCompletePurchase) await _iap.completePurchase(p);
    }
  }

  @override
  Future<void> buy(BuildContext context, String sku) async {
    final d = _details[sku];
    if (d == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Store unavailable. Try again later.')));
      }
      return;
    }
    final param = PurchaseParam(productDetails: d);
    if (sku.startsWith('coins')) {
      await _iap.buyConsumable(purchaseParam: param);
    } else {
      await _iap.buyNonConsumable(purchaseParam: param);
    }
  }

  @override
  Future<void> restore() => _iap.restorePurchases();
}
