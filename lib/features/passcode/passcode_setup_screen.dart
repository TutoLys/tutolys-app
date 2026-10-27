import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/strings.dart';
import '../../core/widgets/kid_avatar.dart';
import '../../data/local_db/session_store.dart';
import '../pairing/pairing_controller.dart';
import '../pairing/who_is_playing_screen.dart' show kidAvatarKeyProvider;
import '../profile/avatars.dart' show defaultAvatarKey;
import '../profile/pin_gate.dart';
import 'passcode_entry_screen.dart' show PasscodeMessage;
import 'passcode_pictures.dart';
import 'passcode_service.dart';
import 'picture_pad.dart';

/// Réglages → "Codes images", behind the guardian PIN.
Future<void> openPasscodes(BuildContext context, WidgetRef ref) async {
  final s = context.s;
  final allowed = await requireGuardianPin(
    context,
    ref,
    confirmLabel: s.pinGateContinue,
    createSubtitle: s.passcodesPinCreate,
    enterSubtitle: s.passcodesPinEnter,
  );
  if (!allowed || !context.mounted) return;
  // Over the whole shell, nav included: Réglages sits in the paired
  // shell's own navigator.
  await Navigator.of(context, rootNavigator: true).push<void>(
    _route(context, const PasscodesScreen()),
  );
}

PageRoute<T> _route<T>(BuildContext context, Widget page) {
  final still = MediaQuery.disableAnimationsOf(context);
  return PageRouteBuilder<T>(
    transitionDuration: still ? Duration.zero : Motion.normal,
    reverseTransitionDuration: still ? Duration.zero : Motion.quick,
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (_, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

/// Every kid paired on this device, and whether each has a picture code.
///
/// Each kid's code is set with *their own* credential, so a guardian can
/// set every sibling's from here without switching to them.
class PasscodesScreen extends ConsumerWidget {
  const PasscodesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.s;
    final p = VillagePalette.of(context);
    final kids = ref.watch(sessionControllerProvider).kids;

    return _Page(
      title: s.passcodesTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            s.passcodesBody,
            style: TextStyle(
              fontFamily: VillageType.display,
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: p.inkMuted,
            ),
          ),
          const SizedBox(height: Space.lg),
          for (final kid in kids) ...[
            _KidRow(kid: kid),
            const SizedBox(height: Space.sm),
          ],
        ],
      ),
    );
  }
}

class _KidRow extends ConsumerWidget {
  const _KidRow({required this.kid});

  final PairedKid kid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.s;
    final p = VillagePalette.of(context);
    final avatar =
        ref.watch(kidAvatarKeyProvider(kid.id)).value ?? defaultAvatarKey;
    final hasCode = ref.watch(kidHasPasscodeProvider(kid.id)).value;

    Future<void> remove() async {
      final ok = await ref.read(passcodeServiceProvider).clear(kid.id);
      ref.invalidate(kidHasPasscodeProvider(kid.id));
      if (context.mounted) {
        VillageToast.show(
          context,
          ok ? s.passcodeRemoved : s.passcodeNeedsInternet,
        );
      }
    }

    return Material(
      color: p.surface,
      borderRadius: VillageMetrics.mdAll,
      elevation: VillageColors.elevationSmall,
      shadowColor: p.shadowSmall,
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Row(
          children: [
            KidAvatar(avatarKey: avatar, size: 48),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kid.displayName,
                    style: TextStyle(
                      fontFamily: VillageType.display,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: p.ink,
                    ),
                  ),
                  if (hasCode != null)
                    Text(
                      hasCode ? s.passcodeIsSet : s.passcodeNotSet,
                      key: ValueKey('passcode-state-${kid.id}'),
                      style: TextStyle(
                        fontFamily: VillageType.display,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: hasCode ? p.success : p.inkMuted,
                      ),
                    ),
                ],
              ),
            ),
            if (hasCode ?? false)
              TextButton(
                key: ValueKey('passcode-remove-${kid.id}'),
                onPressed: remove,
                style: TextButton.styleFrom(foregroundColor: p.inkMuted),
                child: Text(s.passcodeRemove),
              ),
            FilledButton(
              key: ValueKey('passcode-set-${kid.id}'),
              style: FilledButton.styleFrom(
                backgroundColor: p.quebecBlue,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(
                  fontFamily: VillageType.display,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: () async {
                await Navigator.of(context).push<void>(
                  _route(context, PasscodeSetupScreen(kid: kid)),
                );
                ref.invalidate(kidHasPasscodeProvider(kid.id));
              },
              child: Text(
                (hasCode ?? false) ? s.passcodeChange : s.passcodeChoose,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A guardian chooses [kid]'s three pictures, then taps them again to
/// confirm. Saved on the server, since a code only this device knew would
/// be asked for here and nowhere else.
class PasscodeSetupScreen extends ConsumerStatefulWidget {
  const PasscodeSetupScreen({required this.kid, super.key});

  final PairedKid kid;

  @override
  ConsumerState<PasscodeSetupScreen> createState() =>
      _PasscodeSetupScreenState();
}

class _PasscodeSetupScreenState extends ConsumerState<PasscodeSetupScreen> {
  final _picked = <int>[];
  List<int>? _first;
  String? _message;
  int _errorTick = 0;
  bool _saving = false;

  Future<void> _pick(int index) async {
    setState(() {
      _picked.add(index);
      _message = null;
    });
    if (_picked.length < passcodeLength) return;
    final s = context.s;

    final first = _first;
    if (first == null) {
      setState(() {
        _first = List.of(_picked);
        _picked.clear();
      });
      return;
    }
    if (!_same(first, _picked)) {
      setState(() {
        _first = null;
        _picked.clear();
        _errorTick++;
        _message = s.passcodeSetupMismatch;
      });
      return;
    }

    setState(() => _saving = true);
    final saved = await ref
        .read(passcodeServiceProvider)
        .save(widget.kid.id, first);
    if (!mounted) return;
    if (saved) {
      VillageToast.show(context, s.passcodeSaved);
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _saving = false;
      _first = null;
      _picked.clear();
      _message = s.passcodeNeedsInternet;
    });
  }

  static bool _same(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final p = VillagePalette.of(context);
    return _Page(
      title: s.passcodeSetupTitle(widget.kid.displayName),
      child: Column(
        children: [
          Text(
            _first == null ? s.passcodeSetupPick : s.passcodeSetupConfirm,
            key: const ValueKey('passcode-setup-step'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: VillageType.display,
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: p.ink,
            ),
          ),
          const SizedBox(height: Space.lg),
          PicturePad(
            picked: _picked,
            errorTick: _errorTick,
            enabled: !_saving,
            onPick: _pick,
            onUndo: () => setState(() {
              _picked.removeLast();
              _message = null;
            }),
          ),
          const SizedBox(height: Space.md),
          PasscodeMessage(message: _message),
        ],
      ),
    );
  }
}

/// A plain page on the sky, with a back button and a title.
class _Page extends StatelessWidget {
  const _Page({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Space.md),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        key: const ValueKey('passcode-back'),
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: Text(context.s.addProfileCancel),
                        style: TextButton.styleFrom(foregroundColor: p.ink),
                      ),
                    ),
                    const SizedBox(height: Space.sm),
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: VillageType.display,
                        fontWeight: FontWeight.w800,
                        fontSize: 26,
                        color: p.ink,
                      ),
                    ),
                    const SizedBox(height: Space.md),
                    child,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
