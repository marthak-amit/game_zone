import 'package:flutter/material.dart';

abstract class AdService {
  Future<void> init();

  /// Returns true only if the user earned the reward.
  Future<bool> showRewarded(BuildContext context, String reason);
  Future<void> showInterstitial(BuildContext context);
}

/// Fake ads for web/desktop/testing: shows a countdown screen.
class DemoAdService implements AdService {
  final int seconds;
  DemoAdService({this.seconds = 3});

  @override
  Future<void> init() async {}

  @override
  Future<bool> showRewarded(BuildContext context, String reason) => _show(context, 'Rewarded ad ($reason)', seconds);

  @override
  Future<void> showInterstitial(BuildContext context) async => _show(context, 'Interstitial ad', 2);

  Future<bool> _show(BuildContext context, String label, int secs) async {
    final r = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DemoAdDialog(label: label, seconds: secs),
    );
    return r ?? false;
  }
}

class _DemoAdDialog extends StatefulWidget {
  final String label;
  final int seconds;
  const _DemoAdDialog({required this.label, required this.seconds});
  @override
  State<_DemoAdDialog> createState() => _DemoAdDialogState();
}

class _DemoAdDialogState extends State<_DemoAdDialog> {
  late int left = widget.seconds;
  @override
  void initState() {
    super.initState();
    _tick();
  }

  void _tick() async {
    while (left > 0) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      setState(() => left--);
    }
  }

  @override
  Widget build(BuildContext context) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('${widget.label} — demo', style: const TextStyle(color: Colors.white, fontSize: 20)),
          const SizedBox(height: 8),
          Text(left > 0 ? '$left s' : 'Done', style: const TextStyle(color: Colors.white70, fontSize: 32)),
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('adClose'),
            onPressed: left > 0 ? null : () => Navigator.pop(context, true),
            child: const Text('Close ✕'),
          ),
        ]),
      );
}
