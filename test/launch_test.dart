import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/core/i18n/strings.dart';
import 'package:tutolys_app/features/launch/launch_flow.dart';
import 'package:tutolys_app/features/launch/tutolys_loader_screen.dart';
import 'package:tutolys_app/features/launch/tutolys_welcome_screen.dart';
import 'package:tutolys_app/features/launch/widgets/launch_backdrop.dart';
import 'package:tutolys_app/features/launch/widgets/tutolys_animated_logo.dart';
import 'package:tutolys_app/features/launch/widgets/tutolys_loading_message_rotator.dart';
import 'package:tutolys_app/features/launch/widgets/tutolys_progress_bar.dart';

final _fr = Strings.of(const Locale('fr', 'CA'));

Widget _host(Widget child, {bool reduceMotion = true, Size size = const Size(1024, 800)}) {
  return MediaQuery(
    data: MediaQueryData(size: size, disableAnimations: reduceMotion),
    child: MaterialApp(
      locale: const Locale('fr', 'CA'),
      supportedLocales: const [Locale('fr', 'CA'), Locale('en', 'CA')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: TutolysTheme.village(),
      home: child,
    ),
  );
}

String? _barValue(WidgetTester tester) {
  final node = tester.getSemantics(find.byType(TutolysProgressBar));
  return node.getSemanticsData().value;
}

void main() {
  group('TutolysProgressBar', () {
    testWidgets('only ever moves forward', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(const SizedBox(width: 300, child: TutolysProgressBar(value: 0.5))));
      expect(_barValue(tester), '50 %');

      // A lower value is ignored, never drawn as the bar shrinking.
      await tester.pumpWidget(_host(const SizedBox(width: 300, child: TutolysProgressBar(value: 0.3))));
      expect(_barValue(tester), '50 %');

      await tester.pumpWidget(_host(const SizedBox(width: 300, child: TutolysProgressBar(value: 0.8))));
      expect(_barValue(tester), '80 %');
      handle.dispose();
    });

    testWidgets('clamps out-of-range values', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(const SizedBox(width: 300, child: TutolysProgressBar(value: 1.7))));
      expect(_barValue(tester), '100 %');
      handle.dispose();
    });
  });

  group('TutolysLoadingMessageRotator', () {
    testWidgets('rotates on its interval and loops', (tester) async {
      await tester.pumpWidget(_host(const TutolysLoadingMessageRotator(
        messages: ['a', 'b'],
        interval: Duration(seconds: 1),
      )));
      expect(find.text('a'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('b'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('a'), findsOneWidget);
    });

    testWidgets('holds the last line when not looping', (tester) async {
      await tester.pumpWidget(_host(const TutolysLoadingMessageRotator(
        messages: ['a', 'b'],
        interval: Duration(seconds: 1),
        loop: false,
      )));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('b'), findsOneWidget);
    });

    testWidgets('a new list starts from its first line', (tester) async {
      await tester.pumpWidget(_host(const TutolysLoadingMessageRotator(
        messages: ['a', 'b', 'c'],
        interval: Duration(seconds: 1),
      )));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('b'), findsOneWidget);
      await tester.pumpWidget(_host(const TutolysLoadingMessageRotator(
        messages: ['x', 'y'],
        interval: Duration(seconds: 1),
      )));
      expect(find.text('x'), findsOneWidget);
    });
  });

  group('loader copy follows real progress', () {
    test('mood lines below 80 %, then "almost", then "nearly ready"', () {
      expect(TutolysLoaderScreen.messagesFor(_fr, progress: 0.5, done: false), _fr.launchMessages);
      expect(TutolysLoaderScreen.messagesFor(_fr, progress: 0.85, done: false), [_fr.launchAlmost]);
      expect(TutolysLoaderScreen.messagesFor(_fr, progress: 0.95, done: false), [_fr.launchNearlyReady]);
    });

    test('the welcome line only once startup is done', () {
      expect(TutolysLoaderScreen.messagesFor(_fr, progress: 0.99, done: false), isNot(contains(_fr.launchDone)));
      expect(TutolysLoaderScreen.messagesFor(_fr, progress: 0.2, done: true), [_fr.launchDone]);
    });

    test('the brief\'s eight lines, in order', () {
      expect([..._fr.launchMessages, _fr.launchAlmost, _fr.launchNearlyReady, _fr.launchDone], [
        'Préparation de ton aventure…',
        'On prépare le village pour toi…',
        'On rassemble tes activités…',
        'Foxy arrive avec tes défis…',
        'On installe ton parcours d’apprentissage…',
        'Tiens bon, on y est presque…',
        'Presque prêt…',
        'Bienvenue dans TutoLys !',
      ]);
    });
  });

  group('reduced motion', () {
    testWidgets('the loader comes to rest: no frame scheduled', (tester) async {
      await tester.pumpWidget(_host(const TutolysLoaderScreen(progress: 0.4)));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('the welcome screen comes to rest too', (tester) async {
      await tester.pumpWidget(_host(TutolysWelcomeScreen(kidName: 'Yelhan', onStart: () {})));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('with motion on, the logo keeps animating', (tester) async {
      await tester.pumpWidget(_host(const Center(child: TutolysAnimatedLogo(size: 120)), reduceMotion: false));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a hidden loop stops ticking', (tester) async {
      await tester.pumpWidget(_host(
        const Visibility(
          visible: false,
          maintainState: true,
          child: LaunchBackdrop(child: SizedBox()),
        ),
        reduceMotion: false,
      ));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  group('LaunchFlow', () {
    Widget flow(LaunchStage stage, {String? kid = 'Yelhan', VoidCallback? onFinished}) => _host(
          LaunchFlow(
            stage: stage,
            kidName: kid,
            startProgress: 0.1,
            onFinished: onFinished ?? () {},
          ),
        );

    testWidgets('loader → done beat → welcome → finished', (tester) async {
      final handle = tester.ensureSemantics();
      var finished = 0;
      await tester.pumpWidget(flow(LaunchStage.restoring, onFinished: () => finished++));
      expect(find.byType(TutolysLoaderScreen), findsOneWidget);
      expect(find.text(_fr.launchMessages.first), findsOneWidget);

      await tester.pumpWidget(flow(LaunchStage.ready, onFinished: () => finished++));
      await tester.pump();
      expect(find.text(_fr.launchDone), findsOneWidget);
      expect(_barValue(tester), '100 %');
      expect(find.byType(TutolysWelcomeScreen), findsNothing);

      await tester.pump(LaunchFlow.doneBeatReduced);
      await tester.pump();
      expect(find.byType(TutolysWelcomeScreen), findsOneWidget);
      expect(find.text('Salut Yelhan !'), findsOneWidget);

      // An impatient double tap starts the day once.
      await tester.tap(find.text('Jouer'));
      await tester.tap(find.text('Jouer'), warnIfMissed: false);
      expect(finished, 1);
      handle.dispose();
    });

    testWidgets('an unpaired device is invited to start the adventure', (tester) async {
      await tester.pumpWidget(flow(LaunchStage.ready, kid: null));
      await tester.pump();
      await tester.pump(LaunchFlow.doneBeatReduced);
      await tester.pump();
      expect(find.text('Commencer l’aventure'), findsOneWidget);
      expect(find.text(_fr.welcomeFoxLineNew), findsOneWidget);
    });

    testWidgets('progress creeps within a stage but never past its span', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(flow(LaunchStage.restoring));
      final readings = <int>[];
      for (var i = 0; i < 80; i++) {
        await tester.pump(const Duration(milliseconds: 250));
        readings.add(int.parse(_barValue(tester)!.replaceAll(' %', '')));
      }
      // Monotonic, alive, and short of the restoring span's end
      // (0.1 + 0.9 × 0.55 = 59.5 %).
      for (var i = 1; i < readings.length; i++) {
        expect(readings[i], greaterThanOrEqualTo(readings[i - 1]));
      }
      expect(readings.last, greaterThan(10));
      expect(readings.last, lessThan(60));

      // The stage really changing is what lets the bar cross that line.
      await tester.pumpWidget(flow(LaunchStage.sessionResolved));
      await tester.pump();
      expect(int.parse(_barValue(tester)!.replaceAll(' %', '')), greaterThanOrEqualTo(59));

      await tester.pumpWidget(const SizedBox());
      handle.dispose();
    });
  });

  testWidgets('the welcome screen fits a small phone without overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(
      TutolysWelcomeScreen(kidName: 'Yelhan', onStart: () {}),
      size: const Size(360, 640),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

}
