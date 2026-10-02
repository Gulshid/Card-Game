// Spades Royale — multiplayer game server (Phase 10).
//
//   flutter pub get
//   dart run server/spades_server.dart          # listens on :8080
//   PORT=9000 dart run server/spades_server.dart
//
// Endpoints:
//   ws://HOST:PORT/ws       the game socket (see lib/features/multiplayer/
//                           domain/protocol/protocol.dart)
//   http://HOST:PORT/health JSON liveness + counters
//
// The server imports the *same* pure-Dart rules engine the app uses, so a
// move is legal on the server exactly when it is legal on the client.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'src/game_hub.dart';
import 'src/session.dart';

Future<void> main(List<String> args) async {
  final int port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final bool verbose = Platform.environment['SPADES_VERBOSE'] == '1';

  final GameHub hub = GameHub(
    log: (String line) {
      if (verbose) stdout.writeln('[${DateTime.now().toIso8601String()}] $line');
    },
  )..start();

  final Handler socketHandler = webSocketHandler((WebSocketChannel channel, String? _) {
    final ClientConnection conn = hub.attach(
      onSend: channel.sink.add,
      onClose: (int code, String reason) => channel.sink.close(code, reason),
    );
    // Frames are handled strictly in arrival order (hello may be async).
    Future<void> chain = Future<void>.value();
    channel.stream.listen(
      (Object? raw) {
        chain = chain.then((_) => hub.onRaw(conn, raw)).catchError((Object e, StackTrace s) {
          stderr.writeln('handler error: $e\n$s');
        });
      },
      onDone: () => hub.onClosed(conn),
      onError: (Object _) => hub.onClosed(conn),
      cancelOnError: true,
    );
  });

  FutureOr<Response> handler(Request request) {
    switch (request.url.path) {
      case 'ws':
        return socketHandler(request);
      case 'health':
        return Response.ok(
          jsonEncode({
            'ok': true,
            'connections': hub.connectionCount,
            'rooms': hub.roomCount,
            'matches': hub.matchCount,
            'queue': hub.queueLength,
          }),
          headers: {'content-type': 'application/json'},
        );
      default:
        return Response.notFound('not found');
    }
  }

  final HttpServer server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  stdout.writeln('Spades server listening on ws://${server.address.host}:${server.port}/ws');

  Future<void> shutdown(ProcessSignal signal) async {
    stdout.writeln('Received $signal — shutting down');
    await hub.stop();
    await server.close(force: true);
    exit(0);
  }

  ProcessSignal.sigint.watch().listen(shutdown);
  if (!Platform.isWindows) ProcessSignal.sigterm.watch().listen(shutdown);
}
