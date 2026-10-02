/// Rule-based milestones. Each one is evaluated purely from lifetime
/// [PlayerStats] (see `AchievementRules`) and, once earned, is kept
/// forever — it is persisted by id, so a future tweak to a rule can never
/// take away something a player already unlocked.
///
/// Every achievement unlocks exactly one cosmetic [CardBackStyle].
enum Achievement {
  firstWin('First Victory', 'Win your first match.'),
  hotStreak('Hot Streak', 'Win 3 matches in a row.'),
  nilMaster('Nil Master', 'Make good on a Nil bid.'),
  giantSlayer('Giant Slayer', 'Beat the Hard bots.'),
  veteran('Veteran', 'Play 10 matches.'),
  domination('Domination', 'Win a match by 200 or more points.');

  const Achievement(this.title, this.description);

  final String title;
  final String description;

  /// The card back this achievement unlocks.
  CardBackStyle get reward => CardBackStyle.values.firstWhere((s) => s.unlockedBy == this);
}

/// Cosmetic card backs. [classic] is always available; every other style
/// is gated behind an [Achievement]. Colors/icons live in the
/// presentation layer (`cosmetic_theme.dart`) so this stays pure Dart.
enum CardBackStyle {
  classic('Classic', null),
  crimson('Crimson', Achievement.firstWin),
  emerald('Emerald', Achievement.hotStreak),
  midnight('Midnight', Achievement.nilMaster),
  royal('Royal', Achievement.giantSlayer),
  slate('Slate', Achievement.veteran),
  sunset('Sunset', Achievement.domination);

  const CardBackStyle(this.label, this.unlockedBy);

  final String label;

  /// `null` means available from the start.
  final Achievement? unlockedBy;

  bool isUnlockedWith(Set<Achievement> unlocked) => unlockedBy == null || unlocked.contains(unlockedBy);
}
