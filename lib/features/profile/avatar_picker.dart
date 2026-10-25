import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/strings.dart';
import '../../core/widgets/kid_avatar.dart';
import '../quests/quests_screen.dart' show achievementName;
import 'avatars.dart';

/// Opens the avatar picker from Profil's edit dot.
Future<void> showAvatarPicker(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: VillagePalette.of(context).surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const AvatarPicker(),
    );

/// The starters, then what play unlocks. A locked avatar is shown, dimmed,
/// with what unlocks it, because that is the reward's whole point: a kid
/// should see what they're playing towards.
///
/// Tapping an unlocked avatar wears it at once. There's no save button,
/// like Réglages.
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
    final unlockables = offered.where((a) => a.unlock is! AvatarFree);

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
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.lg),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                  const SizedBox(height: Space.sm),
                  Text(t.avatarStarters, style: section()),
                  const SizedBox(height: Space.sm),
                  grid(starters),
                  const SizedBox(height: Space.lg),
                  Text(t.avatarUnlockables, style: section()),
                  const SizedBox(height: Space.sm),
                  grid(unlockables),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// What unlocks [a], in the kid's language: "Niveau 5", "Série de 3 jours".
String avatarCondition(Strings t, AvatarDef a) => switch (a.unlock) {
      AvatarFree() => '',
      AvatarAtLevel(:final level) => t.avatarAtLevel(level),
      AvatarForAchievement(:final achievement) => achievementName(t, achievement),
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
                          color: selected ? p.quebecBlueBright : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: KidAvatar(
                        avatarKey: avatar.key,
                        size: 64,
                        locked: !unlocked,
                      ),
                    ),
                    if (!unlocked)
                      Positioned.fill(
                        child: Center(
                          child: Icon(Icons.lock_rounded, size: 24, color: p.ink),
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
                          child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
