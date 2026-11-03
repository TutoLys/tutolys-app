import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/strings.dart';
import '../../core/widgets/kid_avatar.dart';
import '../../data/local_db/session_store.dart';
import '../profile/avatars.dart';
import 'pairing_controller.dart';
import 'who_is_playing_screen.dart';

/// What the kid chose. The menu closes first and the caller acts on this
/// from its own context, because a passcode screen outlives the menu.
sealed class _Choice {
  const _Choice();
}

class _PlayAs extends _Choice {
  const _PlayAs(this.kid);
  final PairedKid kid;
}

class _AddProfile extends _Choice {
  const _AddProfile();
}

/// The profile menu (ADR 0123): the header's avatar opens it, and one tap
/// plays as another kid. "Qui joue ?" stays for launch and for when the
/// app must ask who's there.
///
/// Under [anchor] on a tablet or desktop, over it when the anchor sits low.
/// A bottom sheet on a phone, like the bell's panel. Switching goes through
/// [enterAs], the picker's own path, so a passcode gates both.
Future<void> showProfileMenu(
  BuildContext context,
  WidgetRef ref, {
  required Rect anchor,
}) async {
  final phone = MediaQuery.sizeOf(context).width < Breakpoints.compact;
  final still = MediaQuery.disableAnimationsOf(context);
  final p = VillagePalette.of(context);

  final choice = phone
      ? await showModalBottomSheet<_Choice>(
          context: context,
          useRootNavigator: true,
          isScrollControlled: true,
          backgroundColor: p.surface,
          showDragHandle: true,
          sheetAnimationStyle: still ? AnimationStyle.noAnimation : null,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.7,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (context) => SafeArea(child: _menu(context)),
        )
      : await showGeneralDialog<_Choice>(
          context: context,
          useRootNavigator: true,
          barrierDismissible: true,
          barrierLabel: MaterialLocalizations.of(context)
              .modalBarrierDismissLabel,
          barrierColor: Colors.transparent,
          transitionDuration: still ? Duration.zero : Motion.quick,
          pageBuilder: (context, _, _) =>
              _AnchoredCard(anchor: anchor, child: _menu(context)),
          transitionBuilder: (context, animation, _, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Motion.enter,
              reverseCurve: Motion.exit,
            );
            return FadeTransition(
              opacity: curved,
              child: ScaleTransition(
                scale: Tween(begin: 0.92, end: 1.0).animate(curved),
                // Grows out of the avatar.
                alignment: FractionalOffset.fromOffsetAndRect(
                  anchor.centerLeft,
                  Offset.zero & MediaQuery.sizeOf(context),
                ),
                child: child,
              ),
            );
          },
        );

  if (!context.mounted) return;
  final session = ref.read(sessionControllerProvider.notifier);
  switch (choice) {
    case _PlayAs(:final kid):
      await enterAs(context, ref, kid);
    case _AddProfile():
      session.addProfile(fromApp: true);
    case null:
      break;
  }
}

Widget _menu(BuildContext context) => ProfileMenu(
  onPlayAs: (kid) => Navigator.of(context).pop(_PlayAs(kid)),
  onAdd: () => Navigator.of(context).pop(const _AddProfile()),
  onStay: () => Navigator.of(context).pop(),
);

/// The card, placed against [anchor] and kept on screen.
class _AnchoredCard extends StatelessWidget {
  const _AnchoredCard({required this.anchor, required this.child});

  static const _width = 300.0;
  static const _gap = Space.xs;
  static const _margin = Space.md;

  final Rect anchor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    final screen = MediaQuery.sizeOf(context);
    final below = anchor.center.dy < screen.height / 2;
    final room = below
        ? screen.height - anchor.bottom - _gap - _margin
        : anchor.top - _gap - _margin;
    final left = anchor.left.clamp(
      _margin,
      (screen.width - _width - _margin).clamp(_margin, double.infinity),
    );
    return Stack(
      children: [
        Positioned(
          left: left,
          top: below ? anchor.bottom + _gap : null,
          bottom: below ? null : screen.height - anchor.top + _gap,
          width: _width,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: room),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: p.shadow,
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: Material(
                color: p.surface,
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                child: child,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The list itself: every kid paired here, then "Ajouter un profil".
class ProfileMenu extends ConsumerWidget {
  const ProfileMenu({
    required this.onPlayAs,
    required this.onAdd,
    required this.onStay,
    super.key,
  });

  final ValueChanged<PairedKid> onPlayAs;
  final VoidCallback onAdd;

  /// The kid already playing was tapped: nothing to switch.
  final VoidCallback onStay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.s;
    final p = VillagePalette.of(context);
    final session = ref.watch(sessionControllerProvider);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: t.switchProfile,
      child: Shortcuts(
        // Web maps the arrows to scrolling, so say it here.
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.arrowDown): NextFocusIntent(),
          SingleActivator(LogicalKeyboardKey.arrowUp): PreviousFocusIntent(),
        },
        child: FocusTraversalGroup(
          child: ListView(
            key: const ValueKey('profile-menu'),
            shrinkWrap: true,
            padding: const EdgeInsets.all(Space.xs),
            children: [
              for (final kid in session.kids)
                _KidRow(
                  kid: kid,
                  current: kid.id == session.kid?.id,
                  // A class tablet asks even the kid already playing.
                  onTap: kid.id == session.kid?.id && !session.mustConfirm
                      ? onStay
                      : () => onPlayAs(kid),
                ),
              // Not on a class tablet: the school decides who is on it.
              if (!session.isClassroom) ...[
                Divider(height: Space.md, color: p.line),
                _Row(
                  rowKey: const ValueKey('profile-menu-add'),
                  label: t.addProfile,
                  onTap: onAdd,
                  child: Row(
                    children: [
                      Container(
                        width: _avatar,
                        height: _avatar,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: p.track,
                        ),
                        child: Icon(
                          Icons.add_rounded,
                          size: 24,
                          color: p.quebecBlueBright,
                        ),
                      ),
                      const SizedBox(width: Space.sm),
                      Expanded(
                        child: Text(
                          t.addProfile,
                          style: TextStyle(
                            fontFamily: VillageType.display,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: p.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

const _avatar = 44.0;

class _KidRow extends ConsumerWidget {
  const _KidRow({
    required this.kid,
    required this.current,
    required this.onTap,
  });

  final PairedKid kid;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.s;
    final p = VillagePalette.of(context);
    final grade = t.gradeLabel(kid.gradeLevel);
    final avatar =
        ref.watch(kidAvatarKeyProvider(kid.id)).value ?? defaultAvatarKey;
    return _Row(
      rowKey: ValueKey('profile-menu-kid-${kid.id}'),
      label: '${kid.displayName}, $grade',
      selected: current,
      autofocus: current,
      onTap: onTap,
      child: Row(
        children: [
          KidAvatar(avatarKey: avatar, size: _avatar),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kid.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: VillageType.display,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: p.ink,
                  ),
                ),
                Text(
                  grade,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: p.inkMuted),
                ),
              ],
            ),
          ),
          if (current)
            Icon(
              Icons.check_circle_rounded,
              key: const ValueKey('profile-menu-current'),
              size: 22,
              color: p.quebecBlueBright,
            ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.rowKey,
    required this.label,
    required this.onTap,
    required this.child,
    this.selected = false,
    this.autofocus = false,
  });

  final Key rowKey;
  final String label;
  final VoidCallback onTap;
  final Widget child;
  final bool selected;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: Material(
          color: selected ? p.navActiveFill : Colors.transparent,
          borderRadius: VillageMetrics.mdAll,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: rowKey,
            autofocus: autofocus,
            hoverColor: p.navHoverFill,
            focusColor: p.navHoverFill,
            onTap: onTap,
            child: ExcludeSemantics(
              child: ConstrainedBox(
                // A six-year-old's finger.
                constraints: const BoxConstraints(minHeight: 60),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Space.xs,
                    vertical: Space.xs,
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
