// Run against a running server: dart run tool/check_rooms.dart http://localhost:8099
import 'dart:async';
import 'dart:io';

import 'package:socket_io_client/socket_io_client.dart' as io;

Future<void> main(List<String> args) async {
  final url = args.isEmpty ? 'http://localhost:8099' : args.first;
  final sockets = <io.Socket>[];
  Future<io.Socket> connect() async {
    final socket = io.io(
      url,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableForceNew()
          .build(),
    );
    sockets.add(socket);
    final ready = Completer<void>();
    socket.onConnect((_) {
      if (!ready.isCompleted) ready.complete();
    });
    socket.onConnectError((error) {
      if (!ready.isCompleted) ready.completeError('$error');
    });
    socket.connect();
    await ready.future.timeout(const Duration(seconds: 5));
    return socket;
  }

  Future<Map> send(io.Socket socket, String event, dynamic payload) async {
    final result = Completer<Map>();
    socket.emitWithAck(
      event,
      payload,
      ack: (dynamic data) => result.complete(data as Map),
    );
    return result.future.timeout(const Duration(seconds: 5));
  }

  void check(bool condition, String message) {
    if (!condition) throw StateError(message);
  }

  try {
    final host = await connect();
    final guest = await connect();
    final created = await send(host, 'create_room', {'name': 'Test host'});
    check(created['ok'] == true, 'Create failed: $created');
    final code = created['room']['code'];
    final update = Completer<Map>();
    host.on('room_updated', (dynamic data) {
      if ((data['players'] as List).length == 2 && !update.isCompleted) {
        update.complete(data as Map);
      }
    });
    final joined = await send(guest, 'join_room', {
      'name': 'Test guest',
      'code': code,
    });
    check(joined['ok'] == true, 'Join failed: $joined');
    check(
      (joined['room']['players'] as List).length == 2,
      'Guest did not receive both players',
    );
    await update.future.timeout(const Duration(seconds: 5));
    final denied = await send(guest, 'start_game', {});
    check(denied['ok'] == false, 'Guest must not start the game');
    final started = await send(host, 'start_game', {});
    check(started['ok'] == true, 'Two-player start failed');
    check(
      started['room']['totalRounds'] == 10,
      'Match must contain ten questions',
    );
    final question = started['room']['question'] as Map;
    check(
      ['English', 'Mathematics'].contains(question['category']),
      'Question must come from the new banks',
    );
    check(!question.containsKey('correctAnswer'), 'Answer leaked');
    final buzzes = await Future.wait([
      send(host, 'buzz', {'questionId': question['id']}),
      send(guest, 'buzz', {'questionId': question['id']}),
    ]);
    check(
      buzzes.where((b) => b['ok'] == true).length == 1,
      'Exactly one buzzer must win',
    );
    final winner = buzzes[0]['ok'] == true ? host : guest;
    final answer = await send(winner, 'submit_answer', {
      'questionId': question['id'],
      'answer': question['choices'][0],
    });
    check(answer['ok'] == true, 'Answer failed');
    final duplicate = await send(winner, 'submit_answer', {
      'questionId': question['id'],
      'answer': question['choices'][0],
    });
    check(duplicate['ok'] == false, 'Duplicate answer was accepted');
    final transferred = Completer<void>();
    guest.on('room_updated', (dynamic data) {
      if (data['hostId'] == guest.id && !transferred.isCompleted) {
        transferred.complete();
      }
    });
    final left = await send(host, 'leave_room', null);
    check(left['ok'] == true, 'Leave failed');
    await transferred.future.timeout(const Duration(seconds: 5));
    stdout.writeln(
      'PASS: create, join, host-only start, two-player match, exclusive buzz, answer, duplicate rejection, and host transfer.',
    );
  } finally {
    for (final socket in sockets) {
      socket.dispose();
    }
  }
}
