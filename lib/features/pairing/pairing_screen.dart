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
class PairingScreen extends ConsumerStatefulWidget {
  const PairingScreen({super.key});

  @override
  ConsumerState<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends ConsumerState<PairingScreen> {
  String _code = '';

  /// Mirrors the server's alphabet. Characters outside it never appear, so a
  /// mistyped `O` or `1` is visibly ignored rather than silently "fixed".
  static const _alphabet = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
  static const _codeLength = 6;

  bool get _isComplete => _code.length == _codeLength;

  Future<void> _submit() async {
    if (!_isComplete) return;
    await ref.read(pairingFormProvider.notifier).submit(_code);
  }

  MascotMood _moodFor(PairingUiState ui) {
    if (ui.isSubmitting) return MascotMood.thinking;
    if (ui.error != null) return MascotMood.incorrect;
    if (_isComplete) return MascotMood.celebrating;
    return MascotMood.idle;
  }

  String? _errorText(PairingUiState ui, Strings s) {
    return switch (ui.error) {
      PairingError.invalidCode => s.pairingCodeInvalid,
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
    );

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Padding(
              padding: const EdgeInsets.all(Space.lg),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < Breakpoints.compact;
                  final mascot = _Mascot(
                    mood: _moodFor(ui),
                    size: stacked ? 108 : 168,
                  );

                  if (stacked) {
                    return SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          mascot,
                          const SizedBox(height: Space.lg),
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
      child: TutolysMascot(mood: mood, size: size),
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

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final extras = context.extras;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(s.pairingTitle, style: context.text.displaySmall),
        const SizedBox(height: Space.xs),
        Text(
          s.pairingSubtitle,
          style: context.text.bodyLarge?.copyWith(color: extras.mutedText),
        ),
        const SizedBox(height: Space.xl),

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
          height: 44,
          child: AnimatedSwitcher(
            duration: Motion.quick,
            child: errorText != null
                ? Row(
                    key: const ValueKey('error'),
                    children: [
                      Icon(Icons.error_outline, color: extras.danger, size: 20),
                      const SizedBox(width: Space.xs),
                      Expanded(
                        child: Text(
                          errorText!,
                          style: context.text.bodyMedium
                              ?.copyWith(color: extras.danger),
                        ),
                      ),
                    ],
                  )
                : Text(
                    s.pairingHint,
                    key: const ValueKey('hint'),
                    style: context.text.bodyMedium
                        ?.copyWith(color: extras.mutedText),
                  ),
          ),
        ),

        const SizedBox(height: Space.sm),

        FilledButton(
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
              : Text(s.pairingConnect),
        ),
      ],
    );
  }
}
