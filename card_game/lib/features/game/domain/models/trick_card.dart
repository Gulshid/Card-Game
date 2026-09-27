import 'package:equatable/equatable.dart';

import 'playing_card.dart';
import 'seat.dart';

/// One card played to a trick, paired with who played it — needed
/// because the engine must know *which seat* to credit when a trick
/// is won, not just which cards were played.
class TrickCard extends Equatable {
  const TrickCard({required this.seat, required this.card});

  final Seat seat;
  final PlayingCard card;

  @override
  List<Object?> get props => [seat, card];

  @override
  String toString() => '$seat:$card';
}
