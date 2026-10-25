import 'dart:convert';
import 'dart:typed_data';

import 'package:engine_sdk/engine_sdk.dart';

import '../local_db/database.dart';
import 'asset_kind.dart';

/// The real [ImageResolver]: the cached envelope's `assets[]` turns an
/// `image_ref` into a sha256, and `asset_cache` holds the bytes for that
/// hash (ADR 0027). Reads only; downloading is `ContentSync`'s job.
class DriftImageResolver implements ImageResolver {
  DriftImageResolver(this.db);

  final LocalDatabase db;

  /// ref -> sha256 per exercise, read once: an exercise's assets don't
  /// change while it is on screen.
  final Map<String, Map<String, String>> _refs = {};

  @override
  Future<Uint8List?> bytesFor({
    required String exerciseId,
    required String ref,
  }) async {
    final sha256 = (await _refsFor(exerciseId))[ref];
    if (sha256 == null) return null;
    final row = await (db.select(
      db.assetCacheTable,
    )..where((t) => t.sha256.equals(sha256))).getSingleOrNull();
    return row?.bytes;
  }

  Future<Map<String, String>> _refsFor(String exerciseId) async {
    if (_refs[exerciseId] case final known?) return known;
    final row = await (db.select(
      db.exerciseCacheTable,
    )..where((t) => t.exerciseId.equals(exerciseId))).getSingleOrNull();
    if (row == null) return const {};
    final assets =
        (jsonDecode(row.payload) as Map<String, Object?>)['assets'] as List?;
    return _refs[exerciseId] = {
      for (final asset in (assets ?? const []).cast<Map<String, Object?>>())
        if (imageMediaTypeOf(asset) != null &&
            asset['ref'] is String &&
            asset['sha256'] is String)
          asset['ref'] as String: asset['sha256'] as String,
    };
  }
}
