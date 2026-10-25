import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    final (border, fill, text, icon) = switch (state) {
      AnswerTileState.idle => (p.line, p.surface, p.ink, null),
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
      child: Material(
        color: fill,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.cardMd,
          side: BorderSide(color: border, width: 2),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: Radii.cardMd,
          child: ConstrainedBox(
            // ≥48px: the frontend spec's tap-target floor.
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
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
