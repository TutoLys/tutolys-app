import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'swatch_text.dart';

/// What an answer tile shows about itself.
enum AnswerTileState {
  idle,

  /// The current choice, not yet checked.
  picked,

  /// Tried and found not right — stays visible so the child doesn't try it
  /// again, and stays amber, never red (the design's Decision Log).
  retry,

  /// The verdict was right.
  correct,
}

/// One answer option, as the design draws it (`03-exercise-engines.html`,
/// `.cloze-option-row`).
///
/// Shared by every engine that offers choices, so a style change happens
/// once. Presentation only: what a tap *means* belongs to the engine.
///
/// Every state reads without colour — `retry` and `correct` carry an icon
/// and a semantics hint — and the tile is focusable and activates with
/// Enter or Space like any button.
class AnswerTile extends StatelessWidget {
  const AnswerTile({
    required this.label,
    required this.state,
    required this.onTap,
    this.semanticsState,
    this.badge,
    this.imageRef,
    this.dense = false,
    this.large = false,
    this.prominent = false,
    this.square = false,
    this.audioRef,
    super.key,
  });

  final String label;
  final AnswerTileState state;

  /// Null disables the tile (already tried, or not the child's turn).
  final VoidCallback? onTap;

  /// Spoken after the label for [AnswerTileState.retry] and
  /// [AnswerTileState.correct] — e.g. "déjà essayé".
  final String? semanticsState;

  /// A small number drawn on the tile — which pair a matched tile belongs
  /// to (`pair_match`), so two linked tiles read as a pair without lines.
  final int? badge;

  /// A picture for this answer (`image_ref`), drawn before the label in a
  /// 56px box. The label stays: it is the screen-reader name, and the text
  /// a child sees until the picture has synced (when nothing is drawn in
  /// its place, so the tile never shows an empty frame).
  final String? imageRef;

  /// For a narrow slot (a number on a number line): the label centred,
  /// the state icon under it rather than beside, almost no padding. Every
  /// state still reads without colour.
  final bool dense;

  /// The design's big cards (`.match-card`, 96 px): for boards a child
  /// taps by sight, pair_match and compose_build's tray (UX review G14).
  /// 88 dp tall (72 at phone width, as the design's compact card), with
  /// a bigger label.
  final bool large;

  /// The answer list of a choice question (mcq, speed_tap): the label
  /// centred and big, 24 px when it's short (UX review AM3: 15 px labels,
  /// left-aligned in 343 px tiles, read smaller than the question).
  final bool prominent;

  /// One of a row of short answers (« 3 », « 20 °C »): a big square tile,
  /// the label centred at 30 px and the state icon under it (UX review
  /// AM3). The parent sizes the square.
  final bool square;

  /// A recording of [label] (`audio_ref`), for a child who can't read it
  /// yet. Played only when asked: the small speaker on the tile, or a long
  /// press. A plain tap still just chooses, so answers are never read
  /// aloud by default (Hafid's rule). Nothing is drawn when the host has no
  /// [ContentSpeakerScope].
  final String? audioRef;

  Widget _dense(Color text, IconData? icon, Color border) => Padding(
    padding: square
        ? const EdgeInsets.all(8)
        : const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Square: scaled down rather than cut when a label is wider than
        // the tile.
        _maybeFit(
          SwatchText(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              fontFamily: VillageType.display,
              fontWeight: square ? FontWeight.w800 : FontWeight.w700,
              fontSize: !square
                  ? 15
                  : _pictureOnly(label)
                  ? 44
                  : 30,
              color: text,
            ),
          ),
        ),
        if (icon != null) Icon(icon, size: square ? 22 : 12, color: border),
      ],
    ),
  );

  Widget _maybeFit(Widget child) => square
      ? Flexible(
          child: FittedBox(fit: BoxFit.scaleDown, child: child),
        )
      : child;

  /// The label's size in the list layout.
  double get _fontSize {
    if (_pictureOnly(label)) return prominent ? 44 : 34;
    if (prominent) return label.length <= 24 && !label.contains('\n') ? 24 : 19;
    return large ? 20 : 15;
  }

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    final speaker = ContentSpeakerScope.maybeOf(context);
    final ref = audioRef;
    final speak = speaker == null || ref == null
        ? null
        : () => speaker.speak(audioRef: ref, partId: ref);
    final en = Localizations.maybeLocaleOf(context)?.languageCode == 'en';
    final (border, fill, text, icon) = switch (state) {
      // A 3:1 edge (UX review G11): `line` was 1.2:1 on white.
      AnswerTileState.idle => (p.inkMuted, p.surface, p.ink, null),
      AnswerTileState.picked => (
        p.quebecBlueBright,
        p.navHoverFill,
        p.ink,
        null,
      ),
      AnswerTileState.retry => (
        p.retry,
        p.retryPale,
        p.isDark ? p.retry : const Color(0xFF9A4A0C),
        Icons.track_changes_rounded,
      ),
      AnswerTileState.correct => (
        p.success,
        p.successPale,
        p.ink,
        Icons.check_rounded,
      ),
    };

    return Semantics(
      button: true,
      selected: state == AnswerTileState.picked,
      enabled: onTap != null,
      label: label,
      hint: semanticsState,
      excludeSemantics: true,
      onLongPress: speak,
      customSemanticsActions: speak == null
          ? null
          : {CustomSemanticsAction(label: en ? 'Listen' : 'Écouter'): speak},
      child: _FocusOutline(
        child: Material(
          color: fill,
          shape: RoundedRectangleBorder(
            borderRadius: Radii.cardMd,
            side: BorderSide(color: border, width: 2),
          ),
          child: InkWell(
            onTap: onTap,
            onLongPress: speak,
            borderRadius: Radii.cardMd,
            // No grey focus fill: it lingered into the wrong-answer state
            // and read as « selected ». _FocusOutline draws focus (N8).
            focusColor: Colors.transparent,
            child: ConstrainedBox(
              // ≥48px: the frontend spec's tap-target floor.
              constraints: BoxConstraints(
                minHeight: square
                    ? 88
                    : prominent
                    ? 64
                    : !large
                    ? 52
                    : MediaQuery.sizeOf(context).width < Breakpoints.compact
                    ? 72
                    : 88,
              ),
              child: dense || square
                  ? _dense(text, icon, border)
                  : Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          // Its own 48 dp pill with a gap after it, so a
                          // child aiming for it doesn't pick the answer
                          // instead (UX review G10).
                          if (speak != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: IconButton.filledTonal(
                                key: ValueKey('tile-speak-$ref'),
                                onPressed: speak,
                                tooltip: en ? 'Listen' : 'Écouter',
                                iconSize: 22,
                                constraints: const BoxConstraints.tightFor(
                                  width: 48,
                                  height: 48,
                                ),
                                style: IconButton.styleFrom(
                                  backgroundColor: p.navHoverFill,
                                  foregroundColor: p.isDark
                                      ? p.quebecBlueBright
                                      : p.quebecBlue,
                                ),
                                icon: const Icon(Icons.volume_up_rounded),
                              ),
                            ),
                          if (imageRef != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 56,
                                  maxHeight: 56,
                                ),
                                child: ContentImage(
                                  ref: imageRef!,
                                  fallback: const SizedBox.shrink(),
                                ),
                              ),
                            ),
                          Expanded(
                            child: SwatchText(
                              label,
                              // A picture answer (emoji only) draws big:
                              // the child reads the picture, not the word.
                              textAlign: prominent || _pictureOnly(label)
                                  ? TextAlign.center
                                  : null,
                              style: TextStyle(
                                fontFamily: VillageType.display,
                                fontWeight: FontWeight.w700,
                                fontSize: _fontSize,
                                color: text,
                              ),
                            ),
                          ),
                          if (badge != null)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              width: 22,
                              height: 22,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: border,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '$badge',
                                style: const TextStyle(
                                  fontFamily: VillageType.display,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          if (icon != null) ...[
                            const SizedBox(width: 8),
                            Icon(icon, size: 18, color: border),
                          ],
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

/// A 2 px blue outline around a tile while it holds keyboard focus (UX
/// review N8; WCAG 2.4.7 and 2.4.11), drawn just outside its border so the
/// state colour still shows. Only in keyboard mode: a tap draws nothing.
class _FocusOutline extends StatefulWidget {
  const _FocusOutline({required this.child});
  final Widget child;

  @override
  State<_FocusOutline> createState() => _FocusOutlineState();
}

class _FocusOutlineState extends State<_FocusOutline> {
  var _focused = false;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    final keyboard =
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (f) => setState(() => _focused = f),
      child: Stack(
        fit: StackFit.passthrough,
        clipBehavior: Clip.none,
        children: [
          widget.child,
          if (_focused && keyboard)
            Positioned(
              left: -4,
              top: -4,
              right: -4,
              bottom: -4,
              child: IgnorePointer(
                child: DecoratedBox(
                  key: const ValueKey('focus-ring'),
                  decoration: BoxDecoration(
                    borderRadius: Radii.cardMd,
                    border: Border.all(color: p.quebecBlueBright, width: 2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Whether [label] is only pictures (emoji), with no letters or digits, so
/// it can be drawn at picture size.
bool _pictureOnly(String label) {
  final t = label.trim();
  if (t.isEmpty) return false;
  return !RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(t);
}
