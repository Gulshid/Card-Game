import 'package:card_game/features/game/domain/models/seat.dart';
import 'package:equatable/equatable.dart';

/// One chair in a lobby room or running match, as the server describes it.
class RoomSeatInfo extends Equatable {
  const RoomSeatInfo({
    required this.seat,
    required this.name,
    required this.avatarId,
    required this.isBot,
    required this.connected,
    required this.isYou,
    required this.isHost,
    this.occupied = true,
  });

  /// An unfilled chair in a room that hasn't started yet.
  const RoomSeatInfo.empty(this.seat)
      : name = '',
        avatarId = 0,
        isBot = false,
        connected = false,
        isYou = false,
        isHost = false,
        occupied = false;

  factory RoomSeatInfo.fromJson(Map<String, Object?> json) {
    return RoomSeatInfo(
      seat: Seat.values.byName(json['seat']! as String),
      name: (json['name'] as String?) ?? '',
      avatarId: ((json['avatarId'] as num?) ?? 0).toInt(),
      isBot: (json['isBot'] as bool?) ?? false,
      connected: (json['connected'] as bool?) ?? false,
      isYou: (json['isYou'] as bool?) ?? false,
      isHost: (json['isHost'] as bool?) ?? false,
      occupied: (json['occupied'] as bool?) ?? true,
    );
  }

  final Seat seat;
  final String name;
  final int avatarId;
  final bool isBot;
  final bool connected;
  final bool isYou;
  final bool isHost;
  final bool occupied;

  Map<String, Object?> toJson() => {
        'seat': seat.name,
        'name': name,
        'avatarId': avatarId,
        'isBot': isBot,
        'connected': connected,
        'isYou': isYou,
        'isHost': isHost,
        'occupied': occupied,
      };

  @override
  List<Object?> get props => [seat, name, avatarId, isBot, connected, isYou, isHost, occupied];
}

/// A private room (or the pre-match view of a quick-match group).
class RoomInfo extends Equatable {
  const RoomInfo({required this.code, required this.seats, required this.isPrivate});

  factory RoomInfo.fromJson(Map<String, Object?> json) {
    final List<Object?> rawSeats = (json['seats']! as List).cast<Object?>();
    return RoomInfo(
      code: json['code']! as String,
      isPrivate: (json['private'] as bool?) ?? true,
      seats: [
        for (final Object? s in rawSeats) RoomSeatInfo.fromJson((s! as Map).cast<String, Object?>()),
      ],
    );
  }

  final String code;
  final bool isPrivate;
  final List<RoomSeatInfo> seats;

  int get humanCount => seats.where((s) => s.occupied && !s.isBot).length;
  bool get iAmHost => seats.any((s) => s.isYou && s.isHost);

  @override
  List<Object?> get props => [code, isPrivate, seats];
}
