import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// A preloaded sound that can be fired many times quickly (landing thud, chimes, clicks).
abstract class SfxPool {
  Future<void> start(double volume);
}

/// A player used for rare, longer sounds (applause, fanfare, game over ...).
abstract class OneShot {
  Future<void> play(Uint8List bytes, double volume);
}

typedef SfxPoolFactory = Future<SfxPool> Function(Uint8List bytes);
typedef OneShotFactory = OneShot Function();

class _PoolAdapter implements SfxPool {
  final AudioPool pool;
  _PoolAdapter(this.pool);
  @override
  Future<void> start(double volume) => pool.start(volume: volume);
}

class _PlayerAdapter implements OneShot {
  final AudioPlayer p = AudioPlayer();
  @override
  Future<void> play(Uint8List bytes, double volume) async {
    await p.stop();
    await p.play(BytesSource(bytes), volume: volume);
  }
}

Future<SfxPool> _defaultPool(Uint8List bytes) async =>
    _PoolAdapter(await AudioPool.create(source: BytesSource(bytes), maxPlayers: 2));

/// Plays sound effects with a **bounded** number of native players.
///
/// Creating a new AudioPlayer per sound (what this app used to do) leaks Android MediaPlayers and makes
/// the app stutter and hang after a few games. Here:
///  * frequent sounds get one preloaded pool each (max 2 players), created lazily;
///  * rare sounds share [sharedCount] players in round-robin;
///  * the same sound cannot be re-triggered faster than [minGap].
class SfxPlayer {
  SfxPlayer({
    SfxPoolFactory? poolFactory,
    OneShotFactory? oneShotFactory,
    this.sharedCount = 3,
    this.minGap = const Duration(milliseconds: 40),
  })  : _poolFactory = poolFactory ?? _defaultPool,
        _oneShotFactory = oneShotFactory ?? _PlayerAdapter.new;

  final SfxPoolFactory _poolFactory;
  final OneShotFactory _oneShotFactory;
  final int sharedCount;
  final Duration minGap;

  final _pools = <String, Future<SfxPool>>{};
  final _shared = <OneShot>[];
  final _last = <String, DateTime>{};
  int _next = 0;

  @visibleForTesting
  int get poolCount => _pools.length;
  @visibleForTesting
  int get sharedPlayers => _shared.length;

  bool _throttled(String key) {
    final now = DateTime.now();
    final prev = _last[key];
    if (prev != null && now.difference(prev) < minGap) return true;
    _last[key] = now;
    return false;
  }

  /// Frequent, latency-sensitive sound.
  Future<void> playPooled(String key, Uint8List Function() build, double volume) async {
    if (_throttled(key)) return;
    try {
      final pool = await (_pools[key] ??= _poolFactory(build()));
      await pool.start(volume);
    } catch (_) {
      _pools.remove(key); // best-effort: try again next time
    }
  }

  /// Rare/long sound on one of the shared players.
  Future<void> playShared(String key, Uint8List Function() build, double volume) async {
    if (_throttled(key)) return;
    try {
      if (_shared.length < sharedCount) _shared.add(_oneShotFactory());
      final p = _shared[_next++ % _shared.length];
      await p.play(build(), volume);
    } catch (_) {}
  }
}
