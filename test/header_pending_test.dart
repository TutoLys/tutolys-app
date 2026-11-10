import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/core/routing/paired_router.dart';
import 'package:tutolys_app/core/routing/village_header.dart';
import 'package:tutolys_app/core/widgets/kid_avatar.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/features/pairing/pairing_controller.dart';
import 'package:tutolys_app/features/profile/avatars.dart';
import 'package:tutolys_app/features/progress/progress_controller.dart';

/// Hafid, 2026-11-10: on launch the header showed a girl's face and
/// "0 XP" for a boy with 47 XP, then switched. Before progress and the
/// avatar are read, the header shows a dash and a plain circle instead.
class _Progress extends ProgressController {
  _Progress(this.value);
  final ProgressState value;
  @override
  ProgressState build() => value;

  @override
  Future<void> refresh() async {}
}

class _AvatarNeverRead extends AvatarController {
  @override
  Future<AvatarState> build() => Completer<AvatarState>().future;
}

class _Avatar extends AvatarController {
  @override
  Future<AvatarState> build() async =>
      const AvatarState(selected: 'kid_curly', unlocked: {});
}

Widget app({required ProgressState progress, required bool avatarRead}) {
  final router = buildPairedRouter();
  return ProviderScope(
    overrides: [
      localDatabaseProvider.overrideWithValue(LocalDatabase.memory()),
      progressControllerProvider.overrideWith(() => _Progress(progress)),
      avatarControllerProvider.overrideWith(
        avatarRead ? _Avatar.new : _AvatarNeverRead.new,
      ),
    ],
    child: MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: MaterialApp.router(
        theme: TutolysTheme.learner(),
        locale: const Locale('fr', 'CA'),
        supportedLocales: const [Locale('fr', 'CA'), Locale('en', 'CA')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: router,
      ),
    ),
  );
}

final _headerAvatar = find.descendant(
  of: find.byType(VillageHeader),
  matching: find.byType(KidAvatar),
);

void main() {
  testWidgets('before the reads: a dash for XP and no face', (tester) async {
    await tester.pumpWidget(
      app(progress: const ProgressState(), avatarRead: false),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('– XP'), findsOneWidget);
    expect(find.text('0 XP'), findsNothing);
    expect(tester.widget<KidAvatar>(_headerAvatar).avatarKey, isNull);
    expect(
      find.descendant(
        of: _headerAvatar,
        matching: find.byKey(const ValueKey('avatar-pending')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: _headerAvatar, matching: find.byType(Image)),
      findsNothing,
      reason: 'never a default face that may be someone else\'s',
    );
  });

  testWidgets('once read: the real XP and the kid\'s own avatar', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        progress: const ProgressState(loading: false, totalXp: 47),
        avatarRead: true,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('47 XP'), findsOneWidget);
    expect(tester.widget<KidAvatar>(_headerAvatar).avatarKey, 'kid_curly');
  });

  testWidgets('a read that found nothing is a real 0, not a dash', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(progress: const ProgressState(loading: false), avatarRead: true),
    );
    await tester.pump();
    expect(find.text('0 XP'), findsOneWidget);
  });
}
