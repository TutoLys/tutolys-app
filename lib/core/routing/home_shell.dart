import 'package:flutter/material.dart';

import '../../features/home/home_screen.dart';
import '../../features/path/path_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../i18n/strings.dart';

/// The three learner tabs (A7.2), switched locally rather than through
/// go_router — none of the three need their own URL or deep link, only
/// `/play` (pushed on top of this whole shell) does.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  // IndexedStack, not a rebuilt child per tab: switching tabs must not
  // re-trigger each screen's one-shot `build()` load (Home/Path's
  // controllers fetch once and expect to stay mounted).
  static const _tabs = [HomeScreen(), PathScreen(), ProfileScreen()];

  @override
  Widget build(BuildContext context) {
    final s = context.s;

    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: s.navHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.map_outlined),
            selectedIcon: const Icon(Icons.map),
            label: s.navPath,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: s.navProfile,
          ),
        ],
      ),
    );
  }
}
