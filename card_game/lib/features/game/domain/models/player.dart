import 'package:equatable/equatable.dart';

import 'seat.dart';

/// Identity/display info for a seat — name, avatar hook, bot flag.
/// Deliberately separate from [Seat] and from `GameState`: the engine
/// only ever reasons about `Seat`, never about *who* is sitting there.
/// This keeps the rules engine reusable for any combination of human
/// and bot players without caring which is which.
class Player extends Equatable {
  const Player({
    required this.seat,
    required this.name,
    this.isBot = false,
  });

  final Seat seat;
  final String name;
  final bool isBot;

  @override
  List<Object?> get props => [seat, name, isBot];
}
