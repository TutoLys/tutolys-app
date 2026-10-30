import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'shell_strings.dart';

enum ShellFeedbackKind { correct, retry, neutral }

/// Text and icons on a bright accent (VALIDER's gold, the banner's
/// amber/green), in both themes: at least 6.2:1 on each, where white
/// reached only 2.2–2.8:1 (UX review G1).
const onAccentInk = Color(0xFF241A04);

/// The feedback banner's height with a two-line message, kept free under
/// the board while it shows.
const bannerRoom = 112.0;

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
    this.progressCount,
    this.xp,
    this.inARow = 0,
    this.promptText,
    this.promptImageRef,
    this.instruction,
    this.onSpeak,
    this.character,
    this.revealedHint,
    this.onHint,
    this.offerHint = false,
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

  /// « 2 / 6 », drawn beside the track so a child sees what's left (UX
  /// review N1).
  final String? progressCount;

  /// XP earned so far this activity; null hides the pill.
  final int? xp;

  /// Consecutive first-try answers. The label shows from 2.
  final int inARow;

  /// Null when the engine renders its own prompt (the legacy path).
  final String? promptText;

  /// The prompt's picture (`prompt.image_ref`), drawn above the question.
  /// Nothing is drawn until it has synced: the question still reads
  /// without it, because content never puts the question only in a
  /// picture.
  final String? promptImageRef;

  /// How to play this kind of board, for a game a child can't guess from
  /// the screen (UX review G3). Drawn with a hand icon, never read aloud
  /// unasked; the engines also show the move with an idle hand.
  final String? instruction;

  /// Null hides the speaker: there's nothing that may be read aloud.
  final VoidCallback? onSpeak;

  final Widget? character;

  /// The hint, once the child asked for it.
  final String? revealedHint;

  /// Null hides INDICE (no hint, hints off, or already revealed).
  final VoidCallback? onHint;

  /// After a couple of misses, INDICE is offered: drawn in gold, with a
  /// hint for a screen reader (UX review G8).
  final bool offerHint;

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

    // The design floats the mascot beside the content (`.mascot-hint` is
    // absolutely positioned), never as a row of its own: a row cost a
    // fixed-height legacy engine 72px it didn't have on a short window. So
    // it sits beside the prompt — or, when the engine draws its own prompt
    // (the legacy path), small in the top bar.
    final hasPrompt = promptText != null || onSpeak != null;
    final header = <Widget>[
      if (promptImageRef != null)
        Padding(
          padding: const EdgeInsets.only(bottom: Space.md),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180, maxWidth: 360),
              child: ContentImage(
                key: const ValueKey('prompt-image'),
                ref: promptImageRef!,
                fallback: const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      if (hasPrompt)
        _PromptRow(
          palette: p,
          strings: s,
          text: promptText,
          onSpeak: onSpeak,
          character: character,
        ),
      if (instruction != null)
        Padding(
          padding: const EdgeInsets.only(bottom: Space.md),
          child: Row(
            key: const ValueKey('shell-instruction'),
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.touch_app_rounded, color: p.ink, size: 20),
              const SizedBox(width: Space.xs),
              Flexible(
                child: Text(
                  instruction!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: p.ink,
                  ),
                ),
              ),
            ],
          ),
        ),

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

    // While an activity is on screen the audio output stays awake, so the
    // first read-aloud after a quiet moment isn't clipped (ADR 0043).
    return AudioOutputKeepAliveScope(
      // Enter validates (or acts on the banner) only when nothing inside
      // has focus. A focused tile or button keeps Enter for itself, so a
      // keyboard user can pick an option with it (UX review G6).
      child: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent ||
              (event.logicalKey != LogicalKeyboardKey.enter &&
                  event.logicalKey != LogicalKeyboardKey.numpadEnter) ||
              !node.hasPrimaryFocus) {
            return KeyEventResult.ignored;
          }
          final f = feedback;
          if (f != null) {
            f.onAction();
          } else {
            onValidate?.call();
          }
          return KeyEventResult.handled;
        },
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
                  progressCount: progressCount,
                  xp: xp,
                  inARow: inARow,
                  character: hasPrompt ? null : character,
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Padding(
                          // Room under the board for the banner, so it
                          // never hides a tile (UX review G9).
                          padding: EdgeInsets.fromLTRB(
                            compact ? Space.md : Space.xxl,
                            compact ? Space.lg : 36,
                            compact ? Space.md : Space.xxl,
                            (compact ? Space.lg : 36) +
                                (feedback != null ? bannerRoom : 0),
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
                // The hint opens here, above the buttons, not above the
                // board: inserting it there pushed the tiles down under
                // the child's finger (UX review N3).
                if (feedback == null &&
                    (showValidate || onHint != null || revealedHint != null))
                  _BottomBar(
                    revealedHint: revealedHint,
                    palette: p,
                    strings: s,
                    gutter: gutter,
                    compact: compact,
                    onHint: onHint,
                    offerHint: offerHint,
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
    required this.progressCount,
    required this.xp,
    required this.inARow,
    required this.character,
  });

  final VillagePalette palette;
  final ShellStrings strings;
  final double gutter;
  final VoidCallback onClose;
  final Widget? character;
  final double? progress;
  final String? progressLabel;
  final String? progressCount;
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
          if (character != null)
            SizedBox.square(dimension: 52, child: FittedBox(child: character)),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 14,
                  // 12 px, deep green and an icon (UX review G16): 10 px
                  // success green was 2.8:1 on white.
                  child: inARow >= 2
                      ? Row(
                          key: const ValueKey('in-a-row'),
                          children: [
                            Icon(
                              Icons.bolt_rounded,
                              size: 14,
                              color: p.isDark
                                  ? p.success
                                  : const Color(0xFF1C7A4C),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              strings.inARow(inARow).toUpperCase(),
                              style: TextStyle(
                                fontSize: 12,
                                height: 1,
                                fontWeight: FontWeight.w800,
                                letterSpacing: .5,
                                color: p.isDark
                                    ? p.success
                                    : const Color(0xFF1C7A4C),
                              ),
                            ),
                          ],
                        )
                      : null,
                ),
                if (progress != null)
                  Semantics(
                    label: progressLabel,
                    value: '${(progress!.clamp(0, 1) * 100).round()} %',
                    // An outlined track (3:1) shows the whole way even
                    // at 0 %, where only the gold fill drew before (N1).
                    // Full width: in this start-aligned column the track's
                    // Stack had nothing to size it and shrank to 0 px.
                    child: SizedBox(
                      width: double.infinity,
                      child: DecoratedBox(
                        key: const ValueKey('progress-track'),
                        position: DecorationPosition.foreground,
                        decoration: BoxDecoration(
                          borderRadius: Radii.pillAll,
                          border: Border.all(color: p.inkMuted, width: 1.5),
                        ),
                        child: ClipRRect(
                          borderRadius: Radii.pillAll,
                          child: SizedBox(
                            height: 10,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: ColoredBox(color: p.track),
                                ),
                                FractionallySizedBox(
                                  // Full height: a childless box in a Stack is otherwise
                                  // sized to zero, and the fill never shows.
                                  heightFactor: 1,
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
                    ),
                  ),
                const SizedBox(height: 14),
              ],
            ),
          ),
          if (progressCount != null) ...[
            const SizedBox(width: Space.sm),
            ExcludeSemantics(
              // The track's own semantics already say « Question 2 sur 6 ».
              child: Text(
                progressCount!,
                key: const ValueKey('progress-count'),
                style: TextStyle(
                  fontFamily: VillageType.display,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: p.ink,
                ),
              ),
            ),
          ],
          if (xp != null) ...[
            const SizedBox(width: Space.md),
            Icon(Icons.star_rounded, color: p.gold, size: 18),
            const SizedBox(width: 4),
            // A little pop when XP arrives; a plain swap when motion is
            // reduced.
            AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 380),
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: TweenSequence<double>([
                  TweenSequenceItem(
                    tween: Tween(begin: 0.6, end: 1.35),
                    weight: 60,
                  ),
                  TweenSequenceItem(
                    tween: Tween(begin: 1.35, end: 1),
                    weight: 40,
                  ),
                ]).animate(animation),
                child: child,
              ),
              child: Text(
                strings.xp(xp!),
                key: ValueKey(xp),
                style: TextStyle(
                  fontFamily: VillageType.display,
                  fontWeight: FontWeight.w800,
                  color: p.ink,
                ),
              ),
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
    required this.character,
  });

  final VillagePalette palette;
  final ShellStrings strings;
  final String? text;
  final VoidCallback? onSpeak;
  final Widget? character;

  @override
  // A fixed column, left-aligned: the fox and the speaker stay at the
  // same place from one question to the next, whatever the prompt's
  // length (UX review N2). It was centred on the text, so they moved.
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Center(
      child: ConstrainedBox(
        key: const ValueKey('prompt-row'),
        constraints: const BoxConstraints(maxWidth: 640),
        child: Row(
          // Top-aligned: a prompt wrapping to two lines doesn't move them
          // down either.
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (character != null) ...[character!, const SizedBox(width: 14)],
            // 56 dp, solid bright blue: the one control a non-reader needs to
            // find (UX review G10, the design's `.exo-listen-btn`).
            if (onSpeak != null)
              IconButton.filled(
                key: const ValueKey('prompt-speak'),
                onPressed: onSpeak,
                tooltip: strings.listen,
                iconSize: 28,
                constraints: const BoxConstraints.tightFor(
                  width: 56,
                  height: 56,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: palette.quebecBlueBright,
                  // White reads on the light blue (4.6:1), dark ink on the
                  // dark theme's brighter blue (5.9:1).
                  foregroundColor: palette.isDark
                      ? const Color(0xFF0D1526)
                      : Colors.white,
                ),
                icon: const Icon(Icons.volume_up_rounded),
              ),
            if (onSpeak != null && text != null) const SizedBox(width: 14),
            if (text != null)
              Expanded(
                // Lines a one-line prompt up with the 56 dp speaker's middle.
                child: Padding(
                  padding: EdgeInsets.only(top: onSpeak != null ? 12 : 0),
                  child: Text(
                    text!,
                    style: TextStyle(
                      fontFamily: VillageType.display,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: palette.ink,
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
          // The design's sparkle, in a colour that reads on the gold
          // ground (UX review G18): gold on gold-pale was 1.7:1.
          Icon(
            Icons.auto_awesome_rounded,
            color: palette.isDark ? palette.gold : const Color(0xFF9A4A0C),
            size: 18,
          ),
          const SizedBox(width: Space.xs),
          Flexible(
            child: Text(text, style: TextStyle(color: palette.ink)),
          ),
        ],
      ),
    ),
  );
}

class _BottomBar extends StatefulWidget {
  const _BottomBar({
    required this.palette,
    required this.strings,
    required this.gutter,
    required this.compact,
    required this.onHint,
    required this.offerHint,
    required this.revealedHint,
    required this.showValidate,
    required this.onValidate,
  });

  final bool offerHint;
  final String? revealedHint;
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
  State<_BottomBar> createState() => _BottomBarState();
}

/// VALIDER before there's an answer still answers a tap: it says what's
/// missing for a few seconds, instead of doing nothing (UX review G2).
class _BottomBarState extends State<_BottomBar> {
  Timer? _nudge;

  @override
  void didUpdateWidget(_BottomBar old) {
    super.didUpdateWidget(old);
    if (widget.onValidate != null) _clearNudge();
  }

  void _clearNudge() {
    _nudge?.cancel();
    _nudge = null;
  }

  void _showNudge() {
    _nudge?.cancel();
    setState(() {
      _nudge = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(_clearNudge);
      });
    });
  }

  @override
  void dispose() {
    _nudge?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final strings = widget.strings;
    final gutter = widget.gutter;
    final compact = widget.compact;
    final onHint = widget.onHint;
    final offerHint = widget.offerHint;
    final showValidate = widget.showValidate;
    final onValidate = widget.onValidate;
    final active = onValidate != null;
    final nudging = _nudge != null && !active;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: gutter, vertical: Space.md),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: p.line)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (widget.revealedHint case final hint?)
            Align(
              alignment: Alignment.centerLeft,
              child: _HintPanel(palette: p, text: hint),
            ),
          if (nudging)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: Semantics(
                liveRegion: true,
                child: Container(
                  key: const ValueKey('validate-nudge'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: Space.md,
                    vertical: Space.sm,
                  ),
                  decoration: BoxDecoration(
                    color: p.goldPale,
                    borderRadius: Radii.cardMd,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.touch_app_rounded, color: p.ink, size: 22),
                      const SizedBox(width: Space.xs),
                      Flexible(
                        child: Text(
                          strings.answerFirst,
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
              ),
            ),
          _row(
            p,
            strings,
            compact,
            onHint,
            offerHint,
            showValidate,
            onValidate,
            active,
          ),
        ],
      ),
    );
  }

  Widget _row(
    VillagePalette p,
    ShellStrings strings,
    bool compact,
    VoidCallback? onHint,
    bool offerHint,
    bool showValidate,
    VoidCallback? onValidate,
    bool active,
  ) => ConstrainedBox(
    // One height with or without INDICE, so VALIDER never moves (N2).
    constraints: const BoxConstraints(minHeight: 52),
    child: Row(
      // INDICE left, VALIDER right (the design's `.exo-bottombar`),
      // each allowed to shrink on a narrow screen.
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (onHint != null)
          Flexible(
            child: OutlinedButton.icon(
              key: const ValueKey('hint'),
              onPressed: onHint,
              icon: const Icon(Icons.lightbulb_outline_rounded, size: 15),
              // Inside the button, so it lands on the button's own node.
              label: Semantics(
                hint: offerHint ? strings.hintOffered : null,
                child: Text(
                  strings.hint.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              style: OutlinedButton.styleFrom(
                // Offered after misses: gold, so it catches the eye.
                backgroundColor: offerHint ? p.goldPale : null,
                foregroundColor: offerHint ? p.ink : p.inkMuted,
                side: BorderSide(color: offerHint ? p.gold : p.line, width: 2),
                shape: const StadiumBorder(),
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 12 : 18,
                  vertical: 11,
                ),
              ),
            ),
          )
        else
          // Holds the left slot so a lone VALIDER still sits on the right.
          const SizedBox.shrink(),
        if (showValidate)
          Flexible(
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
                key: const ValueKey('validate'),
                onPressed: onValidate ?? _showNudge,
                style: TextButton.styleFrom(
                  // Grey ground, but text that still reads (it was
                  // inkMuted on track, 2.9:1).
                  foregroundColor: active ? onAccentInk : p.ink,
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 22 : 38,
                    vertical: 14,
                  ),
                  shape: const RoundedRectangleBorder(
                    borderRadius: Radii.cardMd,
                  ),
                ),
                // Inside the button, so it merges into the button's own
                // node: a screen reader hears what's missing.
                child: Semantics(
                  hint: active ? null : strings.answerFirst,
                  child: Text(
                    strings.validate.toUpperCase(),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: VillageType.display,
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
              child: Icon(icon, color: onAccentInk, size: 22),
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
                      fontFamily: VillageType.display,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: p.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    feedback.message,
                    style: TextStyle(fontSize: 14, color: p.ink),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Space.md),
            FilledButton(
              onPressed: feedback.onAction,
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: onAccentInk,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: Text(
                feedback.actionLabel.toUpperCase(),
                style: const TextStyle(
                  fontFamily: VillageType.display,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
