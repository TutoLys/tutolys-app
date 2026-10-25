import 'package:flutter/widgets.dart';

/// Plays one piece of an engine's own content on request: a sentence of a
/// `passage_reader` passage (app ADR 0044).
///
/// The shell's speaker reads the *prompt*; some engines show more text than
/// that (a passage a grade-1 child can't read yet) and need a speaker beside
/// each part. An engine never touches audio (the contract keeps it pure), so
/// the host puts a [ContentSpeaker] above it, and the engine only says
/// *which* `audio_ref` the child asked for.
abstract interface class ContentSpeaker {
  /// The child tapped the speaker beside [partId]; play [audioRef] from the
  /// exercise's synced assets. Only ever called on a tap — nothing in an
  /// engine reads aloud by itself.
  void speak({required String audioRef, required String partId});
}

/// Puts a [ContentSpeaker] above an engine. Absent (a test, a host that
/// hasn't wired it, read-aloud turned off), [maybeOf] is null and the engine
/// draws no speaker at all rather than one that does nothing.
class ContentSpeakerScope extends InheritedWidget {
  const ContentSpeakerScope({
    required this.speaker,
    required super.child,
    super.key,
  });

  final ContentSpeaker speaker;

  static ContentSpeaker? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ContentSpeakerScope>()
      ?.speaker;

  @override
  bool updateShouldNotify(ContentSpeakerScope oldWidget) =>
      speaker != oldWidget.speaker;
}
