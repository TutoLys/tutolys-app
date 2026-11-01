import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/strings.dart';
import 'pairing_controller.dart';

/// The first screen a kid ever sees.
///
/// Design intent:
///
/// - One job on screen. No navigation, no settings, no account talk — the kid
///   has a code and needs to get in.
/// - The mascot carries the emotional state, so the error text can stay short.
///   A child reads a face faster than a sentence.
/// - Errors are specific. "No internet" and "wrong code" are different
///   problems, and conflating them has a kid retyping a code that was fine.
/// - One widget tree, two layouts. Wide screens put the fox beside the form;
///   narrow screens stack. Logic is never forked (plan §6.3).
///
/// [onCancel] makes it the "add a profile" screen, opened from "Qui joue ?"
/// on a device that already has a kid: a back button appears, and the
/// subtitle says a parent's code adds a child rather than signing in.
///
/// "Ajouter une classe" switches it to a teacher's class code, which pairs
/// a shared tablet for the whole class at once (O8). Same six characters,
/// same field: only the words and the endpoint change.
class PairingScreen extends ConsumerStatefulWidget {
  const PairingScreen({this.onCancel, super.key});

  final VoidCallback? onCancel;

  @override
  ConsumerState<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends ConsumerState<PairingScreen> {
  String _code = '';

  /// A teacher's class code rather than a kid's pairing code.
  bool _classMode = false;

  /// Mirrors the server's alphabet. Characters outside it never appear, so a
  /// mistyped `O` or `1` is visibly ignored rather than silently "fixed".
  static const _alphabet = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
  static const _codeLength = 6;

  bool get _isComplete => _code.length == _codeLength;

  /// Below this window height the logo and title step aside, as they do for
  /// a keyboard inset.
  static const shortWindow = 600.0;

  Future<void> _submit() async {
    if (!_isComplete) return;
    final form = ref.read(pairingFormProvider.notifier);
    await (_classMode ? form.submitClass(_code) : form.submit(_code));
  }

  MascotMood _moodFor(PairingUiState ui) {
    if (ui.isSubmitting) return MascotMood.thinking;
    if (ui.error != null) return MascotMood.incorrect;
    if (_isComplete) return MascotMood.celebrating;
    return MascotMood.idle;
  }

  String? _errorText(PairingUiState ui, Strings s) {
    return switch (ui.error) {
      PairingError.invalidCode =>
        _classMode ? s.pairingClassInvalid : s.pairingCodeInvalid,
      PairingError.emptyClass => s.pairingClassEmpty,
      PairingError.classNotEntitled => s.pairingClassNotEntitled,
      PairingError.noSeat => s.pairingNoSeat,
      PairingError.offline => s.pairingOffline,
      // Shown in the kid's own terms: a child does not need to hear the words
      // "rate limit", only that waiting is the fix.
      PairingError.rateLimited => s.pairingUnexpectedError,
      PairingError.unexpected => s.pairingUnexpectedError,
      null => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final ui = ref.watch(pairingFormProvider);
    final s = context.s;
    final error = _errorText(ui, s);
    // Read above the Scaffold, which hides the inset from its body. With
    // the keyboard up, the logo and « Salut ! » step aside so the code
    // boxes and the button stay above it (AM22).
    // A phone browser often shrinks the window for its keyboard instead of
    // reporting an inset, so a short window counts too: 375×476 hid
    // « Ajouter » below the fold (AM17 verify).
    final height = MediaQuery.sizeOf(context).height;
    final keyboard =
        MediaQuery.viewInsetsOf(context).bottom > 0 ||
        (height > 0 && height < shortWindow);

    final form = _PairingForm(
      alphabet: _alphabet,
      codeLength: _codeLength,
      isSubmitting: ui.isSubmitting,
      hasError: ui.error != null,
      errorText: error,
      canSubmit: _isComplete && !ui.isSubmitting,
      onChanged: (value) {
        setState(() => _code = value);
        if (ui.error != null) {
          ref.read(pairingFormProvider.notifier).clearError();
        }
      },
      onCompleted: (_) => _submit(),
      onSubmit: _submit,
      showTitle: !keyboard,
      title: _classMode ? s.pairingClassTitle : null,
      // Adding a profile, the subtitle already says to ask a parent, so the
      // hint would say it twice (AM17).
      hint: _classMode || widget.onCancel != null ? null : s.pairingHint,
      submitLabel: _classMode || widget.onCancel != null
          ? s.pairingAdd
          : s.pairingConnect,
      subtitle: _classMode
          ? s.pairingClassSubtitle
          : widget.onCancel == null
              ? null
              : s.addProfileHint,
      footer: TextButton.icon(
        key: const ValueKey('pairing-mode'),
        onPressed: ui.isSubmitting
            ? null
            : () {
                setState(() => _classMode = !_classMode);
                ref.read(pairingFormProvider.notifier).clearError();
              },
        icon: Icon(
          _classMode ? Icons.person_add_alt_1_rounded : Icons.groups_rounded,
        ),
        label: Text(_classMode ? s.pairingKidLink : s.pairingClassLink),
      ),
    );

    return Scaffold(
      appBar: widget.onCancel == null
          ? null
          : AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                key: const ValueKey('pairing-cancel'),
                tooltip: s.addProfileCancel,
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: widget.onCancel,
              ),
            ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Padding(
              padding: const EdgeInsets.all(Space.lg),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final stacked =
                      keyboard || constraints.maxWidth < Breakpoints.compact;
                  final mascot = _Mascot(
                    mood: _moodFor(ui),
                    size: stacked ? 108 : 168,
                  );

                  if (stacked) {
                    return SingleChildScrollView(
                      key: const ValueKey('pairing-scroll'),
                      // Anchored to the bottom while the keyboard is up, so
                      // the button sits just above it rather than under it.
                      reverse: keyboard,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (!keyboard) ...[
                            mascot,
                            const SizedBox(height: Space.lg),
                          ],
                          form,
                        ],
                      ),
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: Center(child: mascot)),
                      const SizedBox(width: Space.xl),
                      Expanded(flex: 2, child: form),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Mascot extends StatelessWidget {
  const _Mascot({required this.mood, required this.size});

  final MascotMood mood;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            colors.primary.withValues(alpha: 0.22),
            colors.primary.withValues(alpha: 0.0),
          ],
        ),
      ),
      // The real brand mark, not the hand-drawn `TutolysMascot` placeholder
      // this screen carried since A2. `mood` is still computed above and
      // still drives the copy; it just no longer drives a drawing, because
      // there is one pose and a static illustration cannot act.
      child: Image.asset(
        'assets/images/asset-logo.webp',
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  }
}

class _PairingForm extends StatelessWidget {
  const _PairingForm({
    required this.alphabet,
    required this.codeLength,
    required this.isSubmitting,
    required this.hasError,
    required this.errorText,
    required this.canSubmit,
    required this.onChanged,
    required this.onCompleted,
    required this.onSubmit,
    this.showTitle = true,
    this.title,
    this.subtitle,
    this.hint,
    this.footer,
    required this.submitLabel,
  });

  final String alphabet;
  final int codeLength;
  final bool isSubmitting;
  final bool hasError;
  final String? errorText;
  final bool canSubmit;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onCompleted;
  final VoidCallback onSubmit;

  /// False while the keyboard is up (AM22): the subtitle still says what
  /// to type, and the boxes keep the room.
  final bool showTitle;

  /// Replace the default title and subtitle: adding a profile, or a class.
  final String? title;
  final String? subtitle;

  /// Under the code, until there's an error. None for a class code: the
  /// subtitle already says the teacher shows it, and "ask the person in
  /// charge of your account" is a family's hint.
  final String? hint;

  /// Under the button: the switch between a kid's code and a class code.
  final Widget? footer;

  /// « Se connecter » on first launch, « Ajouter » when adding (AM17).
  final String submitLabel;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final extras = context.extras;

    // One centred column, exactly as wide as the row of code boxes at full
    // size: title, boxes, hint and button share one axis and one width, so
    // the eye runs straight down to the button. Left-aligned headings over
    // centred boxes over a wider button gave three edges and no line.
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth:
              codeLength * TutolysCodeField.maxBoxWidth +
              (codeLength - 1) * Space.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showTitle) ...[
              Text(
                title ?? s.pairingTitle,
                textAlign: TextAlign.center,
                // The design's display face, like every other title.
                style: context.text.displaySmall?.copyWith(
                  fontFamily: VillageType.display,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: Space.xs),
            ],
            Text(
              subtitle ?? s.pairingSubtitle,
              textAlign: TextAlign.center,
              style: context.text.bodyLarge?.copyWith(color: extras.mutedText),
            ),
            SizedBox(height: showTitle ? Space.xl : Space.md),

            TutolysCodeField(
              length: codeLength,
              alphabet: alphabet,
              enabled: !isSubmitting,
              hasError: hasError,
              onChanged: onChanged,
              onCompleted: onCompleted,
            ),

            const SizedBox(height: Space.md),

            // Reserve the message row's height so the layout does not jump when an
            // error appears — movement under a child's finger loses their place.
            SizedBox(
              // Two lines of hint or error, so the longer wording never pushes
              // the button down under a child's finger.
              height: 48,
              child: AnimatedSwitcher(
                duration: Motion.quick,
                child: errorText != null
                    ? Row(
                        key: const ValueKey('error'),
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Icon(
                              Icons.error_outline,
                              color: VillagePalette.of(context).retry,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: Space.xs),
                          Flexible(
                            child: Text(
                              errorText!,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              style: context.text.bodyMedium?.copyWith(
                                color: VillagePalette.of(context).retry,
                              ),
                            ),
                          ),
                        ],
                      )
                    : hint == null
                    ? const SizedBox.shrink(key: ValueKey('hint'))
                    : Text(
                        hint!,
                        key: const ValueKey('hint'),
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        style: context.text.bodyMedium?.copyWith(
                          color: extras.mutedText,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: Space.sm),

            FilledButton(
              key: const ValueKey('pairing-submit'),
              onPressed: canSubmit ? onSubmit : null,
              child: isSubmitting
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                        const SizedBox(width: Space.sm),
                        Text(s.pairingConnecting),
                      ],
                    )
                  : Text(submitLabel),
            ),
            if (footer != null) ...[
              const SizedBox(height: Space.sm),
              footer!,
            ],
          ],
        ),
      ),
    );
  }
}
