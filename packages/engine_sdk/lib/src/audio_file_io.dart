import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

/// Native platforms: write to a deterministic temp file and play from
/// that — `DeviceFileSource` is the best-supported source type everywhere
/// `dart:io` exists, unlike `BytesSource`, whose cross-platform support
/// audioplayers itself documents as "only some platforms."
Future<Source> fileSourceFor(Uint8List bytes, String cacheKey) async {
  final dir = await getTemporaryDirectory();
  final safeKey = cacheKey.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  final file = File('${dir.path}/exercise_audio_$safeKey.wav');
  // Overwriting a deterministic filename, not a fresh temp file every
  // play — the whole point is not accumulating one file per tap.
  await file.writeAsBytes(bytes, flush: true);
  return DeviceFileSource(file.path);
}
