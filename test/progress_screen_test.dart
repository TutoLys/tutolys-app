import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:design_system/design_system.dart';
import 'package:tutolys_app/data/api/progress_api.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/features/progress/progress_controller.dart';
import 'package:tutolys_app/features/progress/progress_screen.dart';

class _FixedProgress extends ProgressController {
  _FixedProgress(this._state);
  final ProgressState _state;

  @override
  ProgressState build() => _state;

  @override
  Future<void> refresh() async {}
}

CachedSkillNode leaf(String id, String subject, String key) => CachedSkillNode(
  id: id,
  labelFr: id,
  labelEn: '',
  stableKey: key,
  subject: subject,
  grade: 1,
);

Widget screen({
  required ProgressState progress,
  Map<String, List<CachedSkillNode>> leaves = const {},
}) => ProviderScope(
  overrides: [
    progressControllerProvider.overrideWith(() => _FixedProgress(progress)),
    progressLeavesProvider.overrideWith(
      (ref, subject) async => leaves[subject] ?? const [],
    ),
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
    home: const Scaffold(body: ProgressScreen()),
  ),
);

void main() {
  testWidgets('the headline stats are the real ones, level included', (
    tester,
  ) async {
    await tester.pumpWidget(
      screen(
        progress: const ProgressState(
          loading: false,
          currentStreakDays: 4,
          totalXp: 340,
          level: 14,
          masteredCount: 1,
          masteries: [
            SkillMasteryDto(skillNodeId: 'a', masteryPct: 90, isMastered: true),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Niv. 14'), findsOneWidget);
    expect(find.text('340 points XP'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('an unknown streak is a dash, never a made-up zero', (
    tester,
  ) async {
    await tester.pumpWidget(
      screen(progress: const ProgressState(loading: false)),
    );
    await tester.pumpAndSettle();

    expect(find.text('–'), findsOneWidget);
  });

  testWidgets('one row per learning area, each with its status', (
    tester,
  ) async {
    await tester.pumpWidget(
      screen(
        progress: const ProgressState(
          loading: false,
          masteries: [
            SkillMasteryDto(skillNodeId: 'm', masteryPct: 50, isMastered: false),
            SkillMasteryDto(skillNodeId: 'g', masteryPct: 90, isMastered: true),
          ],
        ),
        leaves: {
          'MATH': [
            leaf('m', 'MATH', 'mathematique/mesure/b:A/o:1'),
            leaf('g', 'MATH', 'mathematique/geometrie/b:A/o:1'),
            leaf('p', 'MATH', 'mathematique/probabilite/b:A/o:1'),
          ],
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mathématiques — par compétence'), findsOneWidget);
    expect(find.text('Géométrie'), findsOneWidget);
    expect(find.text('MAÎTRISÉ'), findsOneWidget);
    expect(find.text('EN COURS'), findsOneWidget);
    expect(find.text('À DÉCOUVRIR'), findsOneWidget);
    expect(find.text('50 %'), findsOneWidget);
  });

  testWidgets('a subject pill switches the card to that subject', (
    tester,
  ) async {
    await tester.pumpWidget(
      screen(
        progress: const ProgressState(loading: false),
        leaves: {
          'SCI': [leaf('s', 'SCI', 'science-technologie/l-univers-vivant/o:1')],
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text("Rien à montrer pour cette matière pour l'instant."),
      findsOneWidget,
      reason: 'math has nothing cached in this test',
    );

    await tester.tap(find.byKey(const ValueKey('subject-pill-SCI')));
    await tester.pumpAndSettle();

    expect(find.text('Science et techno. — par compétence'), findsOneWidget);
    expect(find.text('L’univers vivant'), findsOneWidget);
  });
}
