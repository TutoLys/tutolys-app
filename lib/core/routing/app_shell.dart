import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/pairing/pairing_controller.dart';
import '../../features/pairing/pairing_screen.dart';
import 'paired_router.dart';

/// Chooses the screen from the session state.
///
/// Deliberately a state switch rather than go_router redirects for this
/// decision: "am I paired?" is the app's single most important question, and
/// expressing it as one exhaustive switch means there is no URL that can land
/// an unpaired device on a play screen. Routing within the paired shell is
/// go_router's job (A7 onward).
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  @override
  void initState() {
    super.initState();
    // Read the secure store and refresh once the first frame is up, so launch
    // shows a splash rather than a blank window.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sessionControllerProvider.notifier).restore();
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);

    return AnimatedSwitcher(
      duration: Motion.normal,
      child: switch (session.status) {
        SessionStatus.checking => const _Splash(),
        SessionStatus.unpaired => const PairingScreen(),
        SessionStatus.paired => const _PairedShell(),
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: TutolysMascot(size: 120)));
  }
}

/// Owns the paired-branch router's lifetime.
///
/// A fresh `GoRouter` per entry into the paired state, not one cached for
/// the app's whole lifetime: a kid can forget the device and re-pair later
/// in the same app session, and re-entering `/play`'s stale location from a
/// prior pairing (rather than starting back at `/path`) would be a real,
/// confusing bug. Giving this its own `StatefulWidget` means
/// `AnimatedSwitcher` creates (and `State.dispose` tears down) a new router
/// every time this branch is (re-)entered, the same way it already does for
/// `PairingScreen`/`PathScreen` themselves.
class _PairedShell extends StatefulWidget {
  const _PairedShell();

  @override
  State<_PairedShell> createState() => _PairedShellState();
}

class _PairedShellState extends State<_PairedShell> {
  late final GoRouter _router = buildPairedRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // `Router.withConfig`, not a nested `MaterialApp.router`: this inherits
    // the outer `MaterialApp`'s theme/localizations/Directionality instead
    // of needing its own copy of all three.
    return Router.withConfig(config: _router);
  }
}
