import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/pairing/pairing_controller.dart';
import '../../features/pairing/pairing_screen.dart';
import '../../features/path/path_screen.dart';

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
        SessionStatus.paired => const PathScreen(),
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: TutolysMascot(size: 120)),
    );
  }
}
