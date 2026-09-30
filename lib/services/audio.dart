import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'music.dart';

/// Synthesized sound effects (no asset files needed) + haptics.
/// Perfect drops play a rising pentatonic scale so a streak sounds like a soothing melody.
class Audio {
  bool soundOn = true, vibeOn = true;
  final music = Music();

  /// Set false in tests / unsupported platforms to disable all sound plugins.
  bool _available = true;
  bool get available => _available;
  set available(bool v) {
    _available = v;
    music.available = v;
  }

  final _cache = <String, Uint8List>{};
  AudioPlayer? _rain;
  bool _rainOn = false;

  static const _pentatonic = [523.25, 587.33, 659.25, 783.99, 880.0, 1046.5, 1174.66, 1318.5, 1567.98];

  static Uint8List _wav(List<double> samples, {int rate = 22050}) {
    final n = samples.length;
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
    data.setUint32(24, rate, Endian.little);
    data.setUint32(28, rate * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    str(36, 'data');
    data.setUint32(40, n * 2, Endian.little);
    for (var i = 0; i < n; i++) {
      data.setInt16(44 + i * 2, (samples[i].clamp(-1.0, 1.0) * 32767).toInt(), Endian.little);
    }
    return data.buffer.asUint8List();
  }

  static Uint8List _tone(double freq, double seconds, {bool soft = false}) {
    const rate = 22050;
    final n = (rate * seconds).toInt();
    final out = List<double>.filled(n, 0);
    for (var i = 0; i < n; i++) {
      final t = i / rate;
      final attack = min(1.0, t / .005);
      final env = attack * exp(-t * (soft ? 5 : 9));
      var v = sin(2 * pi * freq * t);
      if (soft) v += .3 * sin(2 * pi * freq * 2 * t) + .1 * sin(2 * pi * freq * 3 * t);
      out[i] = v * .28 * env;
    }
    return _wav(out);
  }

  /// 2.5 s of soft filtered noise that loops seamlessly (cross-faded ends).
  static Uint8List _rainLoop() {
    const rate = 22050;
    final n = (rate * 2.5).toInt(), fade = 2200;
    final r = Random(3);
    final raw = List<double>.filled(n + fade, 0);
    var lp = 0.0;
    for (var i = 0; i < raw.length; i++) {
      lp += ((r.nextDouble() * 2 - 1) - lp) * .35; // low-pass => soft patter
      raw[i] = lp;
    }
    final out = List<double>.filled(n, 0);
    for (var i = 0; i < n; i++) {
      out[i] = raw[i] * .33;
      if (i < fade) {
        final a = i / fade;
        out[i] = (raw[i] * a + raw[n + i] * (1 - a)) * .33;
      }
    }
    return _wav(out);
  }

  void beep(double freq, [double seconds = .12]) {
    if (!soundOn || !_available) return;
    _play(_cache.putIfAbsent('b$freq-$seconds', () => _tone(freq, seconds)));
  }

  /// Gentle chime climbing the pentatonic scale with [step] (combo count).
  void chime(int step) {
    if (!soundOn || !_available) return;
    final f = _pentatonic[step.clamp(0, _pentatonic.length - 1)];
    _play(_cache.putIfAbsent('c$f', () => _tone(f, .7, soft: true)));
  }

  Future<void> _play(Uint8List bytes, {double volume = .7}) async {
    try {
      final p = AudioPlayer();
      p.onPlayerComplete.first.then((_) => p.dispose());
      await p.play(BytesSource(bytes), volume: volume);
    } catch (_) {/* audio is best-effort */}
  }

  /// Start/stop the rain ambience.
  Future<void> setRain(bool on) async {
    final want = on && soundOn && _available;
    if (want == _rainOn) return;
    _rainOn = want;
    try {
      if (want) {
        _rain ??= AudioPlayer();
        await _rain!.setReleaseMode(ReleaseMode.loop);
        await _rain!.play(BytesSource(_cache.putIfAbsent('rain', _rainLoop)), volume: .3);
      } else {
        await _rain?.stop();
      }
    } catch (_) {}
  }

  // ---------------------------------------------------------------- sound effects
  static const _rate = 22050;

  static List<double> _buf(double seconds) => List<double>.filled((seconds * _rate).toInt(), 0);

  static Uint8List _finish(List<double> b, double peak) {
    var m = 1e-6;
    for (final v in b) {
      m = max(m, v.abs());
    }
    final g = peak / m;
    return _wav([for (final v in b) v * g]);
  }

  static double _env(double t, double attack, double decay) => min(1.0, t / attack) * exp(-t * decay);

  /// Adds a bell-like note into [out] starting at [at] seconds.
  static void _bell(List<double> out, double at, double f, double amp, {double decay = 4}) {
    final s0 = (at * _rate).toInt();
    for (var i = 0; s0 + i < out.length; i++) {
      final t = i / _rate;
      final e = _env(t, .003, decay);
      if (t > .05 && e < 0.0005) break;
      out[s0 + i] += (sin(2 * pi * f * t) + .35 * sin(2 * pi * f * 2.76 * t) * exp(-t * 6) + .15 * sin(2 * pi * f * 5.4 * t) * exp(-t * 10)) * amp * e;
    }
  }

  /// Block landing: a soft "thud" with a tiny click. [perfect] is brighter and fuller.
  @visibleForTesting
  static Uint8List buildThud({bool perfect = false}) {
    final out = _buf(.26);
    final r = Random(perfect ? 1 : 2);
    var ph = 0.0, lp = 0.0;
    for (var i = 0; i < out.length; i++) {
      final t = i / _rate;
      final f = (perfect ? 190 : 140) * exp(-t * 16) + (perfect ? 70 : 52);
      ph += 2 * pi * f / _rate;
      lp += ((r.nextDouble() * 2 - 1) - lp) * .5;
      out[i] = sin(ph) * exp(-t * (perfect ? 13 : 17)) + lp * exp(-t * 500) * .6;
    }
    return _finish(out, perfect ? .9 : .7);
  }

  /// Game over: four sagging notes and a low thud.
  @visibleForTesting
  static Uint8List buildGameOver() {
    final out = _buf(1.5);
    const notes = [392.0, 349.23, 293.66, 196.0];
    for (var k = 0; k < notes.length; k++) {
      final s0 = (k * .24 * _rate).toInt();
      final last = k == notes.length - 1;
      var ph = 0.0;
      for (var i = 0; s0 + i < out.length; i++) {
        final t = i / _rate;
        final bend = last ? (1 - min(1.0, t / .9) * .25) : 1.0; // final note sags
        final vib = 1 + .012 * sin(2 * pi * 5.5 * t);
        ph += 2 * pi * notes[k] * bend * vib / _rate;
        final e = min(1.0, t / .01) * exp(-t * (last ? 2.2 : 5));
        if (t > .05 && e < .001) break;
        out[s0 + i] += (sin(ph) + .35 * sin(2 * ph) + .15 * sin(3 * ph)) * .28 * e;
      }
    }
    final th = buildThud();
    final bd = th.buffer.asByteData();
    final s0 = (.72 * _rate).toInt();
    for (var i = 0; i < (th.length - 44) ~/ 2 && s0 + i < out.length; i++) {
      out[s0 + i] += bd.getInt16(44 + i * 2, Endian.little) / 32767 * .6;
    }
    return _finish(out, .8);
  }

  /// "Let's go" sting when a round starts: rising sweep into three bright bells.
  @visibleForTesting
  static Uint8List buildStart() {
    final out = _buf(1.3);
    var ph = 0.0;
    for (var i = 0; i < (.34 * _rate).toInt(); i++) {
      final t = i / _rate;
      final f = 260 * pow(3.3, t / .34);
      ph += 2 * pi * f / _rate;
      out[i] += sin(ph) * .22 * sin(pi * t / .34);
    }
    _bell(out, .3, 523.25, .3);
    _bell(out, .42, 783.99, .28);
    _bell(out, .54, 1046.5, .3, decay: 3);
    return _finish(out, .8);
  }

  /// Crowd applause: hundreds of tiny hand-claps whose density swells and fades.
  @visibleForTesting
  static Uint8List buildApplause({double seconds = 3.4}) {
    final out = _buf(seconds);
    final r = Random(9);
    double dens(double t) {
      final up = min(1.0, t / .45);
      final down = t > seconds - 1.3 ? max(0.0, (seconds - t) / 1.3) : 1.0;
      return up * down;
    }
    // soft crowd bed
    var lp = 0.0;
    for (var i = 0; i < out.length; i++) {
      lp += ((r.nextDouble() * 2 - 1) - lp) * .12;
      out[i] += lp * .22 * dens(i / _rate);
    }
    final claps = (seconds * 95).toInt();
    for (var c = 0; c < claps; c++) {
      var t = 0.0;
      do {
        t = r.nextDouble() * (seconds - .05);
      } while (r.nextDouble() > dens(t));
      final s0 = (t * _rate).toInt();
      final amp = .35 + r.nextDouble() * .65;
      final len = ((.012 + r.nextDouble() * .012) * _rate).toInt();
      var prev = 0.0, hp = 0.0;
      for (var i = 0; i < len && s0 + i < out.length; i++) {
        final n = r.nextDouble() * 2 - 1;
        hp = n - prev * .85; // crude high-pass => papery clap
        prev = n;
        out[s0 + i] += hp * amp * exp(-i / (len * .3)) * .9;
      }
    }
    return _finish(out, .9);
  }

  /// Small sparkle for milestones and level-ups.
  @visibleForTesting
  static Uint8List buildSparkle() {
    final out = _buf(.8);
    const f = [1567.98, 1975.53, 2349.32, 3135.96];
    for (var k = 0; k < f.length; k++) {
      _bell(out, k * .06, f[k], .22, decay: 7);
    }
    return _finish(out, .7);
  }

  /// Airy whoosh when a new world arrives.
  @visibleForTesting
  static Uint8List buildWhoosh() {
    final out = _buf(1.0);
    final r = Random(5);
    var lp = 0.0;
    for (var i = 0; i < out.length; i++) {
      final t = i / _rate;
      final shape = sin(pi * (t / 1.0).clamp(0.0, 1.0));
      final a = .03 + .5 * shape;
      lp += ((r.nextDouble() * 2 - 1) - lp) * a;
      out[i] = lp * shape;
    }
    return _finish(out, .6);
  }

  /// Achievement "ding".
  @visibleForTesting
  static Uint8List buildDing() {
    final out = _buf(1.1);
    _bell(out, 0, 880, .35, decay: 3.5);
    _bell(out, .12, 1318.5, .3, decay: 3.5);
    return _finish(out, .8);
  }

  /// Celebration jingle: a bright rising arpeggio with a sparkling tail (new high score, level up).
  @visibleForTesting
  static Uint8List buildFanfare() {
    final out = _buf(2.2);
    const notes = [523.25, 659.25, 783.99, 1046.5, 1318.5, 1567.98];
    for (var k = 0; k < notes.length; k++) {
      final s0 = (_rate * k * .12).toInt();
      for (var i = 0; s0 + i < out.length; i++) {
        final t = i / _rate;
        final env = _env(t, .004, 3.2);
        if (t > .05 && env < .001) break;
        out[s0 + i] += (sin(2 * pi * notes[k] * t) + .3 * sin(2 * pi * notes[k] * 2 * t)) * .17 * env;
      }
    }
    return _finish(out, .8);
  }

  /// Tiny UI tick.
  @visibleForTesting
  static Uint8List buildClick() {
    final out = _buf(.05);
    final r = Random(1);
    for (var i = 0; i < out.length; i++) {
      final t = i / _rate;
      out[i] = (sin(2 * pi * 1900 * t) * .5 + (r.nextDouble() * 2 - 1) * .3) * exp(-t * 110);
    }
    return _finish(out, .4);
  }

  void _sfx(String key, Uint8List Function() build, [double volume = .8]) {
    if (!soundOn || !_available) return;
    _play(_cache.putIfAbsent(key, build), volume: volume);
  }

  void thud({bool perfect = false}) => _sfx(perfect ? 'thudP' : 'thud', () => buildThud(perfect: perfect), .9);
  void gameOver() => _sfx('over', buildGameOver, .85);
  void startRound() => _sfx('start', buildStart, .8);
  void applause({bool long = true}) => _sfx(long ? 'clap' : 'clapS', () => buildApplause(seconds: long ? 3.4 : 2.2), 1.0);
  void sparkle() => _sfx('sparkle', buildSparkle, .6);
  void whoosh() => _sfx('whoosh', buildWhoosh, .55);
  void ding() => _sfx('ding', buildDing, .8);
  void fanfare() => _sfx('fanfare', buildFanfare, .8);
  void click() => _sfx('click', buildClick, .5);
  void miss() => gameOver();

  void buzz([int ms = 10]) {
    if (!vibeOn) return;
    try {
      ms > 30 ? HapticFeedback.heavyImpact() : HapticFeedback.lightImpact();
    } catch (_) {}
  }
}
