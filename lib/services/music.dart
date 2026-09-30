import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class _Cfg {
  final double root; // Hz
  final bool minor;
  final int bpm;
  final double density; // chance of a melody note on each half-beat
  final String style; // pluck | arp | bell
  final int seed;
  const _Cfg(this.root, this.minor, this.bpm, this.density, this.style, this.seed);
}

// One musical mood per world (same order as worlds.dart).
const _cfgs = <_Cfg>[
  _Cfg(261.63, false, 96, .55, 'pluck', 11), // Morning Sky  – bright C major
  _Cfg(349.23, false, 78, .45, 'pluck', 22), // Golden Hour  – warm F major
  _Cfg(220.00, true, 68, .40, 'pluck', 33), // Starry Night – dreamy A minor
  _Cfg(146.83, true, 60, .22, 'bell', 44), // Rain Storm   – low, sparse D minor
  _Cfg(329.63, false, 84, .70, 'arp', 55), // Aurora       – shimmering arpeggios
  _Cfg(196.00, true, 56, .30, 'bell', 66), // Deep Space   – slow bells
];

const _rate = 16000;

/// Builds a seamless 8-bar ambient loop (WAV bytes) for world [world]. Runs in an isolate.
Uint8List buildTrack(int world) {
  final c = _cfgs[world % _cfgs.length];
  final beat = 60 / c.bpm;
  const bars = 8;
  final n = (bars * 4 * beat * _rate).round();
  final buf = List<double>.filled(n, 0);
  final rnd = Random(c.seed);
  final prog = c.minor ? [0, 8, 3, 10] : [0, 9, 5, 7];
  final penta = c.minor ? [0, 3, 5, 7, 10] : [0, 2, 4, 7, 9];

  double hz(double base, int semis) => base * pow(2, semis / 12);

  // Adds a note; writes wrap around the loop end so the tail blends into the start.
  void note(double start, double dur, double freq, double amp, String kind) {
    final s0 = (start * _rate).round();
    final len = (dur * _rate).round();
    for (var i = 0; i < len; i++) {
      final t = i / _rate;
      double env, v;
      switch (kind) {
        case 'pad':
          env = min(1.0, t / .7) * min(1.0, (dur - t) / 1.0).clamp(0.0, 1.0);
          v = sin(2 * pi * freq * t) + .5 * sin(2 * pi * freq * 1.003 * t) + .2 * sin(2 * pi * freq * 2 * t);
        case 'bell':
          env = min(1.0, t / .003) * exp(-t * 1.7);
          v = sin(2 * pi * freq * t) + .35 * sin(2 * pi * freq * 2.76 * t) * exp(-t * 3);
        default: // pluck
          env = min(1.0, t / .004) * exp(-t * 3.2);
          v = sin(2 * pi * freq * t) + .3 * sin(2 * pi * freq * 2 * t) + .12 * sin(2 * pi * freq * 3 * t);
      }
      buf[(s0 + i) % n] += v * env * amp;
    }
  }

  final barLen = 4 * beat;
  for (var b = 0; b < bars; b++) {
    final start = b * barLen;
    final ch = prog[b % 4];
    final third = c.minor ? 3 : 4;
    // warm pad chord
    for (final iv in [0, third, 7]) {
      note(start, barLen * 1.15, hz(c.root, ch + iv), .085, 'pad');
    }
    // soft bass on beats 1 and 3
    note(start, beat * 1.8, hz(c.root, ch - 12), .16, 'pluck');
    note(start + 2 * beat, beat * 1.8, hz(c.root, ch - 12), .12, 'pluck');
    // melody
    for (var h = 0; h < 8; h++) {
      final t = start + h * beat / 2;
      if (c.style == 'arp') {
        final tones = [0, third, 7, 12, 7, third, 12, 16];
        if (rnd.nextDouble() < c.density) note(t, beat * 1.2, hz(c.root, ch + 12 + tones[h]), .07, 'pluck');
      } else if (rnd.nextDouble() < c.density) {
        final semis = ch + 12 + penta[rnd.nextInt(penta.length)] + (rnd.nextBool() ? 12 : 0);
        note(t, beat * 2, hz(c.root, semis), c.style == 'bell' ? .11 : .10, c.style == 'bell' ? 'bell' : 'pluck');
      }
    }
  }

  // dreamy echo (wraps around the loop)
  final d = (beat * .75 * _rate).round();
  final wet = List<double>.from(buf);
  for (var i = 0; i < n; i++) {
    wet[i] += buf[(i - d) % n] * .34 + buf[(i - 2 * d) % n] * .2 + buf[(i - 3 * d) % n] * .1;
  }

  var peak = 0.001;
  for (final v in wet) {
    peak = max(peak, v.abs());
  }
  final gain = .7 / peak;

  final data = ByteData(44 + n * 2);
  void str(int o, String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(o + i, s.codeUnitAt(i));
    }
  }
  str(0, 'RIFF');
  data.setUint32(4, 36 + n * 2, Endian.little);
  str(8, 'WAVEfmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, _rate, Endian.little);
  data.setUint32(28, _rate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  str(36, 'data');
  data.setUint32(40, n * 2, Endian.little);
  for (var i = 0; i < n; i++) {
    data.setInt16(44 + i * 2, (wet[i] * gain * 32767).round().clamp(-32767, 32767), Endian.little);
  }
  return data.buffer.asUint8List();
}

/// Plays one looping ambient track that matches the current world, cross-fading when the world changes.
class Music {
  static const double volume = .4;
  bool enabled = true;
  bool available = true;
  AudioPlayer? _p;
  int? _world;
  int? _wanted;
  int _gen = 0;
  bool _paused = false;
  bool _playing = false;
  final _tracks = <int, Uint8List>{};

  Future<Uint8List> _track(int w) async {
    final cached = _tracks[w];
    if (cached != null) return cached;
    final bytes = await compute(buildTrack, w);
    _tracks[w] = bytes;
    return bytes;
  }

  /// Switch to the music of world [w] (no-op if it is already playing).
  Future<void> setWorld(int w) async {
    w = w % _cfgs.length;
    _wanted = w;
    if (!available || !enabled) {
      _world = null;
      return;
    }
    if (_world == w) return;
    _world = w;
    final gen = ++_gen;
    try {
      final bytes = await _track(w);
      if (gen != _gen || !enabled) return;
      final p = _p ??= AudioPlayer();
      await _fade(p, 0, gen);
      if (gen != _gen) return;
      await p.setReleaseMode(ReleaseMode.loop);
      await p.play(BytesSource(bytes), volume: 0);
      if (_paused) await p.pause();
      await _fade(p, volume, gen);
      _playing = true;
    } catch (_) {
      // e.g. browser autoplay rules: allow a retry on the next user gesture
      if (gen == _gen) _world = null;
      _playing = false;
    }
  }

  Future<void> _fade(AudioPlayer p, double to, int gen) async {
    const steps = 6;
    try {
      final from = p.volume;
      for (var i = 1; i <= steps; i++) {
        if (gen != _gen) return;
        await p.setVolume(from + (to - from) * i / steps);
        await Future.delayed(const Duration(milliseconds: 70));
      }
    } catch (_) {}
  }

  /// Call on user gestures: (re)starts the music if it could not start earlier (web autoplay policy).
  void ensure() {
    if (!_playing && _wanted != null && enabled && available) setWorld(_wanted!);
  }

  void setEnabled(bool on) {
    if (on == enabled) return;
    enabled = on;
    if (on) {
      if (_wanted != null) setWorld(_wanted!);
    } else {
      _gen++;
      _world = null;
      _playing = false;
      try {
        _p?.stop();
      } catch (_) {}
    }
  }

  void pause() {
    _paused = true;
    try {
      _p?.pause();
    } catch (_) {}
  }

  void resume() {
    _paused = false;
    try {
      if (enabled && _world != null) _p?.resume();
    } catch (_) {}
  }
}
