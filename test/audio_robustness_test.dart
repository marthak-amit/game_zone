import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sky_stack/services/music.dart';
import 'package:sky_stack/services/sfx_player.dart';

/// A fake native player that records what happens to it.
class FakePlayer implements TrackPlayer {
  bool playing = false, disposed = false;
  int plays = 0, stops = 0;
  double volume = 0;
  Completer<void>? holdPlay; // lets a test keep play() "in flight"
  @override
  Future<void> play(Uint8List wav, double v) async {
    plays++;
    volume = v;
    if (holdPlay != null) await holdPlay!.future; // native start still pending...
    if (disposed) throw StateError('play on disposed player');
    playing = true;
  }

  @override
  Future<void> setVolume(double v) async => volume = v;
  @override
  Future<void> pause() async => playing = false;
  @override
  Future<void> resume() async => playing = true;
  @override
  Future<void> stop() async {
    stops++;
    playing = false;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    playing = false;
  }
}

class Rig {
  final players = <FakePlayer>[];
  late final Music music;
  Completer<Uint8List>? hold; // holds the (isolate) track generation
  Rig({bool slowTracks = false}) {
    music = Music(
      fadeStep: Duration.zero,
      playerFactory: () {
        final p = FakePlayer();
        players.add(p);
        return p;
      },
      trackBuilder: (t) async {
        if (slowTracks) {
          hold = Completer<Uint8List>();
          return hold!.future;
        }
        return Uint8List(10);
      },
    );
  }

  bool get anyPlaying => players.any((p) => p.playing);
}

Future<void> settle() => Future.delayed(const Duration(milliseconds: 20));

void main() {
  group('Music', () {
    test('plays the requested track, and only one player exists', () async {
      final r = Rig();
      await r.music.setWorld(homeTrack);
      await r.music.setWorld(2);
      await r.music.setWorld(3);
      expect(r.music.playingTrack, 3);
      expect(r.players.length, 1, reason: 'tracks are switched on a single native player');
      expect(r.anyPlaying, isTrue);
    });

    test('turning music OFF stops and destroys the player', () async {
      final r = Rig();
      await r.music.setWorld(homeTrack);
      expect(r.anyPlaying, isTrue);
      r.music.setEnabled(false);
      await settle();
      expect(r.anyPlaying, isFalse);
      expect(r.players.single.disposed, isTrue);
      expect(r.music.isPlaying, isFalse);
    });

    test('music stays off: navigation, taps and track changes cannot restart it', () async {
      final r = Rig();
      await r.music.setWorld(homeTrack);
      r.music.setEnabled(false);
      await settle();
      r.music.ensure(); // a tap anywhere
      await r.music.setWorld(0); // entering the game
      await r.music.setWorld(homeTrack); // back to the menu
      r.music.resume(); // app resumed from background
      await settle();
      expect(r.anyPlaying, isFalse);
      expect(r.players.length, 1, reason: 'no new player may be created while disabled');
    });

    test('RACE: turning music off while a track is still loading never lets it start', () async {
      final r = Rig(slowTracks: true);
      final f = r.music.setWorld(0); // track is still being generated
      await settle();
      r.music.setEnabled(false);
      r.hold!.complete(Uint8List(10)); // generation finishes AFTER the switch was turned off
      await f;
      await settle();
      expect(r.anyPlaying, isFalse);
      expect(r.players, isEmpty);
    });

    test('RACE: switch turned off while play() is in flight => player is stopped and disposed afterwards', () async {
      final players = <FakePlayer>[];
      final gate = Completer<void>();
      final m = Music(
        fadeStep: Duration.zero,
        playerFactory: () {
          final p = FakePlayer()..holdPlay = gate;
          players.add(p);
          return p;
        },
        trackBuilder: (t) async => Uint8List(10),
      );
      final f = m.setWorld(1);
      await settle(); // play() is now pending inside the native layer
      m.setEnabled(false);
      gate.complete(); // native start completes after the user already turned music off
      await f;
      await settle();
      expect(players.any((p) => p.playing), isFalse, reason: 'music must not be audible after being turned off');
      expect(players.every((p) => p.disposed), isTrue);
    });

    test('turning music back ON resumes the wanted track on a fresh player', () async {
      final r = Rig();
      await r.music.setWorld(4);
      r.music.setEnabled(false);
      await settle();
      r.music.setEnabled(true);
      await settle();
      expect(r.music.playingTrack, 4);
      expect(r.anyPlaying, isTrue);
      expect(r.players.length, 2);
      expect(r.players.first.disposed, isTrue);
    });

    test('rapid on/off toggling never leaves stray players playing', () async {
      final r = Rig();
      await r.music.setWorld(2);
      for (var i = 0; i < 30; i++) {
        r.music.setEnabled(false);
        r.music.setEnabled(true);
      }
      r.music.setEnabled(false);
      await settle();
      expect(r.anyPlaying, isFalse);
      expect(r.players.every((p) => p.disposed || !p.playing), isTrue);
    });

    test('rapid track changes: the last request wins', () async {
      final r = Rig();
      unawaited(r.music.setWorld(0));
      unawaited(r.music.setWorld(1));
      unawaited(r.music.setWorld(2));
      await r.music.setWorld(5);
      await settle();
      expect(r.music.playingTrack, 5);
      expect(r.players.where((p) => p.playing).length, 1);
    });

    test('duck lowers the volume and restoring brings it back', () async {
      final r = Rig();
      await r.music.setWorld(0);
      r.music.duck(true);
      expect(r.players.single.volume, closeTo(Music.volume * .3, .001));
      r.music.duck(false);
      expect(r.players.single.volume, closeTo(Music.volume, .001));
    });

    test('pause/resume does not restart music that is disabled', () async {
      final r = Rig();
      await r.music.setWorld(0);
      r.music.pause();
      expect(r.anyPlaying, isFalse);
      r.music.resume();
      expect(r.anyPlaying, isTrue);
      r.music.setEnabled(false);
      await settle();
      r.music.resume();
      expect(r.anyPlaying, isFalse);
    });
  });

  group('SfxPlayer (bounded native resources)', () {
    test('one pool per sound no matter how often it is played', () async {
      var created = 0, started = 0;
      final s = SfxPlayer(
        minGap: Duration.zero,
        poolFactory: (b) async {
          created++;
          return _Pool(() => started++);
        },
      );
      for (var i = 0; i < 300; i++) {
        await s.playPooled('thud', () => Uint8List(4), .8);
      }
      expect(created, 1);
      expect(started, 300);
    });

    test('many different sounds still create one pool each (not one per play)', () async {
      var created = 0;
      final s = SfxPlayer(minGap: Duration.zero, poolFactory: (b) async {
        created++;
        return _Pool(() {});
      });
      for (var round = 0; round < 20; round++) {
        for (final k in ['a', 'b', 'c', 'd']) {
          await s.playPooled(k, () => Uint8List(4), .8);
        }
      }
      expect(created, 4);
    });

    test('shared players never exceed the limit', () async {
      var created = 0;
      final s = SfxPlayer(minGap: Duration.zero, sharedCount: 3, oneShotFactory: () {
        created++;
        return _Shot();
      });
      for (var i = 0; i < 200; i++) {
        await s.playShared('k$i', () => Uint8List(4), .8);
      }
      expect(created, 3);
      expect(s.sharedPlayers, 3);
    });

    test('the same sound cannot be machine-gunned', () async {
      var started = 0;
      final s = SfxPlayer(minGap: const Duration(milliseconds: 100), poolFactory: (b) async => _Pool(() => started++));
      for (var i = 0; i < 50; i++) {
        await s.playPooled('click', () => Uint8List(4), .8);
      }
      expect(started, 1);
    });

    test('a failing audio backend never throws into the game and recovers later', () async {
      var attempts = 0;
      final s = SfxPlayer(minGap: Duration.zero, poolFactory: (b) async {
        attempts++;
        if (attempts < 3) throw StateError('native error');
        return _Pool(() {});
      });
      for (var i = 0; i < 5; i++) {
        await s.playPooled('x', () => Uint8List(4), .8); // must not throw
      }
      expect(s.poolCount, 1);
    });
  });
}

class _Pool implements SfxPool {
  final void Function() onStart;
  _Pool(this.onStart);
  @override
  Future<void> start(double volume) async => onStart();
}

class _Shot implements OneShot {
  @override
  Future<void> play(Uint8List bytes, double volume) async {}
}
