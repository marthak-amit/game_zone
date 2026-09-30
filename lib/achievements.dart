import 'store.dart';

/// Numbers from the run that just ended, used to unlock achievements.
class RunStats {
  final int score, maxCombo, perfects;
  const RunStats(this.score, this.maxCombo, this.perfects);
}

class Achievement {
  final String id, title, desc, icon;
  final int reward;
  final bool Function(Store s, RunStats r) test;
  const Achievement(this.id, this.icon, this.title, this.desc, this.reward, this.test);
}

final achievements = <Achievement>[
  Achievement('s10', '🏗', 'First Tower', 'Reach score 10', 50, (s, r) => r.score >= 10),
  Achievement('s25', '🏙', 'Skyline', 'Reach score 25', 100, (s, r) => r.score >= 25),
  Achievement('s50', '☁', 'Cloud Piercer', 'Reach score 50', 250, (s, r) => r.score >= 50),
  Achievement('s100', '👑', 'Legend', 'Reach score 100', 500, (s, r) => r.score >= 100),
  Achievement('c5', '🔥', 'In the Zone', 'Get a 5x perfect combo', 60, (s, r) => r.maxCombo >= 5),
  Achievement('c10', '💎', 'Perfectionist', 'Get a 10x perfect combo', 150, (s, r) => r.maxCombo >= 10),
  Achievement('night', '🌙', 'Night Owl', 'Reach the Starry Night world (score 24)', 80, (s, r) => r.score >= 24),
  Achievement('storm', '⛈', 'Rainy Day', 'Reach the Rain Storm world (score 36)', 120, (s, r) => r.score >= 36),
  Achievement('space', '🚀', 'Space Cadet', 'Reach Deep Space (score 60)', 200, (s, r) => r.score >= 60),
  Achievement('g10', '🎮', 'Regular', 'Play 10 games', 80, (s, r) => s.games >= 10),
  Achievement('str3', '📅', 'Devoted', 'Reach a 3 day login streak', 100, (s, r) => s.streak >= 3),
  Achievement('skins3', '🎨', 'Collector', 'Own 3 block skins', 100, (s, r) => skins.where(s.owns).length >= 3),
];
