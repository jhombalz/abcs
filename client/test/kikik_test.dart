import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:buzz_club/kikik_panel.dart';
import 'package:buzz_club/lobby_settings.dart';
import 'package:buzz_club/game_picker.dart';

Map<String, dynamic> cardRoom() => {
  'mode': 'kikik',
  'code': '123456',
  'status': 'PASSING',
  'hostId': 'a',
  'viewerId': 'a',
  'players': [
    {'id': 'a', 'name': 'Alex', 'connected': true, 'locked': false},
    {'id': 'b', 'name': 'Blair', 'connected': true, 'locked': false},
    {'id': 'c', 'name': 'Casey', 'connected': true, 'locked': false},
  ],
  'hand': [
    for (final suit in ['spades', 'hearts', 'diamonds', 'clubs'])
      {'id': 'A-$suit', 'rank': 'A', 'suit': suit},
  ],
  'canClaim': false,
  'turnId': 'turn1',
  'turnNumber': 1,
  'secondsLeft': 12,
  'winner': null,
};

void main() {
  testWidgets(
    'pick a mode and require at least three connected players for KIKIK',
    (tester) async {
      String? mode;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GamePicker(
              value: 'quiz',
              enabled: true,
              onChanged: (value) => mode = value,
            ),
          ),
        ),
      );
      await tester.tap(find.text('KIKIK · 3–12 players'));
      expect(mode, 'kikik');
      final room = cardRoom()..['status'] = 'WAITING';
      (room['players'] as List).removeLast();
      Future<void> show() => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LobbySettings(
                room: room,
                isHost: true,
                busy: false,
                onAction: (_, _) {},
              ),
            ),
          ),
        ),
      );
      await show();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Start KIKIK'),
            )
            .onPressed,
        isNull,
      );
      expect(find.text('Invite 1 more player(s) to start.'), findsOneWidget);
      (room['players'] as List).add({
        'id': 'c',
        'name': 'Casey',
        'connected': true,
        'locked': false,
      });
      await show();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Start KIKIK'),
            )
            .onPressed,
        isNotNull,
      );
    },
  );
  testWidgets(
    'card selection locks a private card with turn ID and stale selection clears',
    (tester) async {
      final room = cardRoom();
      String? command;
      Map<String, dynamic>? payload;
      Future<void> show({bool busy = false}) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: KikikPanel(
                room: room,
                playerId: 'a',
                busy: busy,
                onAction: (event, data) {
                  command = event;
                  payload = data;
                },
              ),
            ),
          ),
        ),
      );
      await show();
      await tester.pump();
      expect(find.byType(PlayingCard), findsNWidgets(4));
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'KIKIK!'))
            .onPressed,
        isNull,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await tester.pump();
      expect(
        tester.widget<PlayingCard>(find.byType(PlayingCard).at(1)).selected,
        true,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(command, 'select_pass_card');
      expect(payload, {'turnId': 'turn1', 'cardId': 'A-hearts'});
      (room['players'] as List)[0]['locked'] = true;
      await show();
      expect(find.text('Card locked'), findsOneWidget);
      room['turnId'] = 'turn2';
      (room['players'] as List)[0]['locked'] = false;
      await show();
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Lock card to pass'),
            )
            .onPressed,
        isNull,
      );
      room['canClaim'] = true;
      await show();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      expect(command, 'claim_kikik');
      expect(payload?['turnId'], 'turn2');
      command = null;
      await show(busy: true);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      expect(command, isNull);
    },
  );
  testWidgets(
    'winner is visible, guests cannot rematch, phone cards fit with large text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final room = cardRoom();
      Future<void> show() => tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 900),
              textScaler: TextScaler.linear(1.4),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: KikikPanel(
                  room: room,
                  playerId: 'b',
                  busy: false,
                  onAction: (_, _) {},
                ),
              ),
            ),
          ),
        ),
      );
      await show();
      expect(tester.takeException(), isNull);
      room['status'] = 'GAME_FINISHED';
      room['winner'] = {'id': 'a', 'name': 'Alex', 'hand': room['hand']};
      await show();
      expect(find.text('Alex called KIKIK!'), findsOneWidget);
      expect(find.text('Play again'), findsNothing);
      expect(find.byType(PlayingCard), findsNWidgets(4));
      expect(tester.takeException(), isNull);
    },
  );
}
