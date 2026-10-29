import 'dart:async';
import 'dart:math' as math;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/strings.dart';
import '../../data/local_db/session_store.dart';
import '../pairing/pairing_controller.dart' show sessionStoreProvider;

/// Gate before "sign out this device": requires a parent-set PIN.
///
/// Deliberately not a security boundary (see `SessionStore.setGuardianPin`)
/// — a determined kid could still ask an adult. It exists to stop a casual
/// tap from signing the device out, which otherwise costs a guardian a
/// full re-pair. The first time this runs on a device, there's no PIN to
/// check yet, so creating one *is* the gate.
///
/// A PIN is 6 digits. One set when it was 4 still opens the gate, and the
/// guardian then chooses a 6-digit one before the action goes ahead. If
/// they back out of that, the old PIN is left as it was, so nobody is ever
/// locked out (ADR 0010, 2026-10-26 revision).
///
/// The dialogs' wording defaults to sign-out's. Another action passes its
/// own [confirmLabel] (the entry button) and subtitles for creating
/// ([createSubtitle]) and entering ([enterSubtitle]) the PIN. Returns
/// whether the caller may proceed.
Future<bool> requireGuardianPin(
  BuildContext context,
  WidgetRef ref, {
  String? confirmLabel,
  String? createSubtitle,
  String? enterSubtitle,
}) async {
  final store = ref.read(sessionStoreProvider);
  final digits = await store.guardianPinDigits();
  if (!context.mounted) return false;

  if (digits == null) {
    // A5: whoever taps first must not become "the parent". An adult check
    // stands in front of creating the PIN; at pairing, when an adult is
    // certainly there, it is offered without one
    // (offerGuardianPinAfterPairing).
    final adult =
        await showDialog<bool>(
          context: context,
          builder: (context) =>
              _AdultCheckDialog(facts: ref.read(adultCheckFactsProvider)()),
        ) ??
        false;
    if (!adult || !context.mounted) return false;
    return await showDialog<bool>(
          context: context,
          builder: (context) =>
              _CreatePinDialog(store: store, subtitle: createSubtitle),
        ) ??
        false;
  }

  final entered = await showDialog<bool>(
    context: context,
    builder: (context) => _EnterPinDialog(
      store: store,
      digits: digits,
      confirmLabel: confirmLabel,
      subtitle: enterSubtitle,
    ),
  );
  if (entered != true) return false;
  if (digits == SessionStore.guardianPinLength) return true;
  if (!context.mounted) return false;

  return await showDialog<bool>(
        context: context,
        builder: (context) => _CreatePinDialog(store: store, upgrade: true),
      ) ??
      false;
}

/// Right after a kid's pairing, the adult who typed the portal's code is
/// certainly there: they're offered the parent PIN, in "vous" (A5). "Plus
/// tard" leaves it for later, behind the adult check.
Future<void> offerGuardianPinAfterPairing(
  BuildContext context,
  WidgetRef ref,
) async {
  final store = ref.read(sessionStoreProvider);
  if (await store.hasGuardianPin() || !context.mounted) return;
  await showDialog<bool>(
    context: context,
    builder: (context) => _CreatePinDialog(
      store: store,
      subtitle: context.s.pinGateAfterPairing,
      cancelLabel: context.s.later,
    ),
  );
}

/// The two factors the adult check asks to multiply. Random, so it can't
/// be learned; a test pins it.
final adultCheckFactsProvider = Provider<(int, int) Function()>((ref) {
  final random = math.Random();
  return () => (6 + random.nextInt(4), 6 + random.nextInt(4));
});

/// "Zone adulte": a multiplication a grade-1 child can't do, before a PIN
/// can be created anywhere but at pairing (A5). Friction, not security,
/// like the PIN itself.
class _AdultCheckDialog extends StatefulWidget {
  const _AdultCheckDialog({required this.facts});

  final (int, int) facts;

  @override
  State<_AdultCheckDialog> createState() => _AdultCheckDialogState();
}

class _AdultCheckDialogState extends State<_AdultCheckDialog> {
  final _answer = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  void _submit() {
    final (a, b) = widget.facts;
    if (int.tryParse(_answer.text) == a * b) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _error = context.s.adultCheckWrong;
      _answer.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final (a, b) = widget.facts;
    return _PinDialogFrame(
      key: const ValueKey('adult-check'),
      title: s.adultCheckTitle,
      subtitle: s.adultCheckSubtitle(a, b),
      error: _error,
      busy: false,
      primaryLabel: s.pinGateContinue,
      onPrimary: _submit,
      fields: [
        _PinField(
          controller: _answer,
          label: s.adultCheckLabel,
          digits: 2,
          autofocus: true,
          obscure: false,
          onSubmitted: _submit,
        ),
      ],
    );
  }
}

class _CreatePinDialog extends StatefulWidget {
  const _CreatePinDialog({
    required this.store,
    this.upgrade = false,
    this.subtitle,
    this.cancelLabel,
  });

  final SessionStore store;
  final String? subtitle;
  final String? cancelLabel;

  /// Replacing a 4-digit PIN rather than setting the first one.
  final bool upgrade;

  @override
  State<_CreatePinDialog> createState() => _CreatePinDialogState();
}

class _CreatePinDialogState extends State<_CreatePinDialog> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final s = context.s;
    const length = SessionStore.guardianPinLength;
    if (_pinController.text.length != length ||
        _confirmController.text.length != length) {
      setState(() => _error = s.pinGateTooShort(length));
      return;
    }
    if (_pinController.text != _confirmController.text) {
      setState(() => _error = s.pinGateMismatch);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    await widget.store.setGuardianPin(_pinController.text);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return _PinDialogFrame(
      title: widget.upgrade ? s.pinGateUpgradeTitle : s.pinGateCreateTitle,
      subtitle: widget.upgrade
          ? s.pinGateUpgradeSubtitle
          : widget.subtitle ?? s.pinGateCreateSubtitle,
      error: _error,
      busy: _submitting,
      primaryLabel: s.pinGateCreate,
      onPrimary: _submit,
      cancelLabel: widget.cancelLabel,
      fields: [
        _PinField(
          controller: _pinController,
          label: s.pinGatePinLabel(SessionStore.guardianPinLength),
          digits: SessionStore.guardianPinLength,
          autofocus: true,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: Space.xs),
        _PinField(
          controller: _confirmController,
          label: s.pinGateConfirmPinLabel,
          digits: SessionStore.guardianPinLength,
          onSubmitted: _submit,
        ),
      ],
    );
  }
}

class _EnterPinDialog extends StatefulWidget {
  const _EnterPinDialog({
    required this.store,
    required this.digits,
    this.confirmLabel,
    this.subtitle,
  });

  final SessionStore store;
  final String? confirmLabel;
  final String? subtitle;

  /// Digits in the stored PIN: 6, or 4 for one set before the change.
  final int digits;

  @override
  State<_EnterPinDialog> createState() => _EnterPinDialogState();
}

class _EnterPinDialogState extends State<_EnterPinDialog> {
  final _pinController = TextEditingController();
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _unlock?.cancel();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final s = context.s;
    if (_lockedUntil != null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    final correct = await widget.store.verifyGuardianPin(_pinController.text);
    if (!mounted) return;

    if (correct) {
      Navigator.of(context).pop(true);
      return;
    }
    final until = await widget.store.guardianPinLockedUntil();
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _lockedUntil = until;
      _error = until == null
          ? s.pinGateWrong
          : s.pinGateLocked(_secondsLeft(until));
      _pinController.clear();
    });
    _scheduleUnlock();
  }

  /// When the gate opens again after too many wrong PINs (A5).
  DateTime? _lockedUntil;
  Timer? _unlock;

  int _secondsLeft(DateTime until) =>
      until.difference(DateTime.now()).inSeconds.clamp(1, 900);

  void _scheduleUnlock() {
    _unlock?.cancel();
    final until = _lockedUntil;
    if (until == null) return;
    _unlock = Timer(until.difference(DateTime.now()), () {
      if (mounted) {
        setState(() {
          _lockedUntil = null;
          _error = null;
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    widget.store.guardianPinLockedUntil().then((until) {
      if (!mounted || until == null) return;
      setState(() {
        _lockedUntil = until;
        _error = context.s.pinGateLocked(_secondsLeft(until));
      });
      _scheduleUnlock();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return _PinDialogFrame(
      title: s.pinGateEnterTitle,
      subtitle: widget.subtitle ?? s.pinGateEnterSubtitle,
      error: _error,
      busy: _submitting,
      primaryLabel: widget.confirmLabel ?? s.pinGateConfirmSignOut,
      onPrimary: _submit,
      locked: _lockedUntil != null,
      fields: [
        _PinField(
          controller: _pinController,
          label: s.pinGatePinLabel(widget.digits),
          digits: widget.digits,
          autofocus: true,
          onSubmitted: _submit,
        ),
      ],
    );
  }
}

/// The design's modal card (`.streak-modal`: surface, 24px corners, the
/// navy shadow, at most 380 wide) with a Baloo 2 title, a muted subtitle,
/// the fields, then cancel and a gold pill.
class _PinDialogFrame extends StatelessWidget {
  const _PinDialogFrame({
    required this.title,
    required this.subtitle,
    required this.fields,
    required this.primaryLabel,
    required this.onPrimary,
    required this.busy,
    this.error,
    this.cancelLabel,
    this.locked = false,
    super.key,
  });

  final String? cancelLabel;

  /// Waiting after too many wrong PINs: the primary button is off.

  final String title;
  final String subtitle;
  final List<Widget> fields;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final bool busy;
  final bool locked;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    return Dialog(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      elevation: VillageColors.elevationSmall,
      shadowColor: p.shadow,
      insetPadding: const EdgeInsets.all(Space.md),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            Space.lg,
            Space.lg,
            Space.lg,
            Space.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: p.navActiveFill,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_outline_rounded,
                      size: 20,
                      color: p.quebecBlue,
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontFamily: VillageType.display,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        color: p.ink,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.sm),
              Text(
                subtitle,
                style: TextStyle(fontSize: 14, height: 1.4, color: p.inkMuted),
              ),
              const SizedBox(height: Space.md),
              ...fields,
              if (error != null) ...[
                const SizedBox(height: Space.xs),
                Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 18, color: p.retry),
                    const SizedBox(width: Space.xs),
                    Expanded(
                      child: Text(
                        error!,
                        style: TextStyle(
                          fontFamily: VillageType.display,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: p.retry,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: Space.md),
              // Wraps rather than overflows when a label is long
              // ("DÉCONNECTER") or the screen narrow.
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: Space.xs,
                runSpacing: Space.xs,
                children: [
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: p.inkMuted,
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      textStyle: const TextStyle(
                        fontFamily: VillageType.display,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onPressed: busy
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: Text(cancelLabel ?? context.s.cancel),
                  ),
                  _GoldPillButton(
                    key: const ValueKey('pin-gate-primary'),
                    label: primaryLabel,
                    onPressed: busy || locked ? null : onPrimary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Digits only, hidden, the numeric keyboard on touch, and a 0/6 counter.
class _PinField extends StatelessWidget {
  const _PinField({
    required this.controller,
    required this.label,
    required this.digits,
    this.autofocus = false,
    this.textInputAction = TextInputAction.done,
    this.onSubmitted,
    this.obscure = true,
  });

  final bool obscure;
  final TextEditingController controller;
  final String label;
  final int digits;
  final bool autofocus;
  final TextInputAction textInputAction;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: VillageMetrics.mdAll,
      borderSide: BorderSide(color: color, width: width),
    );
    return TextField(
      controller: controller,
      autofocus: autofocus,
      obscureText: obscure,
      keyboardType: TextInputType.number,
      textInputAction: textInputAction,
      autocorrect: false,
      enableSuggestions: false,
      maxLength: digits,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(digits),
      ],
      onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
      style: TextStyle(
        fontFamily: VillageType.display,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: 6,
        color: p.ink,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontFamily: VillageType.display,
          fontWeight: FontWeight.w600,
          color: p.inkMuted,
        ),
        floatingLabelStyle: TextStyle(
          fontFamily: VillageType.display,
          fontWeight: FontWeight.w700,
          color: p.quebecBlueBright,
        ),
        counterStyle: TextStyle(fontSize: 12, color: p.inkMuted),
        filled: true,
        fillColor: p.navHoverFill,
        enabledBorder: border(p.line, 1.5),
        focusedBorder: border(p.quebecBlueBright, 2),
        border: border(p.line, 1.5),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Space.md,
          vertical: Space.sm,
        ),
      ),
    );
  }
}

/// `.btn-gold`: the gold gradient pill with dark ink and Baloo 2 caps.
class _GoldPillButton extends StatelessWidget {
  const _GoldPillButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: Radii.pillAll,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [p.goldLight, p.gold],
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onPressed,
            borderRadius: Radii.pillAll,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    label.toUpperCase(),
                    semanticsLabel: label,
                    style: const TextStyle(
                      fontFamily: VillageType.display,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                      color: Color(0xFF241A04),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
