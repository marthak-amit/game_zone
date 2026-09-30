import 'package:flutter_tts/flutter_tts.dart';

/// Short spoken reactions ("Perfect!", "New high score!") using the phone's built-in voice.
class Voice {
  bool enabled = true;
  bool available = true;
  FlutterTts? _tts;
  bool _ready = false;
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);
  String _lastText = '';

  Future<void> _init() async {
    if (_ready) return;
    _tts = FlutterTts();
    try {
      await _tts!.setLanguage('en-US');
      await _tts!.setSpeechRate(.52);
      await _tts!.setPitch(1.15);
      await _tts!.setVolume(1.0);
    } catch (_) {}
    _ready = true;
  }

  /// Speak [text]. Throttled so lines never pile up; [force] skips the throttle (big moments).
  Future<void> say(String text, {bool force = false}) async {
    if (!available || !enabled) return;
    final now = DateTime.now();
    if (!force && now.difference(_last).inMilliseconds < 1500) return;
    if (text == _lastText && now.difference(_last).inSeconds < 4) return;
    _last = now;
    _lastText = text;
    try {
      await _init();
      await _tts!.stop();
      await _tts!.speak(text);
    } catch (_) {/* speech is best-effort */}
  }

  Future<void> stop() async {
    try {
      await _tts?.stop();
    } catch (_) {}
  }
}
