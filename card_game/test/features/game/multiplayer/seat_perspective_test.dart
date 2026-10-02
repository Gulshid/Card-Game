import 'package:card_game/features/game/domain/engine/spades_rules_engine.dart';
import 'package:card_game/features/game/domain/models/game_state.dart';
import 'package:card_game/features/game/domain/models/seat.dart';
import 'package:card_game/features/multiplayer/domain/models/seat_perspective.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SeatPerspective', () {
    test('local player always maps to South and back', () {
      for (final Seat mine in Seat.values) {
        final SeatPerspective p = SeatPerspective(mine);
        expect(p.toView(mine), Seat.south);
        for (final Seat s in Seat.values) {
          expect(p.fromView(p.toView(s)), s);
        }
      }
    });

    test('partner always lands North, opponents East/West', () {
      for (final Seat mine in Seat.values) {
        final SeatPerspective p = SeatPerspective(mine);
        expect(p.toView(mine.partner), Seat.north);
        expect({p.toView(mine.next), p.toView(mine.next.partner)}, {Seat.east, Seat.west});
      }
    });

    test('team indexes swap only for odd seats, so "Us" is always team 0', () {
      final GameState g = SpadesRulesEngine.newMatch(seed: 1).copyWith(teamScores: {0: 120, 1: 40});
      // North/South players: scores unchanged.
      expect(SeatPerspective(Seat.north).rotate(g).teamScores, {0: 120, 1: 40});
      expect(SeatPerspective(Seat.south).rotate(g).teamScores, {0: 120, 1: 40});
      // East/West players are team 1 on the server: their team becomes "Us".
      expect(SeatPerspective(Seat.east).rotate(g).teamScores, {0: 40, 1: 120});
      expect(SeatPerspective(Seat.west).rotate(g).teamScores, {0: 40, 1: 120});
    });

    test('rotation keeps each hand with the same player', () {
      final GameState g = SpadesRulesEngine.newMatch(seed: 7);
      final SeatPerspective p = SeatPerspective(Seat.west);
      final GameState r = p.rotate(g);
      for (final Seat s in Seat.values) {
        expect(r.hands[p.toView(s)], g.hands[s]);
      }
      expect(r.turn, p.toView(g.turn));
    });

    test('winningTeam is re-indexed', () {
      final GameState g = SpadesRulesEngine.newMatch(seed: 1).copyWith(winningTeam: 1);
      expect(SeatPerspective(Seat.east).rotate(g).winningTeam, 0);
      expect(SeatPerspective(Seat.north).rotate(g).winningTeam, 1);
    });
  });
}
