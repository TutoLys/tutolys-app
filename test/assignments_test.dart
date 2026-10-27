import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/data/api/assignments_api.dart';
import 'package:tutolys_app/features/quests/quests_screen.dart';

/// O7 on the kid's side (backend ADR 0123): the work a teacher gave, and
/// nothing about anyone else.
void main() {
  AssignmentDto dto({bool done = false, String? due}) =>
      AssignmentDto.fromJson({
        'id': 'a1',
        'title': 'Les mesures',
        'from_name': 'École des Érables',
        'skill_node_id': 'skill-1',
        'exercise_id': null,
        'due_on': due,
        'done': done,
      });

  test('reads the backend shape', () {
    final a = dto(due: '2026-11-03');
    expect(a.title, 'Les mesures');
    expect(a.fromName, 'École des Érables');
    expect(a.skillNodeId, 'skill-1');
    expect(a.dueOn, DateTime(2026, 11, 3));
    expect(a.done, isFalse);
  });

  Widget host(Widget child, {Locale locale = const Locale('fr', 'CA')}) =>
      MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('fr', 'CA'), Locale('en', 'CA')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: TutolysTheme.learner(),
        home: Scaffold(body: child),
      );

  testWidgets('the Quêtes card lists the kid\'s own work', (tester) async {
    await tester.pumpWidget(
      host(
        HomeworkCard(
          work: [
            dto(due: '2026-11-03'),
            dto(done: true),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('De ton enseignant·e'), findsOneWidget);
    expect(find.text('Les mesures'), findsNWidgets(2));
    expect(find.textContaining('De École des Érables'), findsNWidgets(2));
    expect(find.textContaining('Pour le 3/11'), findsOneWidget);
    expect(find.text('Fait !'), findsOneWidget);
  });

  testWidgets('and says it in English too', (tester) async {
    await tester.pumpWidget(
      host(HomeworkCard(work: [dto()]), locale: const Locale('en', 'CA')),
    );
    await tester.pumpAndSettle();
    expect(find.text('From your teacher'), findsOneWidget);
  });
}
