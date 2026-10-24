import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../features/home/home_screen.dart';
import '../../features/path/path_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/settings/settings_screen.dart';
import 'village_nav.dart';

/// The paired learner's shell: the design's navigation chrome wrapped around
/// whichever page is current.
///
/// Replaces the three-tab `HomeShell` from A7.2. Tabs are still switched
/// locally rather than through go_router — none of them need their own URL,
/// only `/play` does, and that is pushed on top of this whole shell.
///
/// Four of the six destinations have real screens. Quêtes and Progrès do
/// not yet, and render an honest placeholder naming themselves rather than
/// a blank or a fake.
class VillageShell extends StatefulWidget {
  const VillageShell({super.key});

  @override
  State<VillageShell> createState() => _VillageShellState();
}

class _VillageShellState extends State<VillageShell> {
  int _index = 0;

  /// `IndexedStack`, not a rebuilt child per tab: switching must not
  /// re-trigger each screen's one-shot `build()` load — Home's and Path's
  /// controllers fetch once and expect to stay mounted.
  static const _pages = <Widget>[
    HomeScreen(),
    PathScreen(),
    _NotBuiltYet(title: 'Quêtes'),
    _NotBuiltYet(title: 'Progrès'),
    ProfileScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Transparent: the shell paints the sky gradient, and a scaffold
      // colour underneath it would only show through at the edges.
      backgroundColor: Colors.transparent,
      body: VillageNavShell(
        destinations: villageDestinations,
        secondary: villageSecondaryDestinations,
        currentIndex: _index,
        onSelect: (i) => setState(() => _index = i),
        onSecondarySelect: (i) => setState(
          () => _index = villageDestinations.length + i,
        ),
        onHelp: () => _showNotBuiltYet(context, 'Aide & support'),
        child: IndexedStack(index: _index, children: _pages),
      ),
    );
  }

  void _showNotBuiltYet(BuildContext context, String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title — pas encore construit')),
    );
  }
}

/// A page that does not exist yet, saying so.
class _NotBuiltYet extends StatelessWidget {
  const _NotBuiltYet({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/asset-mascot-welcome.webp',
            width: 120,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: Space.md),
          Text(
            title,
            style: const TextStyle(
              fontFamily: VillageType.display,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: VillageColors.quebecBlue,
            ),
          ),
          const SizedBox(height: Space.xs),
          const Text(
            'Cette page arrive bientôt.',
            style: TextStyle(
              fontFamily: VillageType.display,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: VillageColors.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}
