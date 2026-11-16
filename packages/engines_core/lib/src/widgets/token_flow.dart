import 'package:flutter/widgets.dart';

/// Closing punctuation sits against the word before it: « joue. », « Hier, ».
/// The French space before ; : ! ? » is kept, so those aren't here.
final _closing = RegExp(r'^[.,…)\]”]+$');

/// An elided word sits against the next one: « J'ai », « l'école ».
final _opening = RegExp(r"(['’(\[“])$");

/// Whether [token] attaches to the token before it.
bool gluesToPrevious(String token) => _closing.hasMatch(token.trim());

/// Whether the token after [token] attaches to it.
bool gluesToNext(String token) => _opening.hasMatch(token.trim());

/// One laid-out piece of a sentence: a word, or several words drawn as one
/// (a framed group), known by the text of its first and last token.
class TokenPiece {
  const TokenPiece({
    required this.first,
    required this.last,
    required this.child,
  });

  /// One token on its own.
  TokenPiece.single(String text, this.child) : first = text, last = text;

  final String first;
  final String last;
  final Widget child;
}

/// A sentence of separately drawn tokens, spaced the way it's written.
///
/// A token-per-widget layout puts the same gap between every pair, which
/// gives « joue . » and « J' ai ». Here punctuation and elisions join their
/// neighbour with no gap, and the joined pieces never split across lines.
class TokenFlow extends StatelessWidget {
  const TokenFlow({
    required this.pieces,
    this.spacing = 6,
    this.runSpacing = 10,
    this.alignment = WrapAlignment.center,
    super.key,
  });

  final List<TokenPiece> pieces;
  final double spacing;
  final double runSpacing;
  final WrapAlignment alignment;

  /// The pieces grouped into runs that stay together.
  @visibleForTesting
  static List<List<TokenPiece>> runsOf(List<TokenPiece> pieces) {
    final runs = <List<TokenPiece>>[];
    for (final piece in pieces) {
      final joins =
          runs.isNotEmpty &&
          (gluesToPrevious(piece.first) || gluesToNext(runs.last.last.last));
      if (joins) {
        runs.last.add(piece);
      } else {
        runs.add([piece]);
      }
    }
    return runs;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      alignment: alignment,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final run in runsOf(pieces))
          run.length == 1
              ? run.single.child
              // Bounded, so a framed group inside a run still wraps its
              // own words on a phone rather than overflowing.
              : ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final p in run)
                        Flexible(fit: FlexFit.loose, child: p.child),
                    ],
                  ),
                ),
      ],
    ),
  );
}
