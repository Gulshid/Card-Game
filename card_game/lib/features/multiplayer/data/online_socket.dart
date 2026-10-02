import 'dart:async';

import 'package:web_socket_channel/web_socket_channel.dart';

/// The smallest socket the session needs. Exists so `OnlineSession` can be
/// unit-tested with an in-memory fake instead of a real network.
abstract interface class OnlineSocket {
  /// Text frames. The stream completes (or errors) when the socket closes.
  Stream<String> get incoming;

  void send(String data);

  Future<void> close([int? code, String? reason]);
}

typedef OnlineSocketConnector = Future<OnlineSocket> Function(Uri uri);

class WebSocketOnlineSocket implements OnlineSocket {
  WebSocketOnlineSocket(this._channel);

  final WebSocketChannel _channel;

  @override
  Stream<String> get incoming => _channel.stream.where((Object? e) => e is String).cast<String>();

  @override
  void send(String data) => _channel.sink.add(data);

  @override
  Future<void> close([int? code, String? reason]) => _channel.sink.close(code, reason);
}

/// Production connector (works on mobile, desktop and web).
Future<OnlineSocket> connectWebSocket(Uri uri) async {
  final WebSocketChannel channel = WebSocketChannel.connect(uri);
  await channel.ready;
  return WebSocketOnlineSocket(channel);
}
