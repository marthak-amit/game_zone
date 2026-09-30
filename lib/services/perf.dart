import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Watches real frame times and switches the app to a lighter look ("lite") on slow devices.
///
/// Lite mode: decorative animations stop, the menu background updates slowly and is simplified
/// (no stars / clouds / rain drops). Fast phones never enter it. The user can also force it on
/// in Settings ("Smooth mode").
class Perf extends ChangeNotifier {
  Perf._();
  static final Perf instance = Perf._();

  /// Average build+raster time above this (ms) counts as "slow" (fast devices are ~6-12 ms).
  static const double slowMs = 22;
  static const int window = 45; // frames per measurement
  static const int warmup = 60; // ignore start-up frames (shader compilation etc.)

  bool _auto = false, _manual = false;
  final _loops = <AnimationController, bool>{};
  int _seen = 0, _n = 0, _strikes = 0;
  double _sum = 0;
  bool _attached = false;

  @visibleForTesting
  int get activeLoops => _loops.keys.where((c) => c.isAnimating).length;

  @visibleForTesting
  int get registeredLoops => _loops.length;

  /// True when the light look should be used.
  bool get lite => _auto || _manual;

  /// Start watching frame timings (call once at start-up).
  void attach() {
    if (_attached) return;
    _attached = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      if (_seen++ < warmup) continue;
      _sum += t.totalSpan.inMicroseconds / 1000;
      if (++_n >= window) {
        feed(_sum / _n);
        _sum = 0;
        _n = 0;
      }
    }
  }

  /// One measurement window's average frame time in ms. Two slow windows in a row => lite.
  @visibleForTesting
  void feed(double avgMs) {
    _strikes = avgMs > slowMs ? _strikes + 1 : 0;
    if (_strikes >= 2 && !_auto) {
      _auto = true;
      _apply();
    }
  }

  /// The user's "Smooth mode" setting.
  void setManual(bool on) {
    if (_manual == on) return;
    _manual = on;
    _apply();
  }

  /// Forces lite regardless of measurements (diagnostic CI build / tests).
  void forceLite(bool on) {
    _auto = on;
    if (!on) _strikes = 0;
    _apply();
  }

  /// Looping animation controllers register here so they can be paused in lite mode.
  void register(AnimationController c, bool reverse) {
    _loops[c] = reverse;
    if (lite) c.stop();
  }

  void unregister(AnimationController c) => _loops.remove(c);

  void _apply() {
    for (final e in _loops.entries) {
      lite ? e.key.stop() : e.key.repeat(reverse: e.value);
    }
    notifyListeners();
  }
}
