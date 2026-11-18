import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:buzz_club/game_panel.dart';
import 'package:buzz_club/lobby_settings.dart';

Map<String, dynamic> gameRoom() => {
  'code': '123456',
  'hostId': 'a',
  'status': 'QUESTION_ACTIVE',
  'players': [
    {'id': 'a', 'name': 'Alex', 'score': 100},
    {'id': 'b', 'name': 'Blair', 'score': 100},
  ],
  'question': {
    'id': 'q1',
    'question': 'Choose the next number in the sequence.',
    'choices': ['Two', 'Four', 'Six', 'Eight'],
    'category': 'Mathematics',
  },
  'round': 1,
  'totalRounds': 10,
  'secondsLeft': 15,
  'eligible': ['a', 'b'],
  'answeringId': null,
  'settings': {'category': 'Mixed'},
};

void main() {
  testWidgets(
    'secondary match details start collapsed and survive timer updates',
    (tester) async {
      final room = gameRoom();
      String? command;
      Future<void> show() => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GamePanel(
                room: room,
                playerId: 'a',
                busy: false,
                onAction: (event, _) => command = event,
              ),
            ),
          ),
        ),
      );
      await show();
      await tester.pumpAndSettle();
      expect(find.text('LIVE STANDINGS'), findsNothing);
      expect(find.text('Room 123456'), findsNothing);
      expect(find.text('Leave room'), findsNothing);
      expect(
        find.text('Choose the next number in the sequence.'),
        findsOneWidget,
      );
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      await tester.ensureVisible(find.text('Standings'));
      await tester.tap(find.text('Standings'));
      await tester.pumpAndSettle();
      expect(find.text('LIVE STANDINGS'), findsOneWidget);
      room['secondsLeft'] = 14;
      await show();
      await tester.pumpAndSettle();
      expect(find.text('LIVE STANDINGS'), findsOneWidget);
      await tester.tap(find.text('Standings'));
      await tester.pumpAndSettle();
      expect(find.text('LIVE STANDINGS'), findsNothing);
      await tester.ensureVisible(find.text('Room & controls'));
      await tester.tap(find.text('Room & controls'));
      await tester.pumpAndSettle();
      expect(find.text('Room 123456'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(command, isNull);
      await tester.ensureVisible(find.text('Leave room'));
      await tester.tap(find.text('Leave room'));
      expect(command, 'leave_room');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'host chooses a subject; guest sees synced selection with controls disabled',
    (tester) async {
      final room = gameRoom()..['status'] = 'WAITING';
      String? command;
      Map<String, dynamic>? payload;
      Future<void> show(bool host) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LobbySettings(
                room: room,
                isHost: host,
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
      await show(true);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('English').last);
      await tester.pumpAndSettle();
      expect(command, 'configure_game');
      expect(payload?['category'], 'English');
      room['settings'] = {'category': 'Mathematics'};
      await show(false);
      final dropdown = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>),
      );
      expect(dropdown.onChanged, isNull);
      expect(find.text('Mathematics'), findsOneWidget);
      expect(find.text('Start game'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Space buzzes, number selects a choice, and busy locks shortcuts',
    (tester) async {
      final room = gameRoom();
      final commands = <String>[];
      Map<String, dynamic>? payload;
      Future<void> show({bool busy = false}) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GamePanel(
                room: room,
                playerId: 'a',
                busy: busy,
                onAction: (event, data) {
                  commands.add(event);
                  payload = data;
                },
              ),
            ),
          ),
        ),
      );
      await show();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(commands, ['buzz']);
      room['status'] = 'ANSWERING';
      room['answeringId'] = 'a';
      await show();
      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      expect(commands.last, 'submit_answer');
      expect(payload?['answer'], 'Four');
      await show(busy: true);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      expect(commands.length, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'results include tied winners, host rematch and back-to-lobby actions',
    (tester) async {
      final room = gameRoom()..['status'] = 'GAME_FINISHED';
      String? command;
      Future<void> show(String player) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GamePanel(
                room: room,
                playerId: player,
                busy: false,
                onAction: (event, data) => command = event,
              ),
            ),
          ),
        ),
      );
      await show('a');
      expect(find.text('Joint winners: Alex, Blair'), findsOneWidget);
      expect(find.text('1'), findsNWidgets(2));
      await tester.ensureVisible(find.text('Back to lobby'));
      await tester.tap(find.text('Back to lobby'));
      expect(command, 'return_to_lobby');
      await tester.tap(find.text('Play again'));
      expect(command, 'start_game');
      await show('b');
      expect(find.text('Back to lobby'), findsNothing);
      expect(find.text('Play again'), findsNothing);
    },
  );

  testWidgets(
    'phone game screen and lobby support large text without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Future<void> show(Widget child) => tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 900),
              textScaler: TextScaler.linear(1.4),
              disableAnimations: true,
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: child,
              ),
            ),
          ),
        ),
      );
      await show(
        GamePanel(
          room: gameRoom(),
          playerId: 'a',
          busy: false,
          onAction: (_, _) {},
        ),
      );
      expect(tester.takeException(), isNull);
      await show(
        LobbySettings(
          room: gameRoom(),
          isHost: true,
          busy: false,
          onAction: (_, _) {},
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
