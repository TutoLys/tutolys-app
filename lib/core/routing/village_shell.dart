import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/home/village_screen.dart';
import '../../features/path/path_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/about/about_screen.dart';
import '../../features/progress/progress_controller.dart';
import '../../features/quests/quests_screen.dart';
import '../../features/help/help_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../i18n/strings.dart';
import '../../features/pairing/pairing_controller.dart';
import 'village_header.dart';
import 'village_nav.dart';

/// The paired learner's shell: the design's navigation chrome wrapped around
/// whichever page is current.
///
/// Replaces the three-tab `HomeShell` from A7.2. Tabs are still switched
/// locally rather than through go_router — none of them need their own URL,
/// only `/play` does, and that is pushed on top of this whole shell.
///
/// Five of the six destinations have real screens. Progrès does not yet,
/// and renders an honest placeholder naming itself rather than a blank or a
/// fake.
class VillageShell extends ConsumerStatefulWidget {
  const VillageShell({super.key});

  @override
  ConsumerState<VillageShell> createState() => _VillageShellState();
}

class _VillageShellState extends ConsumerState<VillageShell> {
  int _index = 0;

  /// `IndexedStack`, not a rebuilt child per tab: switching must not
  /// re-trigger each screen's one-shot `build()` load — Home's and Path's
  /// controllers fetch once and expect to stay mounted.
  List<Widget> _pages(Strings s) => [
        VillageScreen(
          // Everything on Village that invites a tap — the CTA, a quest, a
          // building — leads to the Carte, which is the only place a kid can
          // actually play.
          onOpenPath: () => setState(() => _index = 1),
        ),
        const PathScreen(),
        QuestsScreen(onOpenPath: () => setState(() => _index = 1)),
        _NotBuiltYet(title: s.navProgres),
        const ProfileScreen(),
        SettingsScreen(
          onOpenHelp: () => setState(() => _index = _helpIndex),
          onOpenAbout: () => setState(() => _index = _aboutIndex),
        ),
        const HelpScreen(),
        const AboutScreen(),
      ];

  /// Built from [Strings] rather than held as a const list: these labels are
  /// the most visible text in the app, so they follow Réglages' language
  /// choice like everything else.
  ///
  /// Réglages is deliberately not among the primary five — it is the
  /// secondary section on desktop and tablet, and a header icon on mobile.
  ///
  /// Quêtes carries a badge counting today's quests still open — 1 while
  /// the daily challenge is unfinished, none once it is or when it is
  /// unknown. Not the design's "3": there is one quest to count.
  static List<VillageDestination> _primary(Strings s, {int openQuests = 0}) => [
        VillageDestination(label: s.navVillage, asset: 'asset-village.png'),
        VillageDestination(label: s.navCarte, asset: 'asset-carte.png'),
        VillageDestination(
          label: s.navQuetes,
          asset: 'asset-quetes.png',
          badge: openQuests > 0 ? openQuests : null,
        ),
        VillageDestination(label: s.navProgres, asset: 'asset-progres.png'),
        VillageDestination(label: s.navProfil, asset: 'asset-profil.png'),
      ];

  static List<VillageDestination> _secondary(Strings s) => [
        VillageDestination(label: s.navReglages, asset: 'asset-reglages.png'),
      ];

  /// Help and About sit after Réglages in the same `IndexedStack`. They are
  /// not navigation destinations — nothing in the nav selects them — but
  /// they are pages, and routing them through the same stack keeps one
  /// mechanism rather than bolting a second one on for two screens.
  static const _helpIndex = 6;
  static const _aboutIndex = 7;

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final kid = ref.watch(sessionControllerProvider).kid;
    final progress = ref.watch(progressControllerProvider);
    return Scaffold(
      // Transparent: the shell paints the sky gradient, and a scaffold
      // colour underneath it would only show through at the edges.
      backgroundColor: Colors.transparent,
      body: VillageNavShell(
        destinations: _primary(
          t,
          openQuests: progress.dailyQuest?.completed == false ? 1 : 0,
        ),
        secondary: _secondary(t),
        currentIndex: _index,
        onSelect: (i) => setState(() => _index = i),
        onSecondarySelect: (i) => setState(
          () => _index = _primary(t).length + i,
        ),
        helpLabel: t.navHelp,
        onHelp: () => setState(() => _index = _helpIndex),
        child: Column(
          children: [
            // Chrome, not page content: it stays put as the kid moves
            // between pages, and no page has to remember to draw it.
            VillageHeader(
              name: kid?.displayName ?? '',
              subtitle: kid?.gradeLevel == null
                  ? ''
                  : t.gradeLabel(kid!.gradeLevel),
              compact: MediaQuery.sizeOf(context).width < Breakpoints.medium,
              stats: [
                HeaderStat(
                  asset: 'asset-xpstar.webp',
                  label: '${progress.totalXp}',
                ),
                HeaderStat(
                  asset: 'asset-flame.webp',
                  label: progress.currentStreakDays == null
                      ? '–'
                      : '${progress.isStreakEstimated ? '~' : ''}'
                          '${progress.currentStreakDays}',
                ),
              ],
            ),
            Expanded(
              child: IndexedStack(index: _index, children: _pages(t)),
            ),
          ],
        ),
      ),
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
          Text(
            context.s.comingSoonTitle,
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
