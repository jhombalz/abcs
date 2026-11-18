import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:buzz_club/main.dart';

void main() {
  testWidgets('Lobby stays usable on a narrow phone while offline', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const BuzzClubApp(connectToServer: false));
    expect(find.text('What should we call you?'), findsOneWidget);
    expect(find.text('Create a room'), findsNothing);
    expect(find.text('Join room'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'OK'))
          .onPressed,
      isNull,
    );
    await tester.enterText(find.byType(TextField), '   ');
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'OK'))
          .onPressed,
      isNull,
    );
    await tester.enterText(find.byType(TextField), '  TATA  ');
    await tester.pump();
    await tester.ensureVisible(find.text('OK'));
    await tester.tap(find.text('OK'));
    await tester.pump();
    expect(find.text('Playing as TATA'), findsOneWidget);
    expect(find.text('Join room'), findsOneWidget);
    expect(find.text('Make room for fun.'), findsOneWidget);
    final create = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Create a room'),
    );
    expect(create.onPressed, isNull);
    await tester.ensureVisible(find.text('Change name'));
    await tester.tap(find.text('Change name'));
    await tester.pump();
    expect(find.text('Join room'), findsNothing);
    expect(find.text('What should we call you?'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
