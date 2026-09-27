import 'package:equatable/equatable.dart';

import 'playing_card.dart';
import 'seat.dart';

/// Base type for anything a seat can submit to the engine. Sealed via
/// a private unnamed constructor so the only subclasses that can ever
/// exist are the two declared in this file — `switch` on `Move` in
/// the engine is therefore exhaustive and the analyzer will flag any
/// missing case if a third `Move` type is ever added.
sealed class Move extends Equatable {
  const Move({required this.seat});

  final Seat seat;
}

/// Submitted during [GamePhase.bidding]. `tricksBid == 0` means Nil.
class BidMove extends Move {
  const BidMove({required super.seat, required this.tricksBid});

  final int tricksBid;

  bool get isNil => tricksBid == 0;

  @override
  List<Object?> get props => [seat, tricksBid];

  @override
  String toString() => 'BidMove($seat bids $tricksBid)';
}

/// Submitted during [GamePhase.playing].
class PlayCardMove extends Move {
  const PlayCardMove({required super.seat, required this.card});

  final PlayingCard card;

  @override
  List<Object?> get props => [seat, card];

  @override
  String toString() => 'PlayCardMove($seat plays $card)';
}
