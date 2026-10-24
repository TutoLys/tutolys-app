import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

/// Web build: never called (`ExercisePromptAudio` branches on `kIsWeb`
/// before reaching this), but still needs to compile — `dart:io`'s `File`
/// does not exist for a web target, which is the entire reason this file
/// and `audio_file_io.dart` are selected via a conditional import rather
/// than one file branching internally.
Future<Source> fileSourceFor(Uint8List bytes, String cacheKey) async {
  throw UnsupportedError('fileSourceFor is not used on web — see audio.dart');
}
