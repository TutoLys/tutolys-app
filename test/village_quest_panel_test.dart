import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/features/home/subject_progress.dart';
import 'package:tutolys_app/features/home/village_screen.dart';
import 'package:tutolys_app/features/pairing/pairing_controller.dart';
import 'package:tutolys_app/features/quests/quest_board.dart';

const _quests = [
  DailyQuestItem(
    kind: QuestKind.challenge,
    target: 3,
    progress: 3,
    done: true,
    xpReward: 15,
  ),
  DailyQuestItem(
    kind: QuestKind.exercises,
    target: 5,
    progress: 2,
    done: false,
    xpReward: 15,
  ),
  DailyQuestItem(
    kind: QuestKind.minutes,
    target: 10,
    progress: 0,
    done: false,
    xpReward: 20,
  ),
];

Widget harness({VoidCallback? onOpenPath, VoidCallback? onOpenQuests}) =>
    ProviderScope(
      overrides: [
        localDatabaseProvider.overrideWithValue(LocalDatabase.memory()),
        questBoardProvider.overrideWith(
          (ref) async => QuestBoard(
            quests: _quests,
            weekCompleted: 0,
            unlocked: const {},
            today: DateTime(2026, 10, 25),
          ),
        ),
        subjectProgressProvider.overrideWith((ref) async => const {}),
      ],
      child: MaterialApp(
        theme: TutolysTheme.village(),
        locale: const Locale('fr', 'CA'),
        supportedLocales: const [Locale('fr', 'CA'), Locale('en', 'CA')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: MediaQuery(
          // A phone: the panel sits under the subject strip, no scene.
          data: const MediaQueryData(
            size: Size(390, 1400),
            disableAnimations: true,
          ),
          child: Scaffold(
            body: VillageScreen(
              onOpenPath: onOpenPath,
              onOpenQuests: onOpenQuests,
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('each quest shows its fraction, its bar and its XP', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('2/5'), findsOneWidget);
    expect(find.text('0/10'), findsOneWidget);
    expect(find.text('+20 XP'), findsOneWidget);
    expect(find.byKey(const ValueKey('quest-status-done')), findsOneWidget);
    expect(find.byKey(const ValueKey('quest-status-go')), findsNWidgets(2));
  });

  testWidgets('an open quest leads to the Carte; a done one goes nowhere', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var opened = 0;
    await tester.pumpWidget(harness(onOpenPath: () => opened++));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('village-quest-exercises')));
    expect(opened, 1);
    await tester.tap(find.byKey(const ValueKey('village-quest-challenge')));
    expect(opened, 1, reason: 'nothing left to play on a finished quest');
  });

  testWidgets('"Voir toutes" opens Quêtes', (tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var opened = 0;
    await tester.pumpWidget(harness(onOpenQuests: () => opened++));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('village-quests-see-all')));
    expect(opened, 1);
  });
}
