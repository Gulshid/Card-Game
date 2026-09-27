import 'package:equatable/equatable.dart';

import 'rank.dart';
import 'suit.dart';

/// A single playing card. Named `PlayingCard`, not `Card`, so this
/// file can be imported into the same scope as `package:flutter/
/// material.dart` (which owns the `Card` widget) without a conflict
/// or an import alias anywhere in the app.
///
/// Immutable and cheap to compare: two `PlayingCard`s are equal iff
/// their suit and rank match — there is exactly one of each in a
/// standard 52-card deck, so no separate identity field is needed.
class PlayingCard extends Equatable {
  const PlayingCard({required this.suit, required this.rank});

  final Suit suit;
  final Rank rank;

  @override
  List<Object?> get props => [suit, rank];

  @override
  String toString() => '${rank.label}${suit.symbol}';
}
