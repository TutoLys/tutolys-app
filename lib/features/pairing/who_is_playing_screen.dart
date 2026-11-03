import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/strings.dart';
import '../../core/widgets/kid_avatar.dart';
import '../../data/local_db/session_store.dart';
import '../passcode/passcode_entry_screen.dart';
import '../profile/avatars.dart';
import 'pairing_controller.dart';

/// Each paired kid's avatar, read from their own `app_state` rows.
///
/// Re-read when the active kid changes theirs, so the tile matches what
/// that kid just picked.
final kidAvatarKeyProvider = FutureProvider.family<String, String>((
  ref,
  kidId,
) async {
  ref.watch(selectedAvatarKeyProvider);
  final store = AvatarStore(ref.watch(localDatabaseProvider), kidId: kidId);
  final selected = await store.selected();
  final sex = await store.sex();
  return isKnownAvatar(selected)
      ? avatarForSex(selected!, sex, await store.unlocked())
      : defaultAvatarFor(sex);
});

/// "Qui joue ?": one tile per kid paired on this device, plus "Ajouter un
/// profil", which opens the pairing-code screen.
///
/// Framed as choosing who you are, never as logging in. Every kid's play
/// is written to the kid chosen here, so the point is that a sibling's
/// play lands on the sibling's profile. A kid with a picture passcode taps
/// their three pictures before the switch ([confirmItsMe], B-A0.5); one
/// without is a tap.
///
/// When nobody has said who they are yet (`SessionState.mustConfirm`: after
/// a pause past the threshold, and always on a class tablet), the kid
/// already active is asked too, and there is no "Retour". On a class
/// tablet every kid needs a passcode, and the class's name sits under the
/// title.
///
/// The header and Profil open the profile menu instead (ADR 0123). This
/// screen is for when the app must ask, and for backing out of "Ajouter un
/// profil" from launch, where "Retour" goes back to the app as the same kid.
/// On launch with several kids, the welcome screen is the picker instead
/// (ADR 0024), so a cold start never names one of them.
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
              if (session.kid != null && !session.mustConfirm)
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
                        if (session.classroom case final c?) ...[
                          const SizedBox(height: Space.xxs),
                          Text(
                            t.whoIsPlayingClass(c.className),
                            key: const ValueKey('who-class'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: VillageType.display,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: p.inkMuted,
                            ),
                          ),
                        ],
                        const SizedBox(height: Space.lg),
                        Wrap(
                          spacing: Space.md,
                          runSpacing: Space.md,
                          alignment: WrapAlignment.center,
                          children: [
                            for (final kid in session.kids)
                              KidProfileTile(
                                kid: kid,
                                current: kid.id == session.kid?.id &&
                                    !session.mustConfirm,
                                onTap: () =>
                                    kid.id == session.kid?.id &&
                                            !session.mustConfirm
                                        ? controller.closeProfileStage()
                                        : enterAs(context, ref, kid),
                              ),
                            // Not on a class tablet: the school decides who
                            // is on it, and a child must not be able to pair
                            // a family code onto a school's device.
                            if (!session.isClassroom)
                              AddProfileTile(onTap: controller.addProfile),
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

/// Plays as [kid] once their passcode, if they have one, says it's them.
/// The one way to switch kid, from this screen and from the profile menu.
Future<void> enterAs(BuildContext context, WidgetRef ref, PairedKid kid) async {
  final ok = await confirmItsMe(
    context,
    ref,
    kid,
    classroom: ref.read(sessionControllerProvider).isClassroom,
  );
  if (ok == null || !context.mounted) return;
  await ref
      .read(sessionControllerProvider.notifier)
      .switchTo(kid.id, accessToken: ok.accessToken, expiresIn: ok.expiresIn);
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.tileKey,
    required this.onTap,
    required this.label,
    required this.child,
    required this.width,
    this.highlighted = false,
  });

  final Key tileKey;
  final VoidCallback onTap;
  final String label;
  final Widget child;
  final double width;
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
            width: width,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: Space.md,
                horizontal: Space.sm,
              ),
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

/// One paired kid's tile: their avatar and name. Also the launch screen's
/// picker when several kids share the device.
class KidProfileTile extends ConsumerWidget {
  const KidProfileTile({
    required this.kid,
    required this.onTap,
    this.current = false,
    this.avatarSize = 92,
    super.key,
  });

  final PairedKid kid;
  final bool current;
  final VoidCallback onTap;
  final double avatarSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key =
        ref.watch(kidAvatarKeyProvider(kid.id)).value ?? defaultAvatarKey;
    return _Tile(
      tileKey: ValueKey('who-kid-${kid.id}'),
      onTap: onTap,
      label: kid.displayName,
      highlighted: current,
      width: avatarSize + 58,
      child: KidAvatar(avatarKey: key, size: avatarSize),
    );
  }
}

/// "Ajouter un profil": opens the pairing-code screen.
class AddProfileTile extends StatelessWidget {
  const AddProfileTile({required this.onTap, this.avatarSize = 92, super.key});

  final VoidCallback onTap;
  final double avatarSize;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    return _Tile(
      tileKey: const ValueKey('who-add'),
      onTap: onTap,
      label: context.s.addProfile,
      width: avatarSize + 58,
      child: Container(
        width: avatarSize,
        height: avatarSize,
        decoration: BoxDecoration(shape: BoxShape.circle, color: p.track),
        child: Icon(
          Icons.add_rounded,
          size: avatarSize * 0.48,
          color: p.quebecBlue,
        ),
      ),
    );
  }
}
