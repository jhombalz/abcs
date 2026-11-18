import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:buzz_club/game_panel.dart';

void main() {
  testWidgets('eligible players buzz before choosing an answer', (
    tester,
  ) async {
    final room = <String, dynamic>{
      'status': 'QUESTION_ACTIVE',
      'hostId': 'a',
      'players': [
        {'id': 'a', 'name': 'Solo', 'score': 0},
      ],
      'question': {
        'id': 'q1',
        'question': 'Pick one',
        'choices': ['A', 'B', 'C', 'D'],
        'category': 'Logic',
      },
      'round': 1,
      'totalRounds': 10,
      'secondsLeft': 15,
      'eligible': ['a'],
      'answeringId': null,
    };
    String? command;
    Map<String, dynamic>? payload;
    Future<void> show() => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: GamePanel(
              room: room,
              playerId: 'a',
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
    expect(find.textContaining('Question 1 / 10'), findsOneWidget);
    expect(find.textContaining('15s'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'A'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('BUZZ!'));
    expect(command, 'buzz');
    expect(payload?['questionId'], 'q1');
    room['status'] = 'ANSWERING';
    room['answeringId'] = 'a';
    await show();
    await tester.tap(find.text('B'));
    expect(command, 'submit_answer');
    expect(payload?['answer'], 'B');
    room['status'] = 'QUESTION_FINISHED';
    room['result'] = {'reason': 'Question time expired', 'correctAnswer': 'A'};
    await show();
    expect(find.textContaining('Correct answer:'), findsNothing);
    expect(
      tester.widget<Text>(find.text('A')).style,
      tester.widget<Text>(find.text('C')).style,
    );
    expect(find.text('Question time expired'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
