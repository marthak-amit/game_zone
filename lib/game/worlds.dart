import 'dart:ui';

/// Static description of one background "world".
class World {
  final String id, name;
  final Color top, bottom;
  final double stars, rain, clouds, cloudDark, sun, sunY, moon, aurora, planet, lights;
  const World(this.id, this.name, this.top, this.bottom,
      {this.stars = 0,
      this.rain = 0,
      this.clouds = 0,
      this.cloudDark = 0,
      this.sun = 0,
      this.sunY = .2,
      this.moon = 0,
      this.aurora = 0,
      this.planet = 0,
      this.lights = 0});
}

const worlds = <World>[
  World('morning', 'Morning Sky', Color(0xFF4C9BE8), Color(0xFFBFE6FF), clouds: .9, sun: 1, sunY: .16),
  World('golden', 'Golden Hour', Color(0xFF5B3C88), Color(0xFFFFA45C), clouds: .8, cloudDark: .1, sun: 1, sunY: .42, lights: .25),
  World('night', 'Starry Night', Color(0xFF040818), Color(0xFF1C2E63), stars: 1, moon: 1, clouds: .18, cloudDark: .6, lights: 1),
  World('storm', 'Rain Storm', Color(0xFF1B212C), Color(0xFF465267), rain: 1, clouds: 1, cloudDark: 1, lights: .7),
  World('aurora', 'Aurora', Color(0xFF031018), Color(0xFF0E4B4B), stars: .8, aurora: 1, lights: .6),
  World('space', 'Deep Space', Color(0xFF0B0220), Color(0xFF3A1170), stars: 1, planet: 1),
];

/// Interpolated look between two worlds.
class WorldState {
  final Color top, bottom;
  final double stars, rain, clouds, cloudDark, sun, sunY, moon, aurora, planet, lights;
  const WorldState(this.top, this.bottom, this.stars, this.rain, this.clouds, this.cloudDark, this.sun,
      this.sunY, this.moon, this.aurora, this.planet, this.lights);

  static double _l(double a, double b, double t) => a + (b - a) * t;

  static WorldState blend(World a, World b, double t) => WorldState(
        Color.lerp(a.top, b.top, t)!,
        Color.lerp(a.bottom, b.bottom, t)!,
        _l(a.stars, b.stars, t),
        _l(a.rain, b.rain, t),
        _l(a.clouds, b.clouds, t),
        _l(a.cloudDark, b.cloudDark, t),
        _l(a.sun, b.sun, t),
        _l(a.sunY, b.sunY, t),
        _l(a.moon, b.moon, t),
        _l(a.aurora, b.aurora, t),
        _l(a.planet, b.planet, t),
        _l(a.lights, b.lights, t),
      );

  /// [pos] is a continuous world position: 2.0 = exactly the third world,
  /// the last 45% of each unit is a smooth transition into the next world.
  static WorldState at(double pos) {
    final n = worlds.length;
    final i = pos.floor();
    final local = pos - i;
    var t = ((local - .55) / .45).clamp(0.0, 1.0);
    t = t * t * (3 - 2 * t);
    return blend(worlds[i % n], worlds[(i + 1) % n], t);
  }
}
