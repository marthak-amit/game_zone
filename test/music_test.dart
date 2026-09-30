import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sky_stack/services/music.dart';

void main() {
  test('every world gets a valid, non-clipping, seamless music loop', () {
    for (var w = 0; w <= homeTrack; w++) {
      final sw = Stopwatch()..start();
      final wav = buildTrack(w);
      sw.stop();
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      final n = (wav.length - 44) ~/ 2;
      final bd = wav.buffer.asByteData();
      final s = List<int>.generate(n, (i) => bd.getInt16(44 + i * 2, Endian.little));
      final seconds = n / 16000;
      expect(seconds, inInclusiveRange(12, 40), reason: 'track $w loop length');
      final peak = s.map((e) => e.abs()).reduce(max);
      expect(peak, inInclusiveRange(15000, 32767), reason: 'world $w level');
      final rms = sqrt(s.map((e) => e * e).reduce((a, b) => a + b) / n);
      expect(rms, greaterThan(1500), reason: 'world $w is audible');
      // seam: jump between the last and first sample must be no bigger than a typical step
      final seam = (s.first - s.last).abs();
      var maxStep = 0;
      for (var i = 1; i < n; i++) {
        maxStep = max(maxStep, (s[i] - s[i - 1]).abs());
      }
      expect(seam, lessThanOrEqualTo(maxStep * 2 + 200), reason: 'world $w loop seam');
      // ignore: avoid_print
      // children's-song structure: the tune repeats (first half ~ second half) so it is easy to hum along to
      final half = n ~/ 2;
      var dot = 0.0, a2 = 0.0, b2 = 0.0;
      for (var i = 0; i < half; i++) {
        dot += s[i] * s[half + i];
        a2 += s[i] * s[i];
        b2 += s[half + i] * s[half + i];
      }
      expect(dot / sqrt(a2 * b2), greaterThan(.55), reason: 'track $w repeats its tune');
      // ignore: avoid_print
      print('world $w: ${seconds.toStringAsFixed(1)}s peak=$peak rms=${rms.round()} seam=$seam maxStep=$maxStep gen=${sw.elapsedMilliseconds}ms');
    }
  });
}
