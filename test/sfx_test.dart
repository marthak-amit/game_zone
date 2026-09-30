import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sky_stack/services/audio.dart';

List<int> samples(Uint8List wav) {
  final bd = wav.buffer.asByteData(wav.offsetInBytes);
  return List.generate((wav.length - 44) ~/ 2, (i) => bd.getInt16(44 + i * 2, Endian.little));
}

double rms(List<int> s, [int from = 0, int? to]) {
  to ??= s.length;
  var a = 0.0;
  for (var i = from; i < to; i++) {
    a += s[i] * s[i];
  }
  return sqrt(a / max(1, to - from));
}

void main() {
  final builders = <String, (Uint8List Function(), double, double)>{
    // name: (builder, min seconds, max seconds)
    'thud': (() => Audio.buildThud(), .15, .5),
    'thud perfect': (() => Audio.buildThud(perfect: true), .15, .5),
    'game over': (Audio.buildGameOver, 1.0, 2.0),
    'start': (Audio.buildStart, .8, 2.0),
    'applause': (() => Audio.buildApplause(), 2.5, 4.5),
    'applause short': (() => Audio.buildApplause(seconds: 2.2), 1.5, 3.0),
    'sparkle': (Audio.buildSparkle, .4, 1.2),
    'whoosh': (Audio.buildWhoosh, .6, 1.5),
    'ding': (Audio.buildDing, .6, 1.6),
    'fanfare': (Audio.buildFanfare, 1.5, 3.0),
    'click': (Audio.buildClick, .02, .15),
  };

  for (final e in builders.entries) {
    test('sfx "${e.key}" is a valid, audible, unclipped WAV of sensible length', () {
      final wav = e.value.$1();
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      final s = samples(wav);
      final secs = s.length / 22050;
      expect(secs, inInclusiveRange(e.value.$2, e.value.$3));
      final peak = s.map((x) => x.abs()).reduce(max);
      expect(peak, inInclusiveRange(12000, 32767), reason: 'loud enough, not clipping');
      expect(rms(s), greaterThan(800), reason: 'audible');
    });
  }

  test('applause swells then fades (crowd builds up, then dies away)', () {
    final s = samples(Audio.buildApplause());
    final n = s.length;
    final start = rms(s, 0, n ~/ 12), middle = rms(s, n ~/ 3, n ~/ 2), end = rms(s, n - n ~/ 12);
    expect(middle, greaterThan(start));
    expect(middle, greaterThan(end * 1.5));
  });

  test('landing thud is short-lived: energy mostly in the first half', () {
    final s = samples(Audio.buildThud());
    expect(rms(s, 0, s.length ~/ 3), greaterThan(rms(s, s.length ~/ 2) * 3));
  });
}
