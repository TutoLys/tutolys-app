import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/strings.dart';
import '../../core/widgets/kid_avatar.dart';
import '../../data/local_db/session_store.dart';
import '../profile/avatars.dart';
import 'pairing_controller.dart';

/// Each paired kid's avatar, read from their own `app_state` rows.
///
/// Re-read when the active kid changes theirs, so the tile matches what
/// that kid just picked.
final kidAvatarKeyProvider =
    FutureProvider.family<String, String>((ref, kidId) async {
  ref.watch(selectedAvatarKeyProvider);
  final selected = await AvatarStore(
    ref.watch(localDatabaseProvider),
    kidId: kidId,
  ).selected();
  return selected ?? defaultAvatarKey;
});

/// "Qui joue ?": one tile per kid paired on this device, plus "Ajouter un
/// profil", which opens the pairing-code screen.
///
/// Framed as choosing who you are, never as logging in. Every kid's play
/// is written to the kid chosen here, so the point is that a sibling's
/// play lands on the sibling's profile. A tap is enough for now: the
/// picture passcode that would stop a sibling choosing someone else's tile
/// (B-A0.5) isn't built on the backend yet.
///
/// Shown on launch when several kids share the device, and from the header
/// or Profil. In that case "Retour" goes back to the app as the same kid.
class WhoIsPlayingScreen extends ConsumerWidget {
  const WhoIsPlayingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.s;
    final p = VillagePalette.of(context);
    final session = ref.watch(sessionControllerProvider);
    final controller = ref.read(sessionControllerProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [p.skyTop, p.skyBottom],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              if (session.kid != null)
                Positioned(
                  top: Space.sm,
                  left: Space.sm,
                  child: TextButton.icon(
                    key: const ValueKey('who-back'),
                    onPressed: controller.closeProfileStage,
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: Text(t.addProfileCancel),
                    style: TextButton.styleFrom(foregroundColor: p.ink),
                  ),
                ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(Space.lg),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          t.whoIsPlaying,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: VillageType.display,
                            fontWeight: FontWeight.w800,
                            fontSize: 30,
                            color: p.ink,
                          ),
                        ),
                        const SizedBox(height: Space.lg),
                        Wrap(
                          spacing: Space.md,
                          runSpacing: Space.md,
                          alignment: WrapAlignment.center,
                          children: [
                            for (final kid in session.kids)
                              _KidTile(
                                kid: kid,
                                current: kid.id == session.kid?.id,
                                onTap: () => kid.id == session.kid?.id
                                    ? controller.closeProfileStage()
                                    : controller.switchTo(kid.id),
                              ),
                            _AddTile(onTap: controller.addProfile),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.tileKey,
    required this.onTap,
    required this.label,
    required this.child,
    this.highlighted = false,
  });

  final Key tileKey;
  final VoidCallback onTap;
  final String label;
  final Widget child;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: p.surface,
        elevation: VillageColors.elevationSmall,
        shadowColor: p.shadowSmall,
        shape: RoundedRectangleBorder(
          borderRadius: VillageMetrics.mdAll,
          side: BorderSide(
            color: highlighted ? p.quebecBlueBright : Colors.transparent,
            width: 3,
          ),
        ),
        child: InkWell(
          key: tileKey,
          borderRadius: VillageMetrics.mdAll,
          onTap: onTap,
          child: SizedBox(
            width: 150,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.md, horizontal: Space.sm),
              child: Column(
                children: [
                  child,
                  const SizedBox(height: Space.sm),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: VillageType.display,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: p.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KidTile extends ConsumerWidget {
  const _KidTile({
    required this.kid,
    required this.current,
    required this.onTap,
  });

  final PairedKid kid;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key =
        ref.watch(kidAvatarKeyProvider(kid.id)).value ?? defaultAvatarKey;
    return _Tile(
      tileKey: ValueKey('who-kid-${kid.id}'),
      onTap: onTap,
      label: kid.displayName,
      highlighted: current,
      child: KidAvatar(avatarKey: key, size: 92),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    return _Tile(
      tileKey: const ValueKey('who-add'),
      onTap: onTap,
      label: context.s.addProfile,
      child: Container(
        width: 92,
        height: 92,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: p.track,
        ),
        child: Icon(Icons.add_rounded, size: 44, color: p.quebecBlue),
      ),
    );
  }
}
