import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/core/i18n/strings.dart';
import 'package:tutolys_app/features/progress/progress_controller.dart';
import 'package:tutolys_app/features/progress/progress_screen.dart';
import 'package:tutolys_app/features/quests/quests_screen.dart';

class _Progress extends ProgressController {
  @override
  ProgressState build() => const ProgressState(loading: false);

  @override
  Future<void> refresh() async {}
}

Widget _app(Widget child, {List overrides = const []}) => ProviderScope(
  overrides: [...overrides],
  child: MaterialApp(
    theme: TutolysTheme.village(),
    locale: const Locale('fr', 'CA'),
    supportedLocales: const [Locale('fr', 'CA'), Locale('en', 'CA')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: child),
  ),
);

/// UX review A3 and A4: loading, error and empty are three states.
void main() {
  final fr = Strings.fr;

  group('A3, the quest list', () {
    testWidgets('loading: grey rows, never "no quests today"', (tester) async {
      await tester.pumpWidget(_app(const QuestListCard(quests: null)));
      expect(find.byKey(const ValueKey('quests-loading')), findsOneWidget);
      expect(find.text(fr.villageNoQuests), findsNothing);
    });

    testWidgets('failed: the fox says so, with Réessayer', (tester) async {
      var retried = 0;
      await tester.pumpWidget(
        _app(
          QuestListCard(quests: null, failed: true, onRetry: () => retried++),
        ),
      );
      expect(find.text(fr.questsLoadFailed), findsOneWidget);
      expect(find.text(fr.villageNoQuests), findsNothing);
      await tester.tap(find.byKey(const ValueKey('quests-retry')));
      expect(retried, 1);
    });

    testWidgets('a real empty board keeps its own words', (tester) async {
      await tester.pumpWidget(_app(const QuestListCard(quests: [])));
      expect(find.text(fr.villageNoQuests), findsOneWidget);
    });
  });

  group('A4, Progrès', () {
    testWidgets('a failed read says so, with Réessayer, never "nothing"', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(
        _app(
          const ProgressScreen(),
          overrides: [
            progressControllerProvider.overrideWith(_Progress.new),
            progressLeavesProvider.overrideWith((ref, subject) async {
              calls++;
              throw StateError('offline');
            }),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('progress-failed')), findsOneWidget);
      expect(find.text(fr.progressLoadFailed), findsOneWidget);
      final before = calls;
      await tester.tap(find.byKey(const ValueKey('progress-retry')));
      await tester.pumpAndSettle();
      expect(calls, before + 1);
    });

    testWidgets('truly empty: a next step into the Carte on that subject', (
      tester,
    ) async {
      String? opened;
      await tester.pumpWidget(
        _app(
          ProgressScreen(onOpenSubject: (s) => opened = s),
          overrides: [
            progressControllerProvider.overrideWith(_Progress.new),
            progressLeavesProvider.overrideWith((ref, subject) async => []),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('progress-empty')), findsOneWidget);
      expect(
        find.text(fr.progressPlayToSee('Mathématiques')),
        findsOneWidget,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('progress-open-carte')),
      );
      await tester.tap(find.byKey(const ValueKey('progress-open-carte')));
      expect(opened, 'MATH');
    });
  });
}
