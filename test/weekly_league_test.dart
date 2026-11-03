import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/core/i18n/strings.dart';
import 'package:tutolys_app/data/api/notifications_api.dart';
import 'package:tutolys_app/data/api/progress_api.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/features/notifications/local_facts.dart';
import 'package:tutolys_app/features/notifications/notifications_controller.dart';
import 'package:tutolys_app/features/notifications/notifications_panel.dart';
import 'package:tutolys_app/features/progress/league_promoted.dart';
import 'package:tutolys_app/features/progress/progress_cache.dart';
import 'package:tutolys_app/features/progress/weekly_league.dart';
import 'package:tutolys_app/features/progress/weekly_league_card.dart';

/// The contract's own example (backend ADR 0207).
Map<String, Object?> leagueJson({
  String division = 'silver',
  int xp = 62,
  int? promoteAt = 90,
  int? toPromote = 28,
  int? keepAt = 20,
  Map<String, Object?>? lastWeek = const {
    'week_start': '2026-10-26',
    'division': 'silver',
    'outcome': 'promoted',
    'xp': 94,
  },
  String? weekEnd = '2026-11-09T00:00:00-05:00',
  int? xpLastWeek = 94,
}) => {
  'division': division,
  'week_start': '2026-11-02',
  'week_end': ?weekEnd,
  'xp_this_week': xp,
  'xp_last_week': ?xpLastWeek,
  'promote_at_xp': promoteAt,
  'xp_to_promote': toPromote,
  'keep_at_xp': keepAt,
  'last_week': lastWeek,
};

LeagueDto league({
  String division = 'silver',
  int xp = 62,
  int? promoteAt = 90,
  int? toPromote = 28,
  Map<String, Object?>? lastWeek = const {
    'week_start': '2026-10-26',
    'division': 'silver',
    'outcome': 'held',
    'xp': 94,
  },
  String? weekEnd = '2026-11-09T00:00:00-05:00',
  int? xpLastWeek = 94,
}) => LeagueDto.fromJson(
  leagueJson(
    division: division,
    xp: xp,
    promoteAt: promoteAt,
    toPromote: toPromote,
    lastWeek: lastWeek,
    weekEnd: weekEnd,
    xpLastWeek: xpLastWeek,
  ),
);

const percentile78 = EffortPercentileDto(
  percentile: 78,
  grade: 1,
  weekStart: '2026-11-02',
);

Widget app(Widget child, {Locale locale = const Locale('fr', 'CA')}) =>
    MaterialApp(
      theme: TutolysTheme.village(),
      locale: locale,
      supportedLocales: const [Locale('fr', 'CA'), Locale('en', 'CA')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

/// Wednesday 2026-11-04, noon in Québec.
final wednesday = DateTime.utc(2026, 11, 4, 17);

void main() {
  group('payload', () {
    test('parses the contract, nulls meaning "not here"', () {
      final snap = ProgressSnapshot.fromJson({
        'masteries': const [],
        'league': leagueJson(
          division: 'diamond',
          promoteAt: null,
          toPromote: null,
        ),
        'effort_percentile': null,
      });
      expect(snap.league!.division, 'diamond');
      expect(snap.league!.promoteAtXp, isNull);
      expect(snap.league!.xpToPromote, isNull);
      expect(snap.league!.lastWeek!.outcome, 'promoted');
      expect(snap.effortPercentile, isNull);
    });

    test('an older backend sends neither field', () {
      final snap = ProgressSnapshot.fromJson({'masteries': const []});
      expect(snap.league, isNull);
      expect(snap.effortPercentile, isNull);
    });

    test('round-trips through the cache shape', () {
      final snap = ProgressSnapshot.fromJson({
        'masteries': const [],
        'league': leagueJson(weekEnd: '2026-11-09T00:00:00-05:00'),
        'effort_percentile': percentile78.toJson(),
      });
      final back = ProgressSnapshot.fromJson(snap.toJson());
      expect(back.league!.xpThisWeek, 62);
      expect(back.league!.weekEnd, DateTime.utc(2026, 11, 9, 5));
      expect(back.effortPercentile!.percentile, 78);
    });

    test('a degraded read keeps the cached league, never a cached '
        'percentile', () {
      final cached = ProgressSnapshot.fromJson({
        'masteries': const [],
        'league': leagueJson(),
        'effort_percentile': percentile78.toJson(),
      });
      final merged = mergeWithCached(
        ProgressSnapshot.fromJson({'masteries': const []}),
        cached,
      );
      expect(merged.league!.division, 'silver');
      expect(merged.effortPercentile, isNull);
    });
  });

  group('effort line', () {
    test('a served percentile wins', () {
      expect(effortLine(league(), percentile78), isA<EffortPercentile>());
    });

    test('null percentile: ahead of last week only once it is', () {
      final behind = effortLine(league(xp: 62), null);
      expect(behind, isA<EffortKeepGoing>());
      final ahead = effortLine(league(xp: 120), null);
      expect(ahead, isA<EffortAheadOfLastWeek>());
      expect((ahead as EffortAheadOfLastWeek).xp, 26);
    });

    test('measured against the calendar week before, not the last week '
        'judged', () {
      // Judged weeks ago at 10 XP; last calendar week was 150.
      final l = league(
        xp: 120,
        xpLastWeek: 150,
        lastWeek: const {
          'week_start': '2026-10-05',
          'division': 'silver',
          'outcome': 'held',
          'xp': 10,
        },
      );
      expect(effortLine(l, null), isA<EffortKeepGoing>());
      expect(
        effortLine(league(xp: 120, xpLastWeek: 100), null),
        isA<EffortAheadOfLastWeek>(),
      );
    });

    test('first week, or nothing yet: a fresh start', () {
      expect(
        effortLine(league(lastWeek: null, xpLastWeek: null, xp: 15), null),
        isA<EffortKeepGoing>(),
      );
      expect(effortLine(league(xp: 0), null), isA<EffortFreshStart>());
      expect(
        effortLine(
          league(
            xp: 0,
            lastWeek: const {
              'week_start': '2026-10-26',
              'division': 'bronze',
              'outcome': 'demoted',
              'xp': 4,
            },
          ),
          null,
        ),
        isA<EffortFreshStart>(),
      );
    });

    test('the percentile says who it counts: kids who played', () {
      final line = effortLine(league(), percentile78);
      expect(
        effortText(Strings.fr, line),
        "Plus d'XP que 78 % des élèves de 1re année qui ont joué cette semaine",
      );
      expect(
        effortText(Strings.en, line),
        'More XP than 78% of Grade 1 students who played this week',
      );
    });

    test('no branch ever compares the kid downward', () {
      const lines = [
        EffortPercentile(50, 1),
        EffortAheadOfLastWeek(40),
        EffortKeepGoing(12),
        EffortFreshStart(),
      ];
      final down = RegExp(
        r'moins|en dessous|sous la|derni|pire|below|less|under|behind|worse|'
        r'bottom|lower',
        caseSensitive: false,
      );
      for (final t in [Strings.fr, Strings.en]) {
        final texts = [
          for (final l in lines) effortText(t, l),
          for (final d in LeagueDivision.values) ...[
            t.leagueName(divisionName(t, d)),
            t.leaguePromoted(divisionName(t, d)),
            t.leagueToNext(10, divisionName(t, d)),
            t.leagueGoalReached(divisionName(t, d)),
          ],
          t.leagueTop,
          t.leagueWeekXp(3),
          t.leagueDaysLeft(1),
          t.leagueDaysLeft(4),
          t.notificationLeaguePromotedGeneric,
        ];
        for (final text in texts) {
          expect(text, isNot(matches(down)), reason: text);
        }
      }
    });
  });

  group('week end', () {
    test('counts Québec days to the served week_end', () {
      expect(leagueDaysLeft(league(), now: wednesday), 5);
      // Sunday evening in Québec.
      expect(leagueDaysLeft(league(), now: DateTime.utc(2026, 11, 9, 1)), 1);
    });

    test('no week_end, no countdown', () {
      expect(leagueDaysLeft(league(weekEnd: null), now: wednesday), isNull);
    });
  });

  group('promotion', () {
    test('only a promotion is announced', () {
      for (final outcome in ['placed', 'held', 'demoted']) {
        expect(
          promotionOf(
            league(
              lastWeek: {
                'week_start': '2026-10-26',
                'division': 'gold',
                'outcome': outcome,
                'xp': 10,
              },
            ),
          ),
          isNull,
          reason: outcome,
        );
      }
      final p = promotionOf(
        league(
          lastWeek: const {
            'week_start': '2026-10-26',
            'division': 'gold',
            'outcome': 'promoted',
            'xp': 170,
          },
        ),
      )!;
      expect(p.weekStart, '2026-10-26');
      expect(p.division, LeagueDivision.gold);
    });

    test('the local fact dedupes with the backend\'s', () {
      final facts = notificationFacts(
        day: '2026-11-03',
        promotion: (weekStart: '2026-10-26', division: LeagueDivision.gold),
      );
      expect(facts.single.factKey, 'league:2026-10-26');
      expect(facts.single.type, 'league_promoted');
      // Matched on the served key, never derived from created_at: this one
      // was written just after midnight on a Monday.
      final served = NotificationDto.fromJson({
        'id': 's',
        'type': 'league_promoted',
        'message': 'Bravo ! Tu passes en Or.',
        'dedupe_key': 'league:2026-10-26',
        'created_at': '2026-11-02T05:01:00Z',
        'is_read': false,
      });
      expect(serverFactKeys(served), {'league:2026-10-26'});
      // Without the key there is nothing to guess from.
      final keyless = NotificationDto.fromJson({
        'id': 's2',
        'type': 'league_promoted',
        'created_at': '2026-11-02T05:01:00Z',
      });
      expect(serverFactKeys(keyless), isEmpty);
    });

    test('the bell words it in the reader\'s language', () {
      final local = NotificationDto(
        id: 'local:league:2026-10-26',
        type: 'league_promoted',
        message: '',
        createdAt: DateTime.utc(2026, 11, 2, 11),
        isRead: false,
        params: const {'division': 'gold'},
        local: true,
      );
      expect(notificationText(Strings.fr, local), 'Tu passes en ligue Or !');
      expect(
        notificationText(Strings.en, local),
        "You're up to the Gold league!",
      );
      final served = NotificationDto(
        id: 's',
        type: 'league_promoted',
        message: 'Bravo ! Tu passes en Or.',
        createdAt: DateTime.utc(2026, 11, 2, 11),
        isRead: false,
      );
      expect(notificationText(Strings.en, served), 'You moved up a league!');
      final withContext = NotificationDto.fromJson({
        'id': 's3',
        'type': 'league_promoted',
        'message': 'Bravo ! Tu passes en Argent.',
        'dedupe_key': 'league:2026-10-26',
        'context': {'xp': 122, 'division': 'silver'},
        'created_at': '2026-11-02T11:00:00Z',
        'is_read': false,
      });
      expect(notificationText(Strings.fr, withContext),
          'Tu passes en ligue Argent !');
      expect(notificationText(Strings.en, withContext),
          "You're up to the Silver league!");
    });

    test('the celebration claims each promotion once', () async {
      final db = LocalDatabase.memory();
      addTearDown(db.close);
      final store = LeagueCelebrations(db, kidId: 'k1');
      const first = (weekStart: '2026-10-26', division: LeagueDivision.silver);
      expect(await store.claim(first), isTrue);
      expect(await store.claim(first), isFalse);
      expect(
        await LeagueCelebrations(db, kidId: 'k2').claim(first),
        isTrue,
        reason: 'per kid',
      );
      const next = (weekStart: '2026-11-02', division: LeagueDivision.gold);
      expect(await store.claim(next), isTrue);
    });
  });

  group('card', () {
    testWidgets('null percentile shows the kid\'s own progress', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          WeeklyLeagueView(
            league: league(xp: 120, toPromote: 0),
            now: wednesday,
          ),
        ),
      );
      expect(find.text('Ligue Argent'), findsOneWidget);
      expect(find.text('+26 XP de plus que la semaine passée'), findsOneWidget);
      expect(
        find.text('Objectif atteint : tu passes en Or lundi !'),
        findsOneWidget,
      );
      expect(find.text('Nouvelle semaine dans 5 jours'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
    });

    testWidgets('a served percentile shows, in English too', (tester) async {
      await tester.pumpWidget(
        app(
          WeeklyLeagueView(
            league: league(),
            percentile: percentile78,
            now: wednesday,
          ),
          locale: const Locale('en', 'CA'),
        ),
      );
      expect(find.text('Silver league'), findsOneWidget);
      expect(find.text('28 more XP for Gold'), findsOneWidget);
      expect(
        find.text('More XP than 78% of Grade 1 students who played this week'),
        findsOneWidget,
      );
    });

    testWidgets('Diamant has no next goal and no bar', (tester) async {
      await tester.pumpWidget(
        app(
          WeeklyLeagueView(
            league: league(
              division: 'diamond',
              promoteAt: null,
              toPromote: null,
            ),
            now: wednesday,
          ),
        ),
      );
      expect(find.text('Tu es au sommet, continue comme ça !'), findsOneWidget);
      expect(find.byType(VillageProgressBar), findsNothing);
    });

    test('no medal is red', () {
      final p = VillagePalette.light;
      for (final d in LeagueDivision.values) {
        final hsv = HSVColor.fromColor(
          medalColor(d, p.gold, p.quebecBlueBright),
        );
        final reddish = hsv.saturation > 0.3 && (hsv.hue < 20 || hsv.hue > 330);
        expect(reddish, isFalse, reason: d.name);
      }
    });

    testWidgets('the promotion medal sits still under reduced motion', (
      tester,
    ) async {
      Widget row(bool still) => app(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: still),
            child: const LeaguePromotedRow(division: LeagueDivision.gold),
          ),
        ),
      );
      await tester.pumpWidget(row(true));
      expect(find.text('Tu passes en ligue Or !'), findsOneWidget);
      expect(find.byKey(const ValueKey('league-promoted-pop')), findsNothing);
      await tester.pumpWidget(row(false));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('league-promoted-pop')), findsOneWidget);
    });
  });
}
