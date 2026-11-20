// Creates a private test room using three real Dart Socket.IO clients.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:socket_io_client/socket_io_client.dart' as io;

Future<void> main(List<String> args) async {
  final url = args.isEmpty ? 'http://localhost:8099' : args.first;
  final clients = <io.Socket>[];
  final states = <io.Socket, Map>{};
  void check(bool condition, String message) {
    if (!condition) throw StateError(message);
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
    clients.add(socket);
    final ready = Completer<void>();
    socket.onConnect((_) {
      if (!ready.isCompleted) ready.complete();
    });
    socket.onConnectError((error) {
      if (!ready.isCompleted) ready.completeError('$error');
    });
    socket.on('room_updated', (dynamic state) => states[socket] = state as Map);
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

  Future<Map> wait(io.Socket socket, bool Function(Map) predicate) async {
    final end = DateTime.now().add(const Duration(seconds: 5));
    while (DateTime.now().isBefore(end)) {
      final state = states[socket];
      if (state != null && predicate(state)) return state;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    throw StateError('Expected room update did not arrive.');
  }

  try {
    final host = await connect();
    final second = await connect();
    final third = await connect();
    final created = await send(host, 'create_room', {
      'name': 'KIKIK host',
      'mode': 'kikik',
    });
    check(
      created['ok'] == true && created['room']['mode'] == 'kikik',
      'The server needs the KIKIK backend update.',
    );
    final code = created['room']['code'];
    final joined = await send(second, 'join_room', {
      'name': 'KIKIK second',
      'code': code,
    });
    check(joined['ok'] == true, 'Second could not join');
    check(
      (await send(third, 'join_room', {
            'name': 'KIKIK third',
            'code': code,
          }))['ok'] ==
          true,
      'Third could not join',
    );
    final started = await send(host, 'start_game', {});
    check(started['ok'] == true, 'Could not start');
    check(
      started['room']['settings']['dealRule'] == 'all_dealt',
      'The API needs the all-cards-dealt KIKIK rule update.',
    );
    final all = [
      started['room'] as Map,
      await wait(second, (s) => s['status'] == 'PASSING'),
      await wait(third, (s) => s['status'] == 'PASSING'),
    ];
    final dealt = [for (final state in all) ...state['hand'] as List];
    check(
      dealt.length == 12 && dealt.map((c) => c['id']).toSet().length == 12,
      'Three players must receive exactly 12 unique cards.',
    );
    final ranks = dealt.map((c) => c['rank'] as String).toSet().toList()
      ..sort();
    check(
      ranks.join(',') == 'J,K,Q',
      'Three players must use Kings, Queens, and Jacks only.',
    );
    for (var i = 0; i < all.length; i++) {
      final own = all[i];
      check((own['hand'] as List).length == 4, 'Wrong hand size');
      for (var j = 0; j < all.length; j++) {
        if (i == j) continue;
        for (final card in all[j]['hand'] as List) {
          check(
            !jsonEncode(own).contains(card['id'] as String),
            'Another hand leaked',
          );
        }
      }
    }
    final turn = started['room']['turnId'];
    final passed = await Future.wait([
      for (var i = 0; i < 3; i++)
        send([host, second, third][i], 'select_pass_card', {
          'turnId': turn,
          'cardId': all[i]['hand'][0]['id'],
        }),
    ]);
    check(passed.every((r) => r['ok'] == true), 'A pass failed');
    final next = await wait(second, (s) => s['turnNumber'] == 2);
    second.disconnect();
    await wait(
      host,
      (s) => (s['players'] as List).any(
        (p) => p['id'] == joined['playerId'] && p['connected'] == false,
      ),
    );
    final replacement = await connect();
    final resumed = await send(replacement, 'resume_room', joined['resume']);
    check(
      resumed['ok'] == true && resumed['playerId'] == joined['playerId'],
      'Seat restore failed',
    );
    check(
      jsonEncode(resumed['room']['hand']) == jsonEncode(next['hand']),
      'Hand changed on reconnect',
    );
    stdout.writeln(
      'PASS: three Dart clients, private hands, simultaneous pass, stable seat identity, and private-hand reconnect.',
    );
  } finally {
    for (final socket in clients) {
      if (socket.connected) {
        try {
          await send(socket, 'leave_room', null);
        } catch (_) {
          /* Test cleanup only. */
        }
      }
      socket.dispose();
    }
  }
}
