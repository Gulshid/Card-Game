/// The four table positions. Declared clockwise so `next` is always
/// `Seat.values[(index + 1) % 4]` — turn order and dealing order both
/// walk this same sequence.
enum Seat {
  north,
  east,
  south,
  west;

  Seat get next => Seat.values[(index + 1) % Seat.values.length];

  /// The seat directly across the table — always the partner in
  /// Spades' fixed 2v2 partnership (N+S vs E+W).
  Seat get partner => Seat.values[(index + 2) % Seat.values.length];

  /// Partnership index: 0 for North/South, 1 for East/West. Used as
  /// the key for every team-level score/bid/bag lookup.
  int get team => index.isEven ? 0 : 1;

  /// The other team's index — the only two values are 0 and 1.
  int get opposingTeam => team == 0 ? 1 : 0;
}
