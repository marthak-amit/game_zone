import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Tiny synthesized sound effects (no asset files needed) + haptics.
class Audio {
  bool soundOn = true, vibeOn = true;
  final _cache = <String, Uint8List>{};

  static Uint8List _tone(double freq, double seconds) {
    const rate = 22050;
    final n = (rate * seconds).toInt();
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
      final env = 1 - i / n;
      final v = (sin(2 * pi * freq * i / rate) * 0.3 * env * 32767).toInt();
      data.setInt16(44 + i * 2, v, Endian.little);
    }
    return data.buffer.asUint8List();
  }

  void beep(double freq, [double seconds = .12]) {
    if (!soundOn) return;
    final bytes = _cache.putIfAbsent('$freq-$seconds', () => _tone(freq, seconds));
    _play(bytes);
  }

  Future<void> _play(Uint8List bytes) async {
    try {
      final p = AudioPlayer();
      p.onPlayerComplete.first.then((_) => p.dispose());
      await p.play(BytesSource(bytes), volume: 0.7);
    } catch (_) {/* audio is best-effort */}
  }

  void buzz([int ms = 10]) {
    if (!vibeOn) return;
    try {
      ms > 30 ? HapticFeedback.heavyImpact() : HapticFeedback.lightImpact();
    } catch (_) {}
  }
}
