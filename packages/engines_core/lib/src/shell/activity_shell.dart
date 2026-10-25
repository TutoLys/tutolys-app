import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'shell_strings.dart';

enum ShellFeedbackKind { correct, retry, neutral }

/// The banner after VALIDER.
class ShellFeedback {
  const ShellFeedback({
    required this.kind,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final ShellFeedbackKind kind;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;
}

/// The chrome every exercise shares: close, progress, XP, prompt and
/// speaker, character, hint, VALIDER and the feedback banner
/// (`03-exercise-engines.html`, `.exo-*`).
///
/// Presentation only. It holds no session state and knows no engine: the
/// host hands it values and callbacks, and [body] is the engine's own
/// question area. A change to the speaker button or the banner here lands
/// on every engine at once.
///
/// Every state reads without colour: the banner carries an icon and words,
/// VALIDER says it's disabled through semantics, not just grey.
class ActivityShell extends StatelessWidget {
  const ActivityShell({
    required this.locale,
    required this.onClose,
    required this.body,
    this.progress,
    this.progressLabel,
    this.xp,
    this.inARow = 0,
    this.promptText,
    this.onSpeak,
    this.character,
    this.revealedHint,
    this.onHint,
    this.onValidate,
    this.showValidate = false,
    this.feedback,
    this.notice,
    this.scrollBody = true,
    super.key,
  });

  final Locale locale;
  final VoidCallback onClose;

  /// The engine's interactive area.
  final Widget body;

  /// 0..1; null hides the track (a legacy engine reports no progress).
  final double? progress;
  final String? progressLabel;

  /// XP earned so far this activity; null hides the pill.
  final int? xp;

  /// Consecutive first-try answers. The label shows from 2.
  final int inARow;

  /// Null when the engine renders its own prompt (the legacy path).
  final String? promptText;

  /// Null hides the speaker: there's nothing that may be read aloud.
  final VoidCallback? onSpeak;

  final Widget? character;

  /// The hint, once the child asked for it.
  final String? revealedHint;

  /// Null hides INDICE (no hint, hints off, or already revealed).
  final VoidCallback? onHint;

  /// Null with [showValidate] true = VALIDER shown but disabled.
  final VoidCallback? onValidate;
  final bool showValidate;
  final ShellFeedback? feedback;

  /// A one-line problem the child should know about (an answer that
  /// couldn't be saved).
  final String? notice;

  /// False for a [body] that lays itself out to fill the space it's given
  /// (the legacy `ExerciseRunner`, built for an `Expanded`), rather than
  /// scrolling with the prompt above it.
  final bool scrollBody;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    final s = ShellStrings.of(locale);
    final compact = MediaQuery.sizeOf(context).width < Breakpoints.compact;
    final gutter = compact ? Space.md : 28.0;

    final header = <Widget>[
      if (character != null)
        Align(alignment: Alignment.centerLeft, child: character),
      if (promptText != null || onSpeak != null)
        _PromptRow(palette: p, strings: s, text: promptText, onSpeak: onSpeak),
      if (revealedHint != null) _HintPanel(palette: p, text: revealedHint!),
      if (notice != null)
        Padding(
          padding: const EdgeInsets.only(bottom: Space.sm),
          child: Semantics(
            liveRegion: true,
            child: Text(
              notice!,
              style: TextStyle(color: p.retry, fontWeight: FontWeight.w700),
            ),
          ),
        ),
    ];

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter): () {
          final f = feedback;
          if (f != null) {
            f.onAction();
          } else {
            onValidate?.call();
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: Material(
          color: p.surface,
          child: SafeArea(
            child: Column(
              children: [
                _TopBar(
                  palette: p,
                  strings: s,
                  gutter: gutter,
                  onClose: onClose,
                  progress: progress,
                  progressLabel: progressLabel,
                  xp: xp,
                  inARow: inARow,
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: compact ? Space.md : Space.xxl,
                            vertical: compact ? Space.lg : 36,
                          ),
                          child: scrollBody
                              ? SingleChildScrollView(
                                  child: Column(children: [...header, body]),
                                )
                              : Column(
                                  children: [
                                    ...header,
                                    Expanded(child: body),
                                  ],
                                ),
                        ),
                      ),
                      if (feedback != null)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: _FeedbackBanner(
                            palette: p,
                            gutter: gutter,
                            feedback: feedback!,
                          ),
                        ),
                    ],
                  ),
                ),
                if (feedback == null && (showValidate || onHint != null))
                  _BottomBar(
                    palette: p,
                    strings: s,
                    gutter: gutter,
                    compact: compact,
                    onHint: onHint,
                    showValidate: showValidate,
                    onValidate: onValidate,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.palette,
    required this.strings,
    required this.gutter,
    required this.onClose,
    required this.progress,
    required this.progressLabel,
    required this.xp,
    required this.inARow,
  });

  final VillagePalette palette;
  final ShellStrings strings;
  final double gutter;
  final VoidCallback onClose;
  final double? progress;
  final String? progressLabel;
  final int? xp;
  final int inARow;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Container(
      height: 68,
      padding: EdgeInsets.symmetric(horizontal: gutter),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.line)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            tooltip: strings.close,
            icon: Icon(Icons.close_rounded, color: p.inkMuted, size: 20),
          ),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 14,
                  child: inARow >= 2
                      ? Text(
                          strings.inARow(inARow).toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .5,
                            color: p.success,
                          ),
                        )
                      : null,
                ),
                if (progress != null)
                  Semantics(
                    label: progressLabel,
                    value: '${(progress!.clamp(0, 1) * 100).round()} %',
                    child: ClipRRect(
                      borderRadius: Radii.pillAll,
                      child: SizedBox(
                        height: 10,
                        child: Stack(
                          children: [
                            Positioned.fill(child: ColoredBox(color: p.track)),
                            FractionallySizedBox(
                              widthFactor: progress!.clamp(0, 1).toDouble(),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [p.goldLight, p.gold],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
              ],
            ),
          ),
          if (xp != null) ...[
            const SizedBox(width: Space.md),
            Icon(Icons.star_rounded, color: p.gold, size: 18),
            const SizedBox(width: 4),
            Text(
              strings.xp(xp!),
              style: TextStyle(fontWeight: FontWeight.w700, color: p.ink),
            ),
          ],
        ],
      ),
    );
  }
}

class _PromptRow extends StatelessWidget {
  const _PromptRow({
    required this.palette,
    required this.strings,
    required this.text,
    required this.onSpeak,
  });

  final VillagePalette palette;
  final ShellStrings strings;
  final String? text;
  final VoidCallback? onSpeak;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (onSpeak != null)
          IconButton.filledTonal(
            onPressed: onSpeak,
            tooltip: strings.listen,
            icon: const Icon(Icons.volume_up_rounded),
          ),
        if (onSpeak != null && text != null) const SizedBox(width: 14),
        if (text != null)
          Flexible(
            child: Text(
              text!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: palette.ink,
              ),
            ),
          ),
      ],
    ),
  );
}

class _HintPanel extends StatelessWidget {
  const _HintPanel({required this.palette, required this.text});
  final VillagePalette palette;
  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      margin: const EdgeInsets.only(bottom: Space.md),
      padding: const EdgeInsets.symmetric(
        horizontal: Space.md,
        vertical: Space.sm,
      ),
      decoration: BoxDecoration(
        color: palette.goldPale,
        borderRadius: Radii.cardMd,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lightbulb_outline_rounded, color: palette.gold, size: 18),
          const SizedBox(width: Space.xs),
          Flexible(
            child: Text(text, style: TextStyle(color: palette.ink)),
          ),
        ],
      ),
    ),
  );
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.palette,
    required this.strings,
    required this.gutter,
    required this.compact,
    required this.onHint,
    required this.showValidate,
    required this.onValidate,
  });

  final VillagePalette palette;
  final ShellStrings strings;
  final double gutter;

  /// Phone width: the design's 38px VALIDER padding doesn't fit beside
  /// INDICE at 360px with large text, so both tighten and may shrink.
  final bool compact;
  final VoidCallback? onHint;
  final bool showValidate;
  final VoidCallback? onValidate;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final active = onValidate != null;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: gutter, vertical: Space.md),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: p.line)),
      ),
      child: Row(
        children: [
          if (onHint != null)
            Flexible(
              child: OutlinedButton.icon(
                onPressed: onHint,
                icon: const Icon(Icons.lightbulb_outline_rounded, size: 15),
                label: Text(
                  strings.hint.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: p.inkMuted,
                  side: BorderSide(color: p.line, width: 2),
                  shape: const StadiumBorder(),
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 12 : 18,
                    vertical: 11,
                  ),
                ),
              ),
            ),
          const Spacer(),
          if (showValidate)
            Flexible(
              child: Semantics(
                button: true,
                enabled: active,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: Radii.cardMd,
                    gradient: active
                        ? LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [p.goldLight, p.gold],
                          )
                        : null,
                    color: active ? null : p.track,
                  ),
                  child: TextButton(
                    onPressed: onValidate,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF241A04),
                      disabledForegroundColor: p.inkMuted,
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 22 : 38,
                        vertical: 14,
                      ),
                      shape: const RoundedRectangleBorder(
                        borderRadius: Radii.cardMd,
                      ),
                    ),
                    child: Text(
                      strings.validate.toUpperCase(),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        letterSpacing: .4,
                      ),
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

class _FeedbackBanner extends StatelessWidget {
  const _FeedbackBanner({
    required this.palette,
    required this.gutter,
    required this.feedback,
  });
  final VillagePalette palette;
  final double gutter;
  final ShellFeedback feedback;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final (ground, accent, icon) = switch (feedback.kind) {
      ShellFeedbackKind.correct => (
        p.successPale,
        p.success,
        Icons.check_rounded,
      ),
      // Amber and a target, never red and an X (the design's Decision Log).
      ShellFeedbackKind.retry => (
        p.retryPale,
        p.retry,
        Icons.track_changes_rounded,
      ),
      ShellFeedbackKind.neutral => (
        p.goldPale,
        p.gold,
        Icons.arrow_forward_rounded,
      ),
    };
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: gutter, vertical: 20),
        decoration: BoxDecoration(
          color: ground,
          border: Border(top: BorderSide(color: accent, width: 2)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 21,
              backgroundColor: accent,
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    feedback.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: p.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    feedback.message,
                    style: TextStyle(fontSize: 12, color: p.inkMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Space.md),
            FilledButton(
              onPressed: feedback.onAction,
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: Text(
                feedback.actionLabel.toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
