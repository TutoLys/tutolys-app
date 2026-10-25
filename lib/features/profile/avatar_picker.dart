import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/strings.dart';
import '../../core/widgets/kid_avatar.dart';
import '../quests/quests_screen.dart' show achievementName;
import 'avatars.dart';

/// Below this width the picker is a bottom sheet; at or above it, a
/// centred dialog. A sheet on a desktop window sat pinned to the bottom
/// with an empty band above it and its end cut off.
const avatarDialogMinWidth = 768.0;

/// Opens the avatar picker from Profil's edit dot.
Future<void> showAvatarPicker(BuildContext context) {
  final p = VillagePalette.of(context);
  if (MediaQuery.sizeOf(context).width >= avatarDialogMinWidth) {
    return showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: p.surface,
        insetPadding: const EdgeInsets.all(Space.lg),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 640,
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: const AvatarPicker(),
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: p.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: const AvatarPicker(),
    ),
  );
}

/// The free avatars, then what play unlocks: by subject, by milestone,
/// and the rare ones. A locked avatar is shown as a silhouette with what
/// unlocks it, because that is the reward's whole point: a kid should see
/// what they're playing towards. A rare one is a "?" until found, so
/// finding it is a surprise.
///
/// Tapping an unlocked avatar wears it at once. There's no save button,
/// like Réglages. The title and close button stay put while the avatars
/// scroll beneath them; the caller bounds the height.
class AvatarPicker extends ConsumerWidget {
  const AvatarPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.s;
    final p = VillagePalette.of(context);
    final state = ref.watch(avatarControllerProvider).value;
    final selected = state?.selected ?? defaultAvatarKey;
    // Only what this kid's sex is offered. A worn avatar outside that list
    // (picked before the sex was set) stays on, but isn't offered again.
    final offered = state?.offered ?? avatarCatalog;
    final starters = offered.where((a) => a.unlock is AvatarFree);
    final bySubject = offered.where((a) => a.unlock is AvatarForSubject);
    final milestones = offered.where(
      (a) => a.unlock is AvatarAtLevel || a.unlock is AvatarForAchievement,
    );
    final rares = offered.where(
      (a) => a.unlock is AvatarRare && !a.isHistorical,
    );
    final historical = offered.where((a) => a.isHistorical);

    Widget grid(Iterable<AvatarDef> avatars) => Wrap(
      spacing: Space.sm,
      runSpacing: Space.sm,
      children: [
        for (final a in avatars)
          _AvatarChoice(
            avatar: a,
            selected: a.key == selected,
            unlocked: state?.isUnlocked(a.key) ?? a.unlock is AvatarFree,
            onTap: () =>
                ref.read(avatarControllerProvider.notifier).select(a.key),
          ),
      ],
    );

    TextStyle section() => TextStyle(
      fontFamily: VillageType.display,
      fontWeight: FontWeight.w700,
      fontSize: 13,
      color: p.inkMuted,
    );

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.lg,
              Space.md,
              Space.sm,
              Space.xs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    t.avatarPickerTitle,
                    style: TextStyle(
                      fontFamily: VillageType.display,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      color: p.ink,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: t.cancel,
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: Icon(Icons.close_rounded, color: p.inkMuted),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              key: const ValueKey('avatar-picker-scroll'),
              padding: const EdgeInsets.fromLTRB(
                Space.lg,
                Space.sm,
                Space.lg,
                Space.lg,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.avatarStarters, style: section()),
                      const SizedBox(height: Space.sm),
                      grid(starters),
                      const SizedBox(height: Space.lg),
                      Text(t.avatarSubjects, style: section()),
                      const SizedBox(height: Space.sm),
                      grid(bySubject),
                      const SizedBox(height: Space.lg),
                      Text(t.avatarUnlockables, style: section()),
                      const SizedBox(height: Space.sm),
                      grid(milestones),
                      const SizedBox(height: Space.lg),
                      Text(t.avatarRares, style: section()),
                      const SizedBox(height: Space.sm),
                      grid(rares),
                      const SizedBox(height: Space.lg),
                      Text(t.avatarHistorical, style: section()),
                      const SizedBox(height: Space.sm),
                      grid(historical),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// What unlocks [a], in the kid's language: "Niveau 5", "Série de 3 jours",
/// "Termine 5 compétences en sciences".
String avatarCondition(Strings t, AvatarDef a) => switch (a.unlock) {
  AvatarFree() => '',
  AvatarAtLevel(:final level) => t.avatarAtLevel(level),
  AvatarForAchievement(:final achievement) => achievementName(t, achievement),
  AvatarForSubject(:final subject, :final skills) => t.avatarForSubject(
    subject,
    skills,
  ),
  AvatarRare() when a.isHistorical => t.avatarHistoricalHint,
  AvatarRare() => t.avatarRareHint,
};

class _AvatarChoice extends StatelessWidget {
  const _AvatarChoice({
    required this.avatar,
    required this.selected,
    required this.unlocked,
    required this.onTap,
  });

  final AvatarDef avatar;
  final bool selected;
  final bool unlocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final p = VillagePalette.of(context);
    final condition = avatarCondition(t, avatar);
    final name = t.avatarName(avatar.key);
    final caption = unlocked ? t.avatarCaption(avatar.key) : null;
    return Semantics(
      button: unlocked,
      selected: selected,
      label: unlocked ? name : t.avatarLocked(condition),
      child: SizedBox(
        width: 92,
        child: InkWell(
          key: ValueKey('avatar-${avatar.key}'),
          borderRadius: BorderRadius.circular(16),
          onTap: unlocked ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? p.quebecBlueBright
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: KidAvatar(
                        avatarKey: avatar.key,
                        size: 64,
                        locked: !unlocked,
                        hidden: !unlocked && avatar.unlock is AvatarRare,
                      ),
                    ),
                    if (!unlocked && avatar.unlock is! AvatarRare)
                      Positioned.fill(
                        child: Center(
                          // Light on the dark silhouette.
                          child: Icon(
                            Icons.lock_rounded,
                            size: 24,
                            color: p.surface,
                          ),
                        ),
                      ),
                    if (selected)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: p.quebecBlueBright,
                            shape: BoxShape.circle,
                            border: Border.all(color: p.surface, width: 2),
                          ),
                          padding: const EdgeInsets.all(2),
                          child: const Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                // Starters have no name to show: they are the kid themself.
                if (avatar.unlock is! AvatarFree)
                  Text(
                    unlocked ? name : condition,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      color: unlocked ? p.ink : p.inkMuted,
                    ),
                  ),
                // Who a historical figure was, once found.
                if (caption != null)
                  Text(
                    caption,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    style: TextStyle(
                      fontSize: 9.5,
                      height: 1.2,
                      color: p.inkMuted,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
