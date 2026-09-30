import 'package:flutter/material.dart';

typedef GrantCallback = void Function(String sku);

abstract class IapService {
  /// Localised prices by sku (empty until loaded).
  Map<String, String> get prices;
  Future<void> init(GrantCallback onGrant);

  /// Starts a purchase. Real stores grant asynchronously via the callback.
  Future<void> buy(BuildContext context, String sku);
  Future<void> restore();
}

/// Web/desktop/testing: confirm dialog then grant immediately.
class DemoIapService implements IapService {
  late GrantCallback _grant;
  @override
  Map<String, String> get prices => const {};
  @override
  Future<void> init(GrantCallback onGrant) async => _grant = onGrant;
  @override
  Future<void> restore() async {}
  @override
  Future<void> buy(BuildContext context, String sku) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Demo purchase'),
        content: Text('Simulate buying "$sku"? (No real money is charged in demo mode.)'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(key: const Key('confirmBuy'), onPressed: () => Navigator.pop(context, true), child: const Text('Buy')),
        ],
      ),
    );
    if (ok == true) _grant(sku);
  }
}
