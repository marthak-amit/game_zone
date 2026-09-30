import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'music.dart';
import 'voice.dart';

/// Synthesized sound effects (no asset files needed) + haptics.
/// Perfect drops play a rising pentatonic scale so a streak sounds like a soothing melody.
class Audio {
  bool soundOn = true, vibeOn = true;
  final music = Music();
  final voice = Voice();

  /// Set false in tests / unsupported platforms to disable all sound plugins.
  bool _available = true;
  bool get available => _available;
  set available(bool v) {
    _available = v;
    music.available = v;
    voice.available = v;
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

  Future<void> _play(Uint8List bytes) async {
    try {
      final p = AudioPlayer();
      p.onPlayerComplete.first.then((_) => p.dispose());
      await p.play(BytesSource(bytes), volume: 0.7);
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

  /// Celebration jingle: a bright rising arpeggio with a sparkling tail (new high score, level up).
  void fanfare() {
    if (!soundOn || !_available) return;
    _play(_cache.putIfAbsent('fanfare', () {
      const rate = 22050;
      final n = (rate * 2.2).toInt();
      final out = List<double>.filled(n, 0);
      const notes = [523.25, 659.25, 783.99, 1046.5, 1318.5, 1567.98];
      for (var k = 0; k < notes.length; k++) {
        final s0 = (rate * k * .12).toInt();
        for (var i = 0; s0 + i < n; i++) {
          final t = i / rate;
          final env = min(1.0, t / .004) * exp(-t * 3.2);
          out[s0 + i] += (sin(2 * pi * notes[k] * t) + .3 * sin(2 * pi * notes[k] * 2 * t)) * .17 * env;
        }
      }
      return _wav(out);
    }));
  }

  /// Short "whoosh + thud" for a miss.
  void miss() => beep(150, .3);

  void buzz([int ms = 10]) {
    if (!vibeOn) return;
    try {
      ms > 30 ? HapticFeedback.heavyImpact() : HapticFeedback.lightImpact();
    } catch (_) {}
  }
}
