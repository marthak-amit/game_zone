import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

// ============================================================ composition (kid-friendly tunes)

class _Cfg {
  final double root; // Hz of the key's tonic
  final int bpm;
  final int phrases; // which melody set (0 bouncy, 1 skippy, 2 lullaby)
  final String timbre; // xylo | marimba | box | glock
  final bool perc; // shaker + wood-block
  final bool bounce; // bouncy bass
  const _Cfg(this.root, this.bpm, this.phrases, this.timbre, {this.perc = true, this.bounce = true});
}

// One cheerful major-key tune per world + one for the home screen.
const _cfgs = <_Cfg>[
  _Cfg(261.63, 120, 0, 'xylo'), // 0 Morning Sky – sunny xylophone
  _Cfg(349.23, 104, 1, 'marimba'), // 1 Golden Hour – warm marimba
  _Cfg(293.66, 78, 2, 'box', perc: false, bounce: false), // 2 Starry Night – music-box lullaby
  _Cfg(329.63, 92, 1, 'marimba', bounce: true), // 3 Rain Storm – playful "rainy day" plinks
  _Cfg(392.00, 100, 0, 'glock', perc: false), // 4 Aurora – sparkling glockenspiel
  _Cfg(220.00, 86, 2, 'glock', perc: false, bounce: false), // 5 Deep Space – dreamy twinkles
  _Cfg(293.66, 124, 0, 'xylo'), // 6 Home – the most upbeat one
];

/// Number of tracks (6 worlds + home).
int get trackCount => _cfgs.length;

/// Track id of the home-screen music (worlds use 0..5).
const int homeTrack = 6;

// Melodies as indexes into the major pentatonic scale (0=do 1=re 2=mi 3=sol 4=la 5=do'), -1 = rest.
// Form: A A B C | A A B D  (repeating motifs = easy to hum along to).
const _phraseSets = <List<List<int>>>[
  [
    [2, -1, 3, -1, 4, 3, 2, -1],
    [5, -1, 4, -1, 3, -1, 2, -1],
    [3, -1, 3, 4, 3, -1, 2, 0],
    [2, 3, 4, 3, 2, -1, 0, -1],
  ],
  [
    [0, 2, 3, 2, 0, 2, 3, -1],
    [4, -1, 4, 3, 2, -1, 3, -1],
    [5, 4, 3, 2, 3, -1, 2, -1],
    [2, -1, 0, 2, 0, -1, -1, -1],
  ],
  [
    [0, -1, 0, -1, 3, -1, 3, -1],
    [4, -1, 4, -1, 3, -1, -1, -1],
    [2, -1, 2, -1, 1, -1, 1, -1],
    [0, -1, -1, -1, -1, -1, -1, -1],
  ],
];
const _form = [0, 0, 1, 2, 0, 0, 1, 3];
const _pent = [0, 2, 4, 7, 9];
const _chordRoots = [0, 7, 9, 5]; // I – V – vi – IV (the classic children's-song progression)

const int _rate = 22050;

/// Builds a seamless 8-bar loop (WAV bytes) for track [track]. Runs in an isolate.
Uint8List buildTrack(int track) {
  final c = _cfgs[track % _cfgs.length];
  final beat = 60 / c.bpm;
  const bars = 8;
  final n = (bars * 4 * beat * _rate).round();
  final buf = List<double>.filled(n, 0);
  final rnd = Random(track * 31 + 7);

  double hz(int semis) => c.root * pow(2, semis / 12);

  // Adds a note; writes wrap around the loop end so tails blend into the start.
  void add(double start, double dur, double freq, double amp, String kind) {
    final s0 = (start * _rate).round();
    final len = (dur * _rate).round();
    for (var i = 0; i < len; i++) {
      final t = i / _rate;
      double env, v;
      switch (kind) {
        case 'xylo':
          env = min(1.0, t / .002) * exp(-t * 7);
          v = sin(2 * pi * freq * t) + .4 * sin(2 * pi * freq * 3 * t) * exp(-t * 18) + (freq * 4.1 < 9000 ? .15 * sin(2 * pi * freq * 4.1 * t) * exp(-t * 28) : 0);
        case 'marimba':
          env = min(1.0, t / .003) * exp(-t * 4.5);
          v = sin(2 * pi * freq * t) + .5 * sin(2 * pi * freq * 4 * t) * exp(-t * 12);
        case 'box':
          env = min(1.0, t / .003) * exp(-t * 2.6);
          v = sin(2 * pi * freq * t) + .4 * sin(2 * pi * freq * 2.76 * t) * exp(-t * 5) + (freq * 5.4 < 9000 ? .15 * sin(2 * pi * freq * 5.4 * t) * exp(-t * 9) : 0);
        case 'glock':
          env = min(1.0, t / .002) * exp(-t * 3.5);
          v = sin(2 * pi * freq * t) + .5 * sin(2 * pi * freq * 2.76 * t) * exp(-t * 4) + (freq * 5.4 < 9000 ? .2 * sin(2 * pi * freq * 5.4 * t) * exp(-t * 8) : 0);
        case 'pad':
          env = min(1.0, t / .35) * min(1.0, (dur - t) / .6).clamp(0.0, 1.0);
          v = sin(2 * pi * freq * t) + .3 * sin(2 * pi * freq * 2 * t);
        case 'bass':
          env = min(1.0, t / .004) * exp(-t * 5);
          v = sin(2 * pi * freq * t) + .3 * sin(2 * pi * freq * 2 * t) * exp(-t * 9);
        case 'wood':
          env = exp(-t * 70);
          v = sin(2 * pi * 950 * t) + (rnd.nextDouble() * 2 - 1) * .25;
        default: // shaker
          env = exp(-t * 90);
          v = (rnd.nextDouble() * 2 - 1);
      }
      if (env < .0004 && t > .03) break;
      buf[(s0 + i) % n] += v * env * amp;
    }
  }

  final barLen = 4 * beat;
  final eighth = beat / 2;
  final phrases = _phraseSets[c.phrases];
  for (var b = 0; b < bars; b++) {
    final start = b * barLen;
    final chord = _chordRoots[b % 4];
    // soft pad triad
    for (final iv in const [0, 4, 7]) {
      add(start, barLen * 1.05, hz(chord + iv), .05, 'pad');
    }
    // bass
    if (c.bounce) {
      add(start, beat * .9, hz(chord - 12), .2, 'bass');
      add(start + 1.5 * beat, beat * .5, hz(chord - 5), .13, 'bass');
      add(start + 2 * beat, beat * .9, hz(chord - 12), .2, 'bass');
      add(start + 3.5 * beat, beat * .5, hz(chord - 5), .13, 'bass');
    } else {
      add(start, beat * 1.8, hz(chord - 12), .16, 'bass');
      add(start + 2 * beat, beat * 1.8, hz(chord - 12), .12, 'bass');
    }
    // melody (octave above the tonic)
    final ph = phrases[_form[b]];
    for (var s = 0; s < 8; s++) {
      final d = ph[s];
      if (d < 0) continue;
      final semis = _pent[d % 5] + 12 * (d ~/ 5) + 12;
      add(start + s * eighth, beat * 1.6, hz(semis), .24, c.timbre);
    }
    // percussion
    if (c.perc) {
      for (var s = 1; s < 8; s += 2) {
        add(start + s * eighth, .05, 0, .045, 'shaker');
      }
      add(start + beat, .06, 0, .06, 'wood');
      add(start + 3 * beat, .06, 0, .06, 'wood');
    }
  }

  // light echo (wraps around the loop)
  final d = (beat * .75 * _rate).round();
  final wet = List<double>.from(buf);
  for (var i = 0; i < n; i++) {
    wet[i] += buf[(i - d) % n] * .24 + buf[(i - 2 * d) % n] * .1;
  }
  var peak = 0.001;
  for (final v in wet) {
    peak = max(peak, v.abs());
  }
  final gain = .72 / peak;

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

// ============================================================ playback

/// The one native player used for background music (abstracted so the logic can be unit-tested).
abstract class TrackPlayer {
  Future<void> play(Uint8List wav, double volume);
  Future<void> setVolume(double v);
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> dispose();
}

class AudioTrackPlayer implements TrackPlayer {
  final AudioPlayer _p = AudioPlayer();
  @override
  Future<void> play(Uint8List wav, double volume) async {
    await _p.setReleaseMode(ReleaseMode.loop);
    await _p.play(BytesSource(wav), volume: volume);
  }

  @override
  Future<void> setVolume(double v) => _p.setVolume(v);
  @override
  Future<void> pause() => _p.pause();
  @override
  Future<void> resume() => _p.resume();
  @override
  Future<void> stop() => _p.stop();
  @override
  Future<void> dispose() => _p.dispose();
}

/// Plays one looping track that matches the screen/world, cross-fading between tracks.
///
/// Turning music off destroys the native player, and any track that finishes loading afterwards is
/// killed immediately - so music can never "come back by itself".
class Music {
  Music({TrackPlayer Function()? playerFactory, Future<Uint8List> Function(int track)? trackBuilder, this.fadeStep = const Duration(milliseconds: 70)})
      : _factory = playerFactory ?? AudioTrackPlayer.new,
        _builder = trackBuilder ?? ((t) => compute(buildTrack, t));

  static const double volume = .4;
  final TrackPlayer Function() _factory;
  final Future<Uint8List> Function(int) _builder;
  final Duration fadeStep;

  bool enabled = true;
  bool available = true;
  TrackPlayer? _player;
  int? _wanted; // what should be playing (even while disabled)
  int? _playingTrack; // what is actually playing
  int? _inflight; // track currently loading
  int _gen = 0;
  bool _paused = false;
  double _target = volume;
  final _tracks = <int, Uint8List>{};

  /// Id of the track that is (or should be) playing.
  int? get current => _wanted;

  @visibleForTesting
  bool get isPlaying => _playingTrack != null && _player != null;
  @visibleForTesting
  int? get playingTrack => _playingTrack;

  Future<Uint8List> _track(int t) async => _tracks[t] ??= await _builder(t);

  /// Switch to track [w]: a world (0..5) or [homeTrack]. No-op if it is already playing/loading.
  Future<void> setWorld(int w) async {
    w = w % _cfgs.length;
    _wanted = w;
    if (!available || !enabled) return;
    if ((_playingTrack == w && _player != null) || _inflight == w) return;
    final gen = ++_gen;
    _inflight = w;
    try {
      final bytes = await _track(w);
      if (gen != _gen || !enabled) return;
      final p = _player ??= _factory();
      if (_playingTrack != null) {
        await _fade(p, _target, 0, gen);
        if (gen != _gen || !enabled) return;
      }
      await p.play(bytes, 0);
      if (!enabled) {
        // Turned off while this track was starting: do not let it keep playing.
        await _destroy(p);
        return;
      }
      if (gen != _gen) return; // a newer request owns the player now
      _playingTrack = w;
      if (_paused) await p.pause();
      await _fade(p, 0, _target, gen);
    } catch (_) {
      if (gen == _gen) _playingTrack = null;
    } finally {
      if (gen == _gen) _inflight = null;
    }
  }

  Future<void> _fade(TrackPlayer p, double from, double to, int gen) async {
    const steps = 6;
    try {
      for (var i = 1; i <= steps; i++) {
        if (gen != _gen) return;
        await p.setVolume(from + (to - from) * i / steps);
        if (fadeStep > Duration.zero) await Future.delayed(fadeStep);
      }
    } catch (_) {}
  }

  Future<void> _destroy(TrackPlayer? p) async {
    if (p == null) return;
    if (identical(p, _player)) _player = null;
    try {
      await p.stop();
    } catch (_) {}
    try {
      await p.dispose();
    } catch (_) {}
  }

  /// Lowers the music (pause screen, game over) or restores it.
  void duck(bool on) {
    _target = on ? volume * .3 : volume;
    try {
      _player?.setVolume(_target);
    } catch (_) {}
  }

  /// Call on user gestures: (re)starts the music if it could not start earlier (browser autoplay policy).
  void ensure() {
    if (_playingTrack == null && _wanted != null && enabled && available) setWorld(_wanted!);
  }

  void setEnabled(bool on) {
    if (on == enabled) return;
    enabled = on;
    _gen++; // cancels any fade / load in flight
    if (on) {
      _inflight = null;
      if (_wanted != null) setWorld(_wanted!);
    } else {
      final p = _player;
      _player = null;
      _playingTrack = null;
      _inflight = null;
      _destroy(p);
    }
  }

  void pause() {
    _paused = true;
    try {
      _player?.pause();
    } catch (_) {}
  }

  void resume() {
    _paused = false;
    try {
      if (enabled && _playingTrack != null) _player?.resume();
    } catch (_) {}
  }
}
