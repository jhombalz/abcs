import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:buzz_club/butbutay_panel.dart';
import 'package:buzz_club/game_picker.dart';
import 'package:buzz_club/lobby_settings.dart';
import 'package:buzz_club/kikik_panel.dart' show PlayingCard;

Map<String, dynamic> bluffRoom() => {
  'mode': 'butbutay',
  'code': '123456',
  'hostId': 'a',
  'viewerId': 'a',
  'status': 'DROPPING',
  'currentPlayerId': 'a',
  'turnId': 't1',
  'secondsLeft': 30,
  'settings': {'rules': 'last_drop_only'},
  'players': [
    {'id': 'a', 'name': 'Alex', 'connected': true, 'cardCount': 18},
    {'id': 'b', 'name': 'Blair', 'connected': true, 'cardCount': 17},
    {'id': 'c', 'name': 'Casey', 'connected': true, 'cardCount': 17},
  ],
  'hand': [
    for (final suit in ['spades', 'hearts', 'diamonds', 'clubs'])
      {'id': 'A-$suit', 'rank': 'A', 'suit': suit},
    {'id': 'K-spades', 'rank': 'K', 'suit': 'spades'},
  ],
  'discardCount': 0,
  'currentDrop': null,
  'history': [],
  'result': null,
  'winner': null,
};

void main() {
  testWidgets('Butbutay mode and lobby require three connected players', (
    tester,
  ) async {
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
    await tester.tap(find.text('Butbutay · 3–6 players'));
    expect(mode, 'butbutay');
    final room = bluffRoom()..['status'] = 'WAITING';
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
            find.widgetWithText(FilledButton, 'Start Butbutay'),
          )
          .onPressed,
      isNotNull,
    );
    (room['players'] as List).removeLast();
    await show();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Start Butbutay'),
          )
          .onPressed,
      isNull,
    );
  });
  testWidgets(
    'select at most four cards and submit the exact declared count and rank',
    (tester) async {
      final room = bluffRoom();
      String? event;
      Map<String, dynamic>? payload;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ButbutayPanel(
                room: room,
                playerId: 'a',
                busy: false,
                onAction: (name, data) {
                  event = name;
                  payload = data;
                },
              ),
            ),
          ),
        ),
      );
      await tester.ensureVisible(find.byType(GridView));
      await tester.pump();
      for (final id in ['A-spades', 'A-hearts', 'A-diamonds', 'A-clubs']) {
        final card = find.byKey(ValueKey(id));
        await tester.ensureVisible(card);
        await tester.tap(card);
        await tester.pump();
      }
      expect(
        tester
            .widget<PlayingCard>(find.byKey(const ValueKey('K-spades')))
            .enabled,
        false,
      );
      final button = find.widgetWithText(FilledButton, 'Drop 4 as K');
      await tester.ensureVisible(button);
      await tester.tap(button);
      expect(event, 'drop_cards');
      expect(payload?['quantity'], 4);
      expect(payload?['rank'], 'K');
      expect(payload?['turnId'], 't1');
      expect((payload?['cardIds'] as List).toSet().length, 4);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'opponents challenge by L; paused matches disable LIE and pending faces stay hidden',
    (tester) async {
      final room = bluffRoom()
        ..['status'] = 'CHALLENGE'
        ..['currentDrop'] = {
          'id': 'd1',
          'playerId': 'a',
          'quantity': 4,
          'rank': 'K',
        };
      String? command;
      Map<String, dynamic>? payload;
      Future<void> show() => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ButbutayPanel(
                room: room,
                playerId: 'b',
                busy: false,
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
      expect(
        tester
            .widgetList<PlayingCard>(find.byType(PlayingCard))
            .any((c) => c.label == 'Challenged card'),
        false,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
      expect(command, 'call_lie');
      expect(payload?['dropId'], 'd1');
      command = null;
      room['status'] = 'PAUSED';
      room['pausedPhase'] = 'CHALLENGE';
      await show();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'CALL LIE'))
            .onPressed,
        isNull,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
      expect(command, isNull);
      expect(find.textContaining('Match paused.'), findsOneWidget);
      room['status'] = 'CHALLENGE_RESULT';
      room['currentDrop'] = null;
      room['result'] = {
        'kind': 'challenged',
        'truthful': false,
        'dropperId': 'a',
        'challengerId': 'b',
        'nextPlayerId': 'b',
        'quantity': 1,
        'cards': [
          {'id': '7-spades', 'rank': '7', 'suit': 'spades'},
        ],
      };
      await show();
      expect(
        tester
            .widgetList<PlayingCard>(find.byType(PlayingCard))
            .where((c) => c.label == 'Challenged card')
            .length,
        1,
      );
      expect(find.textContaining('LIE — Alex picks up'), findsOneWidget);
    },
  );
  testWidgets('empty hand does not win until final challenge resolves', (
    tester,
  ) async {
    final room = bluffRoom()
      ..['status'] = 'CHALLENGE'
      ..['hand'] = []
      ..['currentDrop'] = {
        'id': 'd1',
        'playerId': 'a',
        'quantity': 1,
        'rank': 'A',
      };
    Future<void> show(String player) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ButbutayPanel(
              room: room,
              playerId: player,
              busy: false,
              onAction: (_, _) {},
            ),
          ),
        ),
      ),
    );
    await show('a');
    expect(find.text('Play again'), findsNothing);
    expect(find.textContaining('final drop must survive'), findsOneWidget);
    room['status'] = 'GAME_FINISHED';
    room['currentDrop'] = null;
    room['winner'] = {'id': 'a', 'name': 'Alex'};
    await show('a');
    expect(find.text('Alex wins Butbutay!'), findsOneWidget);
    expect(find.text('Play again'), findsOneWidget);
    await show('b');
    expect(find.text('Play again'), findsNothing);
  });
  testWidgets(
    'large hands scroll inside a bounded phone layout with large text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final room = bluffRoom()
        ..['hand'] = [
          for (final rank in butbutayRanks)
            for (final suit in ['spades', 'hearts', 'diamonds', 'clubs'])
              {'id': '$rank-$suit', 'rank': rank, 'suit': suit},
        ];
      await tester.pumpWidget(
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
                child: ButbutayPanel(
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
      expect(
        tester.getSize(find.byType(GridView)).height,
        lessThanOrEqualTo(290),
      );
      expect(
        tester
            .widget<GridView>(find.byType(GridView))
            .childrenDelegate
            .estimatedChildCount,
        52,
      );
      await tester.ensureVisible(find.byType(GridView));
      await tester.drag(find.byType(GridView), const Offset(0, -400));
      await tester.pumpAndSettle();
      final scroll = tester.state<ScrollableState>(
        find.descendant(
          of: find.byType(GridView),
          matching: find.byType(Scrollable),
        ),
      );
      expect(scroll.position.pixels, greaterThan(0));
      expect(tester.takeException(), isNull);
    },
  );
}
