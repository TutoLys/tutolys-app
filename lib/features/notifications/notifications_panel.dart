import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/strings.dart';
import '../../data/api/notifications_api.dart';
import '../quests/quest_board.dart'
    show Achievement, exercisesQuestTarget, minutesQuestTarget;
import '../quests/quests_screen.dart' show achievementName;
import 'notifications_controller.dart';

/// Opens the inbox from the header bell.
///
/// The design draws the bell and its badge but not what opens; this is
/// built from its own parts (`.quest-panel` card, its shadow and radius).
/// A card dropping from the bell on tablet and desktop; a bottom sheet on a
/// phone, where a floating card would cover most of the screen anyway.
Future<void> showNotificationsPanel(BuildContext context) {
  final phone = MediaQuery.sizeOf(context).width < Breakpoints.compact;
  final still = MediaQuery.disableAnimationsOf(context);
  final p = VillagePalette.of(context);

  if (phone) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: p.surface,
      showDragHandle: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.7,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const NotificationsPanel(),
    );
  }

  return showGeneralDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.08),
    transitionDuration: still ? Duration.zero : Motion.quick,
    pageBuilder: (context, _, _) => SafeArea(
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          // Just under the header's bell.
          padding: const EdgeInsets.only(
            top: VillageMetrics.headerHeight - 10,
            right: 20,
            left: 20,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360, maxHeight: 480),
            child: Material(
              color: p.surface,
              elevation: 0,
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: p.line),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: p.shadow,
                      blurRadius: 40,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: NotificationsPanel(),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
    transitionBuilder: (context, animation, _, child) => FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, -0.03), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
        child: child,
      ),
    ),
  );
}

/// The inbox: a title, then the kid's notifications, newest first.
///
/// Opening it reads everything. The rows keep the unread dot they had when
/// it opened, so the kid can still see which ones are new this time.
class NotificationsPanel extends ConsumerStatefulWidget {
  const NotificationsPanel({super.key});

  @override
  ConsumerState<NotificationsPanel> createState() => _NotificationsPanelState();
}

class _NotificationsPanelState extends ConsumerState<NotificationsPanel> {
  late final List<NotificationDto> _shown = ref
      .read(notificationsControllerProvider)
      .items;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationsControllerProvider.notifier).markAllRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    final t = context.s;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
          child: Row(
            children: [
              Image.asset(
                'assets/images/asset-bell.webp',
                width: 18,
                height: 18,
              ),
              const SizedBox(width: 7),
              Text(
                t.notificationsTitle,
                style: TextStyle(
                  fontFamily: VillageType.display,
                  fontWeight: FontWeight.w700,
                  fontSize: 14.5,
                  color: p.ink,
                ),
              ),
            ],
          ),
        ),
        if (_shown.isEmpty)
          _Empty(palette: p)
        else
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
              itemCount: _shown.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                thickness: 1,
                indent: 8,
                endIndent: 8,
                color: p.line,
              ),
              itemBuilder: (_, i) => _Row(notification: _shown[i], palette: p),
            ),
          ),
      ],
    );
  }
}

/// The app's own wording for a known type, in the reader's language.
///
/// The app's own notifications (ADR 0097) are worded here, at display time,
/// from their params, so they follow a language change.
String notificationText(Strings t, NotificationDto n) => switch (n.type) {
  'daily_quest_completed' => t.notificationDailyQuest,
  'quest_completed' => t.notificationQuestDone(
    switch (n.params['quest']) {
      'exercises' => t.questExercisesTitle(
        n.params['target'] as int? ?? exercisesQuestTarget,
      ),
      'minutes' => t.questMinutesTitle(
        n.params['target'] as int? ?? minutesQuestTarget,
      ),
      _ => t.navQuetes,
    },
  ),
  'achievement_earned' => t.notificationAchievement(
    achievementName(t, _achievement(n.params['achievement'] as String?)),
  ),
  'streak_milestone' => n.params['days'] == 7
      ? t.notificationStreakGuardian
      : t.notificationStreakChest,
  'level_reached' => t.notificationLevel(n.params['level'] as int? ?? 1),
  'streak_freeze_spent' => t.notificationStreakFreeze,
  'streak_freeze_refunded' => t.notificationStreakFreezeRefunded,
  'tutoring_session_soon' => t.notificationTutoringSession(n.message),
  _ => n.message,
};

Achievement? _achievement(String? key) {
  for (final a in Achievement.values) {
    if (a.name == key) return a;
  }
  return null;
}

(String, Color) _iconFor(NotificationDto n, VillagePalette p) =>
    switch (n.type) {
      'daily_quest_completed' ||
      'quest_completed' => ('asset-target.webp', p.goldPale),
      'achievement_earned' => ('asset-badge.webp', p.goldPale),
      'level_reached' => ('asset-xpstar.webp', p.goldPale),
      'streak_milestone' => (
        n.params['days'] == 7 ? 'asset-flame.webp' : 'asset-chest.webp',
        p.navActiveFill,
      ),
      'streak_freeze_spent' ||
      'streak_freeze_refunded' => ('asset-flame.webp', p.navActiveFill),
      'tutoring_session_soon' => ('asset-mascot-welcome.webp', p.goldPale),
      _ => ('asset-bell.webp', p.track),
    };

class _Row extends StatelessWidget {
  const _Row({required this.notification, required this.palette});

  final NotificationDto notification;
  final VillagePalette palette;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final t = context.s;
    final (asset, tint) = _iconFor(notification, p);
    final unread = !notification.isRead;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
            child: Image.asset('assets/images/$asset', width: 20, height: 20),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notificationText(t, notification),
                  style: TextStyle(
                    fontFamily: VillageType.display,
                    fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                    fontSize: 13,
                    height: 1.3,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  t.notificationsAgo(
                    DateTime.now().difference(notification.createdAt),
                  ),
                  style: TextStyle(fontSize: 11, color: p.inkMuted),
                ),
              ],
            ),
          ),
          if (unread) ...[
            const SizedBox(width: 8),
            Container(
              key: const ValueKey('notification-unread'),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: p.quebecBlueBright,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.palette});

  final VillagePalette palette;

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        children: [
          Image.asset('assets/images/asset-mascot-welcome.webp', height: 72),
          const SizedBox(height: 10),
          Text(
            t.notificationsEmpty,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: VillageType.display,
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
              color: palette.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            t.notificationsEmptyHint,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: palette.inkMuted),
          ),
        ],
      ),
    );
  }
}
