import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

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

  /// A recording of [label] (`audio_ref`), for a child who can't read it
  /// yet. Played only when asked: the small speaker on the tile, or a long
  /// press. A plain tap still just chooses, so answers are never read
  /// aloud by default (Hafid's rule). Nothing is drawn when the host has no
  /// [ContentSpeakerScope].
  final String? audioRef;

  Widget _dense(Color text, IconData? icon, Color border) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            fontFamily: VillageType.display,
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: text,
          ),
        ),
        if (icon != null) Icon(icon, size: 12, color: border),
      ],
    ),
  );

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
          child: ConstrainedBox(
            // ≥48px: the frontend spec's tap-target floor.
            constraints: const BoxConstraints(minHeight: 52),
            child: dense
                ? _dense(text, icon, border)
                : Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
                          child: Text(
                            label,
                            style: TextStyle(
                              fontFamily: VillageType.display,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
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
    );
  }
}
