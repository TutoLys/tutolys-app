import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/strings.dart';
import '../../core/widgets/kid_avatar.dart';
import '../../data/local_db/session_store.dart';
import '../pairing/who_is_playing_screen.dart' show kidAvatarKeyProvider;
import '../profile/avatars.dart' show defaultAvatarKey;
import '../profile/pin_gate.dart';
import '../../data/api/passcode_api.dart';
import 'passcode_setup_screen.dart';
import 'passcode_pictures.dart';
import 'passcode_service.dart';
import 'picture_pad.dart';

/// Before playing as [kid] from "Qui joue ?": their picture passcode, when
/// they have one.
///
/// Returns how it went, or null when the child said "Ce n'est pas moi" and
/// went back to the picker. A kid with no passcode passes straight through,
/// with no screen at all, except on a class tablet ([classroom]), where a
/// passcode is required: there, a kid without one waits for an adult to
/// set it (`PasscodeWaitingScreen`), and nobody plays until then.
Future<PasscodeAccepted?> confirmItsMe(
  BuildContext context,
  WidgetRef ref,
  PairedKid kid, {
  bool classroom = false,
}) async {
  final service = ref.read(passcodeServiceProvider);
  var required = await service.isRequired(kid.id);
  if (!required && classroom) {
    // Maybe set in the portal since the last sync: ask before saying no.
    required = await service.refresh(kid.id) is HasPasscode;
    if (!required) {
      if (!context.mounted) return null;
      final setNow = await Navigator.of(context)
          .push<bool>(_route(context, PasscodeWaitingScreen(kid: kid)));
      if (setNow != true) return null;
      required = true;
    }
  }
  if (!required) return const PasscodeAccepted();
  if (!context.mounted) return null;
  return Navigator.of(context)
      .push<PasscodeAccepted>(_route(context, PasscodeEntryScreen(kid: kid)));
}

PageRoute<T> _route<T>(BuildContext context, Widget page) {
  final still = MediaQuery.disableAnimationsOf(context);
  return PageRouteBuilder<T>(
    fullscreenDialog: true,
    transitionDuration: still ? Duration.zero : Motion.normal,
    reverseTransitionDuration: still ? Duration.zero : Motion.quick,
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (_, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

/// "C'est toi, Léa ?": the kid taps their three pictures, in order.
///
/// Framed as choosing who you are, never as logging in: no lock, no red,
/// no count of tries left. "Ce n'est pas moi" is always on screen and
/// always goes back to the picker.
class PasscodeEntryScreen extends ConsumerStatefulWidget {
  const PasscodeEntryScreen({required this.kid, super.key});

  final PairedKid kid;

  @override
  ConsumerState<PasscodeEntryScreen> createState() =>
      _PasscodeEntryScreenState();
}

class _PasscodeEntryScreenState extends ConsumerState<PasscodeEntryScreen> {
  final _picked = <int>[];
  String? _message;
  int _errorTick = 0;
  bool _checking = false;

  Future<void> _pick(int index) async {
    setState(() {
      _picked.add(index);
      _message = null;
    });
    if (_picked.length < passcodeLength) return;

    setState(() => _checking = true);
    final result = await ref
        .read(passcodeServiceProvider)
        .check(widget.kid.id, List.of(_picked));
    if (!mounted) return;
    final s = context.s;
    switch (result) {
      case PasscodeAccepted():
        Navigator.of(context).pop(result);
      case PasscodeRejected():
        setState(() {
          _picked.clear();
          _checking = false;
          _errorTick++;
          _message = s.passcodeWrong;
        });
      case PasscodeTooManyTries():
        setState(() {
          _picked.clear();
          _checking = false;
          _message = s.passcodeTooMany;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final p = VillagePalette.of(context);
    final avatar =
        ref.watch(kidAvatarKeyProvider(widget.kid.id)).value ??
        defaultAvatarKey;

    return _Sky(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          KidAvatar(avatarKey: avatar, size: 84),
          const SizedBox(height: Space.sm),
          Text(
            s.passcodeIsItYou(widget.kid.displayName),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: VillageType.display,
              fontWeight: FontWeight.w800,
              fontSize: 26,
              color: p.ink,
            ),
          ),
          const SizedBox(height: Space.xxs),
          Text(
            s.passcodePrompt,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: VillageType.display,
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: p.inkMuted,
            ),
          ),
          const SizedBox(height: Space.lg),
          PicturePad(
            picked: _picked,
            errorTick: _errorTick,
            enabled: !_checking,
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

/// A class tablet, and [kid] has no picture code yet: they wait for an
/// adult. "Je suis l'adulte" opens the setup behind the guardian PIN, and
/// the screen pops with `true` once a code is saved, so the kid goes on to
/// tap it. Back, or "Ce n'est pas moi", pops with nothing.
class PasscodeWaitingScreen extends ConsumerWidget {
  const PasscodeWaitingScreen({required this.kid, super.key});

  final PairedKid kid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.s;
    final p = VillagePalette.of(context);
    final avatar =
        ref.watch(kidAvatarKeyProvider(kid.id)).value ?? defaultAvatarKey;

    Future<void> adult() async {
      final allowed = await requireGuardianPin(
        context,
        ref,
        confirmLabel: s.pinGateContinue,
        createSubtitle: s.passcodesPinCreate,
        enterSubtitle: s.passcodesPinEnter,
      );
      if (!allowed || !context.mounted) return;
      await Navigator.of(context)
          .push<void>(_route(context, PasscodeSetupScreen(kid: kid)));
      if (!context.mounted) return;
      if (await ref.read(passcodeServiceProvider).isRequired(kid.id)) {
        if (context.mounted) Navigator.of(context).pop(true);
      }
    }

    return _Sky(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          KidAvatar(avatarKey: avatar, size: 84),
          const SizedBox(height: Space.sm),
          Text(
            s.passcodeWaitTitle(kid.displayName),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: VillageType.display,
              fontWeight: FontWeight.w800,
              fontSize: 24,
              color: p.ink,
            ),
          ),
          const SizedBox(height: Space.xs),
          Text(
            s.passcodeWaitBody,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: VillageType.display,
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: p.inkMuted,
            ),
          ),
          const SizedBox(height: Space.xl),
          OutlinedButton.icon(
            key: const ValueKey('passcode-wait-adult'),
            onPressed: adult,
            icon: const Icon(Icons.lock_open_rounded),
            label: Text(s.passcodeWaitAdult),
            style: OutlinedButton.styleFrom(
              foregroundColor: p.quebecBlue,
              side: BorderSide(color: p.line, width: 2),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(
                horizontal: Space.lg,
                vertical: Space.sm,
              ),
              textStyle: const TextStyle(
                fontFamily: VillageType.display,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The sky page both kid-facing passcode screens sit on, with "Ce n'est
/// pas moi" in the corner.
class _Sky extends StatelessWidget {
  const _Sky({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
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
          child: Stack(
            children: [
              Positioned(
                top: Space.sm,
                left: Space.sm,
                child: TextButton.icon(
                  key: const ValueKey('passcode-not-me'),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: Text(
                    s.notMe,
                    style: const TextStyle(
                      fontFamily: VillageType.display,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: TextButton.styleFrom(foregroundColor: p.ink),
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    Space.md,
                    Space.xxl + Space.md,
                    Space.md,
                    Space.lg,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: child,
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

/// The line under the pad: amber, never red (the design never uses red),
/// and announced to a screen reader as it appears. Holds its height when
/// empty so the pad doesn't jump.
class PasscodeMessage extends StatelessWidget {
  const PasscodeMessage({required this.message, super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    return SizedBox(
      height: 44,
      child: message == null
          ? null
          : Semantics(
              liveRegion: true,
              child: Text(
                message!,
                key: const ValueKey('passcode-message'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: VillageType.display,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: p.retry,
                ),
              ),
            ),
    );
  }
}
