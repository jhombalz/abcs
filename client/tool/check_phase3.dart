// Requires a running game API. Creates its own room; takes about 45 seconds.
import 'dart:async';
import 'dart:io';

import 'package:socket_io_client/socket_io_client.dart' as io;

Future<void> main(List<String> args) async {
  final url = args.isEmpty ? 'http://localhost:8099' : args.first;
  final sockets = <io.Socket>[];
  void check(bool value, String message) {
    if (!value) throw StateError(message);
  }

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

  Future<Map> send(io.Socket socket, String event, Map payload) async {
    final ready = Completer<Map>();
    socket.emitWithAck(
      event,
      payload,
      ack: (dynamic data) => ready.complete(data as Map),
    );
    return ready.future.timeout(const Duration(seconds: 5));
  }

  Future<Map> watch(io.Socket socket, bool Function(Map) predicate) {
    final ready = Completer<Map>();
    void listener(dynamic data) {
      if (!ready.isCompleted && predicate(data as Map)) ready.complete(data);
    }

    socket.on('room_updated', listener);
    return ready.future
        .timeout(const Duration(seconds: 8))
        .whenComplete(() => socket.off('room_updated', listener));
  }

  try {
    final host = await connect();
    final guest = await connect();
    final created = await send(host, 'create_room', {'name': 'Phase 3 host'});
    check(created['ok'] == true, 'Create failed');
    final code = created['room']['code'];
    check(
      (await send(guest, 'join_room', {
            'name': 'Phase 3 guest',
            'code': code,
          }))['ok'] ==
          true,
      'Join failed',
    );
    check(
      (await send(guest, 'configure_game', {'category': 'English'}))['ok'] ==
          false,
      'Guest changed settings',
    );
    final synced = watch(
      guest,
      (state) => state['settings']['category'] == 'English',
    );
    check(
      (await send(host, 'configure_game', {'category': 'English'}))['ok'] ==
          true,
      'Configure failed',
    );
    await synced;
    final started = await send(host, 'start_game', {});
    check(started['ok'] == true, 'Start failed');
    Map room = started['room'] as Map;
    final ids = <String>{};
    final scores = <String, int>{host.id!: 0, guest.id!: 0};
    for (var round = 1; round <= 10; round++) {
      check(
        room['totalRounds'] == 10 && room['round'] == round,
        'Wrong round count',
      );
      final q = room['question'] as Map;
      check(
        q['category'] == 'English' && !q.containsKey('correctAnswer'),
        'Wrong subject or leaked answer',
      );
      check(ids.add(q['id'] as String), 'Repeated question ID');
      final advanced = watch(
        host,
        (state) =>
            state['status'] == 'GAME_FINISHED' ||
            state['status'] == 'QUESTION_ACTIVE' && state['round'] == round + 1,
      );
      for (final player in [host, guest]) {
        if (room['status'] == 'QUESTION_FINISHED') break;
        final buzz = await send(player, 'buzz', {'questionId': q['id']});
        check(buzz['ok'] == true, 'Buzz failed');
        final answer = await send(player, 'submit_answer', {
          'questionId': q['id'],
          'answer': q['choices'][0],
        });
        check(answer['ok'] == true, 'Answer failed');
        room = answer['room'] as Map;
        if (room['feedback']['kind'] == 'correct') {
          scores[player.id!] = scores[player.id!]! + 100;
        }
        check(
          room['result'] == null ||
              !(room['result'] as Map).containsKey('correctAnswer'),
          'Result leaked answer',
        );
      }
      check(room['status'] == 'QUESTION_FINISHED', 'Question did not finish');
      room = await advanced;
    }
    check(room['status'] == 'GAME_FINISHED', 'Match did not finish');
    for (final player in room['players'] as List) {
      check(player['score'] == scores[player['id']], 'Wrong final score');
    }
    check(
      (await send(guest, 'return_to_lobby', {}))['ok'] == false,
      'Guest returned room to lobby',
    );
    final lobbySynced = watch(guest, (state) => state['status'] == 'WAITING');
    final lobby = await send(host, 'return_to_lobby', {});
    check(
      lobby['ok'] == true && lobby['room']['code'] == code,
      'Room code changed',
    );
    final guestLobby = await lobbySynced;
    check(
      (guestLobby['players'] as List).every((p) => p['score'] == 0),
      'Scores did not reset',
    );
    final third = await connect();
    check(
      (await send(third, 'join_room', {
            'name': 'New friend',
            'code': code,
          }))['ok'] ==
          true,
      'Room did not reopen',
    );
    check(
      (await send(host, 'configure_game', {'category': 'Mathematics'}))['ok'] ==
          true,
      'Math configure failed',
    );
    final rematch = await send(host, 'start_game', {});
    check(
      rematch['ok'] == true &&
          rematch['room']['question']['category'] == 'Mathematics',
      'Subject change failed',
    );
    check(
      (rematch['room']['eligible'] as List).length == 3,
      'New player not included',
    );
    check(
      (await send(host, 'return_to_lobby', {}))['ok'] == false,
      'Lobby return allowed during play',
    );
    stdout.writeln(
      'PASS: subject sync and permissions, ten complete rounds, score totals, answer privacy, same-code lobby return, new joins, and Mathematics rematch.',
    );
  } finally {
    for (final socket in sockets) {
      socket.dispose();
    }
  }
}
