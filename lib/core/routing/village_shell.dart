import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/village_screen.dart';
import '../../features/notifications/notifications_controller.dart';
import '../../features/notifications/notifications_panel.dart';
import '../../features/path/path_controller.dart';
import '../../features/path/path_screen.dart';
import '../../features/profile/avatars.dart';
import '../../features/settings/settings_controller.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/about/about_screen.dart';
import '../../features/progress/progress_controller.dart';
import '../../features/progress/progress_screen.dart';
import '../../features/quests/quest_board.dart';
import '../../features/quests/quests_screen.dart';
import '../../features/help/help_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../i18n/strings.dart';
import '../widgets/kid_avatar.dart';
import '../../features/pairing/pairing_controller.dart';
import '../../features/pairing/profile_menu.dart';
import 'village_header.dart';
import 'village_nav.dart';
import '../../features/audio/music_director.dart';

/// The paired learner's shell: the design's navigation chrome wrapped around
/// whichever page is current.
///
/// Replaces the three-tab `HomeShell` from A7.2.
///
/// Every page has its own URL (`/carte`, `/progres`, …), and [page] comes
/// from it. Holding the tab only in memory sent every refresh back to the
/// Village, and gave the browser's back button nothing to go back to.
/// Switching pages calls `go`, so the URL is the single source of truth;
/// the router keeps this one shell instance across pages (see
/// `buildPairedRouter`), so the `IndexedStack` below still keeps every page
/// alive.
class VillageShell extends ConsumerStatefulWidget {
  const VillageShell({this.page = VillageShell.defaultPage, super.key});

  /// The slug of the page to show, one of [pages].
  final String page;

  /// URL slugs, in `IndexedStack` order. French, like the labels they stand
  /// for; never translated, so a bookmark survives a language switch.
  static const pages = [
    'village',
    'carte',
    'quetes',
    'progres',
    'profil',
    'reglages',
    'aide',
    'a-propos',
  ];

  static const defaultPage = 'village';

  @override
  ConsumerState<VillageShell> createState() => _VillageShellState();
}

class _VillageShellState extends ConsumerState<VillageShell> {
  // Background music belongs to the shell pages (ADR 0035).
  late final MusicDirector _music = ref.read(musicDirectorProvider);

  @override
  void initState() {
    super.initState();
    _music.shellShown();
  }

  @override
  void dispose() {
    _music.shellGone();
    super.dispose();
  }

  /// The last of the five tabs shown, where ← from Réglages returns.
  int _lastTab = 0;

  @override
  void didUpdateWidget(VillageShell old) {
    super.didUpdateWidget(old);
    final i = VillageShell.pages.indexOf(old.page);
    if (i >= 0 && i < _settingsIndex) _lastTab = i;
  }

  /// ← on a phone (AM8): Aide and À propos go back to Réglages, which
  /// is where a phone reaches them; Réglages goes back to the last tab.
  void _back() => _open(_index > _settingsIndex ? _settingsIndex : _lastTab);

  int get _index {
    final i = VillageShell.pages.indexOf(widget.page);
    return i < 0 ? 0 : i;
  }

  void _open(int index) => context.go('/${VillageShell.pages[index]}');

  final _identityKey = GlobalKey();

  /// Opens under the header's avatar, from there and from Profil's button.
  void _openProfileMenu() {
    final box = _identityKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    showProfileMenu(
      context,
      ref,
      anchor: box.localToGlobal(Offset.zero) & box.size,
    );
  }

  /// `IndexedStack`, not a rebuilt child per tab: switching must not
  /// re-trigger each screen's one-shot `build()` load — Home's and Path's
  /// controllers fetch once and expect to stay mounted.
  List<Widget> _pages(Strings s) => [
        VillageScreen(
          // Everything on Village that invites a tap — the CTA, a quest, a
          // building — leads to the Carte, which is the only place a kid can
          // actually play.
          onOpenPath: () => _open(1),
          onOpenQuests: () => _open(2),
          // A building opens the Carte on its own subject: the subject is
          // chosen before the page switches, so the Carte never flashes the
          // previous one.
          onOpenSubject: (code) {
            ref.read(pathControllerProvider.notifier).selectSubject(code);
            _open(1);
          },
        ),
        const PathScreen(),
        QuestsScreen(onOpenPath: () => _open(1)),
        ProgressScreen(
          onOpenSubject: (code) {
            ref.read(pathControllerProvider.notifier).selectSubject(code);
            _open(1);
          },
        ),
        ProfileScreen(
          onSwitchProfile: _openProfileMenu,
          // The league chip opens Progrès, where the week's card is.
          onOpenProgress: () => _open(3),
        ),
        SettingsScreen(
          onOpenHelp: () => _open(_helpIndex),
          onOpenAbout: () => _open(_aboutIndex),
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
  /// Quêtes carries a badge counting today's quests still open, from the
  /// same board the page draws — none once all are done or while unknown.
  static List<VillageDestination> _primary(
    Strings s, {
    int openQuests = 0,
    String? avatarKey,
  }) => [
        VillageDestination(label: s.navVillage, asset: 'asset-village.png'),
        VillageDestination(label: s.navCarte, asset: 'asset-carte.png'),
        VillageDestination(
          label: s.navQuetes,
          asset: 'asset-quetes.png',
          badge: openQuests > 0 ? openQuests : null,
        ),
        VillageDestination(label: s.navProgres, asset: 'asset-progres.png'),
        // Profil is the kid's own page, so its icon is their avatar, the
        // same one the header shows. The generic icon stays for a kid with
        // no avatar yet, or one whose art isn't drawn.
        VillageDestination(
          label: s.navProfil,
          asset: 'asset-profil.png',
          icon: avatarKey == null || avatarFor(avatarKey).asset == null
              ? null
              : (size) => KidAvatar(avatarKey: avatarKey, size: size),
        ),
      ];

  static List<VillageDestination> _secondary(Strings s) => [
        VillageDestination(label: s.navReglages, asset: 'asset-reglages.png'),
      ];

  /// Help and About sit after Réglages in the same `IndexedStack`. They are
  /// not navigation destinations — nothing in the nav selects them — but
  /// they are pages, and routing them through the same stack keeps one
  /// mechanism rather than bolting a second one on for two screens.
  static const _settingsIndex = 5;
  static const _helpIndex = 6;
  static const _aboutIndex = 7;

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final session = ref.watch(sessionControllerProvider);
    final kid = session.kid;
    final progress = ref.watch(progressControllerProvider);
    final unread = ref.watch(
      notificationsControllerProvider.select((n) => n.unreadCount),
    );
    final board = ref.watch(questBoardProvider).value;
    return Scaffold(
      // Transparent: the shell paints the sky gradient, and a scaffold
      // colour underneath it would only show through at the edges.
      backgroundColor: Colors.transparent,
      body: VillageNavShell(
        destinations: _primary(
          t,
          openQuests: board?.openCount ?? 0,
          avatarKey: ref.watch(selectedAvatarKeyProvider),
        ),
        secondary: _secondary(t),
        currentIndex: _index,
        onSelect: _open,
        onSecondarySelect: (i) => _open(_primary(t).length + i),
        helpLabel: t.navHelp,
        onHelp: () => _open(_helpIndex),
        // Folded per kid (Hafid, 2026-11-10: more room for the village).
        fold: ref.watch(settingsControllerProvider.select((s) => s.navFold)),
        onFold: ref.read(settingsControllerProvider.notifier).setNavFold,
        shrinkLabel: t.navShrink,
        hideLabel: t.navHide,
        expandLabel: t.navExpand,
        showLabel: t.navShow,
        child: Column(
          children: [
            // Chrome, not page content: it stays put as the kid moves
            // between pages, and no page has to remember to draw it.
            VillageHeader(
              name: kid?.displayName ?? '',
              subtitle: kid?.gradeLevel == null
                  ? ''
                  : t.gradeLabel(kid!.gradeLevel),
              avatarKey: ref.watch(selectedAvatarKeyProvider),
              // The profile menu, always one tap away, so a sibling can
              // hand the device over.
              identityKey: _identityKey,
              onIdentity: _openProfileMenu,
              identityLabel: t.switchProfile,
              compact: MediaQuery.sizeOf(context).width < Breakpoints.medium,
              // Phones only: same threshold as VillageNavShell's switch to
              // the bottom bar, which has no Réglages tab.
              onSettings: MediaQuery.sizeOf(context).width < Breakpoints.compact
                  ? () => _open(_primary(t).length)
                  : null,
              settingsLabel: t.navReglages,
              settingsActive: _index >= _settingsIndex,
              onBack:
                  MediaQuery.sizeOf(context).width < Breakpoints.compact &&
                      _index >= _settingsIndex
                  ? _back
                  : null,
              backLabel: t.navBack,
              onNotifications: () => showNotificationsPanel(context),
              unreadNotifications: unread,
              notificationsLabel: t.notificationsBellLabel(unread),
              stats: [
                // The design's "Niv. 14" pill: the school year's level and
                // its track to the next one (ADR 0033), i.e. how far through
                // the ~5 skills the next level needs.
                if (progress.level case final level?)
                  HeaderStat(
                    asset: 'asset-xpstar.webp',
                    priority: 3,
                    label: t.progressLevel(level),
                    progress: progress.levelProgress,
                    tooltip: switch ((
                      progress.skillsCompleted,
                      progress.skillsTotal,
                      kid?.gradeLevel,
                    )) {
                      (final done?, final total?, final grade?) =>
                        t.headerLevelTooltip(done, total, grade),
                      _ => null,
                    },
                  ),
                // XP beside the level, always: the level counts skills, so
                // without this the points a kid just earned show nowhere
                // up here (Hafid: "Why is the XP not showing?").
                // A dash until progress is read, like the streak: never a
                // 0 the kid didn't earn (Hafid, 2026-11-10).
                HeaderStat(
                  asset: 'asset-xpstar.webp',
                  priority: 0,
                  label: progress.loading
                      ? t.headerXpPending
                      : t.headerXp(progress.totalXp),
                ),
                HeaderStat(
                  asset: 'asset-flame.webp',
                  priority: 1,
                  label: progress.currentStreakDays == null
                      ? '–'
                      : '${progress.currentStreakDays}',
                ),
                // The design's "2/3 quêtes" pill: today's quests done.
                if (board != null && board.quests.isNotEmpty)
                  HeaderStat(
                    asset: 'asset-target.webp',
                    priority: 2,
                    label:
                        '${board.doneCount}/${board.quests.length} '
                        '${t.headerQuestsLabel}',
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
