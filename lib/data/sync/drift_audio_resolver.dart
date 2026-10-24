import 'dart:typed_data';

import 'package:engine_sdk/engine_sdk.dart';

import '../local_db/database.dart';

/// The real [AudioResolver]: reads whatever `ContentSync` has already
/// downloaded and verified into [AudioCacheTable]. Never touches the
/// network itself — that's `ContentSync`'s job, kept separate so
/// `ExerciseRunner` (which holds this) never needs an access token or an
/// API client, only a place to read bytes from.
class DriftAudioResolver implements AudioResolver {
  DriftAudioResolver(this.db);

  final LocalDatabase db;

  @override
  Future<Uint8List?> bytesFor({
    required String exerciseId,
    required String ref,
  }) async {
    final row =
        await (db.select(db.audioCacheTable)
              ..where((t) => t.exerciseId.equals(exerciseId))
              ..where((t) => t.ref.equals(ref)))
            .getSingleOrNull();
    return row?.bytes;
  }
}
