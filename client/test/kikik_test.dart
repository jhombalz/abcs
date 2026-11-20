import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:buzz_club/kikik_panel.dart';
import 'package:buzz_club/lobby_settings.dart';
import 'package:buzz_club/game_picker.dart';
import 'package:buzz_club/kikik_table.dart';

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
  'settings': {'dealRule': 'all_dealt'},
};

void main() {
  testWidgets(
    'a pass animates card backs and replaces only the outgoing slot',
    (tester) async {
      final room = cardRoom()..['matchId'] = 'match1';
      Map<String, dynamic>? payload;
      Future<void> show() => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: KikikPanel(
                room: room,
                playerId: 'a',
                busy: false,
                onAction: (_, data) => payload = data,
              ),
            ),
          ),
        ),
      );
      await show();
      await tester.pump();
      final hiddenBefore = find.byType(HiddenCard).evaluate().length;
      final hand = List<Map>.from(room['hand'] as List);
      room['hand'] = [
        hand[0],
        hand[2],
        hand[3],
        {'id': '7-spades', 'rank': '7', 'suit': 'spades'},
      ];
      room['turnId'] = 'turn2';
      room['turnNumber'] = 2;
      await show();
      await tester.pump(const Duration(milliseconds: 300));
      expect(hiddenBefore, 12);
      expect(find.text('All cards dealt'), findsOneWidget);
      expect(find.byType(HiddenCard).evaluate().length, hiddenBefore + 3);
      expect(find.byType(PlayingCard), findsNWidgets(4));
      final cards = tester
          .widgetList<PlayingCard>(
            find.descendant(
              of: find.byKey(const ValueKey('own-hand')),
              matching: find.byType(PlayingCard),
            ),
          )
          .toList();
      expect(cards.map((c) => c.card['id']), [
        'A-spades',
        '7-spades',
        'A-diamonds',
        'A-clubs',
      ]);
      expect(cards[1].received, true);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(payload?['cardId'], '7-spades');
      await tester.pumpAndSettle();
      expect(find.byType(HiddenCard).evaluate().length, hiddenBefore);
      expect(
        tester
            .widgetList<PlayingCard>(find.byType(PlayingCard))
            .any((c) => c.received),
        false,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'circular seats fit 3-12 players on narrow screens and respect reduced motion',
    (tester) async {
      tester.view.physicalSize = const Size(360, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final room = cardRoom();
      Future<void> show() => tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 1000),
              textScaler: TextScaler.linear(1.4),
              disableAnimations: true,
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 44),
                child: KikikPanel(
                  room: room,
                  playerId: 'a',
                  busy: false,
                  onAction: (_, _) {},
                ),
              ),
            ),
          ),
        ),
      );
      for (final count in [3, 6, 8, 12]) {
        room['players'] = [
          for (var i = 0; i < count; i++)
            {
              'id': i == 0 ? 'a' : 'p$i',
              'name': 'Player $i long name',
              'connected': true,
              'locked': true,
            },
        ];
        await show();
        await tester.pump();
        final bounds = tester.getRect(find.byType(KikikTable));
        final seats = [
          for (final player in room['players'] as List)
            tester.getRect(find.byKey(ValueKey('kikik-seat-${player['id']}'))),
        ];
        for (var i = 0; i < seats.length; i++) {
          expect(bounds.inflate(1).contains(seats[i].topLeft), true);
          expect(bounds.inflate(1).contains(seats[i].bottomRight), true);
          for (var j = i + 1; j < seats.length; j++) {
            final overlap = seats[i].intersect(seats[j]);
            expect(
              overlap.width > 1 && overlap.height > 1,
              false,
              reason: '$count players: seats $i/$j overlap',
            );
          }
        }
        expect(tester.takeException(), isNull);
      }
      final hiddenBefore = find.byType(HiddenCard).evaluate().length;
      room['turnId'] = 'turn2';
      room['turnNumber'] = 2;
      await show();
      await tester.pump();
      expect(find.byType(HiddenCard).evaluate().length, hiddenBefore);
    },
  );
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
      room['settings'] = {};
      await show();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Start KIKIK'),
            )
            .onPressed,
        isNull,
      );
      expect(
        find.text(
          'The API needs the latest KIKIK rule update before starting.',
        ),
        findsOneWidget,
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
      final winningHand = [
        for (final suit in ['spades', 'hearts', 'diamonds', 'clubs'])
          {'id': '7-$suit', 'rank': '7', 'suit': suit},
      ];
      room['winner'] = {'id': 'a', 'name': 'Alex', 'hand': winningHand};
      final ownBefore = tester
          .widgetList<PlayingCard>(
            find.descendant(
              of: find.byKey(const ValueKey('own-hand')),
              matching: find.byType(PlayingCard),
            ),
          )
          .map((c) => c.card['id'])
          .toList();
      final beforeRect = tester.getRect(find.byKey(const ValueKey('own-hand')));
      await show();
      expect(find.text('Alex called KIKIK!'), findsOneWidget);
      expect(find.text('Play again'), findsNothing);
      expect(find.byType(PlayingCard), findsNWidgets(8));
      final ownAfter = tester
          .widgetList<PlayingCard>(
            find.descendant(
              of: find.byKey(const ValueKey('own-hand')),
              matching: find.byType(PlayingCard),
            ),
          )
          .map((c) => c.card['id'])
          .toList();
      expect(ownAfter, ownBefore);
      expect(
        tester.getRect(find.byKey(const ValueKey('own-hand'))),
        beforeRect,
      );
      expect(
        tester
            .widgetList<PlayingCard>(
              find.descendant(
                of: find.byKey(const ValueKey('winning-hand')),
                matching: find.byType(PlayingCard),
              ),
            )
            .map((c) => c.card['rank']),
        everyElement('7'),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
