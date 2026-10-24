/// Content checksums, computed to match the backend byte for byte.
///
/// This is a **cross-language contract**. The server computes
/// `sha256(canonical_json(envelope))` in Python; the app recomputes it in Dart
/// to verify what arrived. If the two disagree by so much as a space, every
/// download looks corrupted and content sync never converges — so the rules
/// are spelled out here and pinned by a test against a hash produced by the
/// real backend.
///
/// The rules, matching Python's
/// `json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False)`:
///
/// 1. **Map keys sorted** — so the same content authored in a different order
///    hashes the same.
/// 2. **List order preserved** — order is meaning in a list (the correct
///    sequence in `compose_build`), so it is never sorted.
/// 3. **No insignificant whitespace.**
/// 4. **Non-ASCII left literal**, not `\u`-escaped. French content is full of
///    accents; escaping them would change every hash.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Recursively sort map keys, leaving lists in place.
Object? canonicalize(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((k) => k as String).toList()..sort();
    return {for (final key in keys) key: canonicalize(value[key])};
  }
  if (value is List) {
    // Order is meaning here — sorting would change the answer.
    return value.map(canonicalize).toList();
  }
  return value;
}

/// The exact string the backend hashes.
String canonicalJson(Object? payload) => jsonEncode(canonicalize(payload));

/// Checksum of an exercise envelope, comparable with the server's
/// `content_hash`.
String contentSha256(Object? payload) {
  return sha256.convert(utf8.encode(canonicalJson(payload))).toString();
}

/// Checksum of raw bytes (an audio file, say) — comparable with an
/// `assets[].sha256` entry, which the backend computes over the file's
/// actual bytes, not a canonical-JSON encoding of anything.
String bytesSha256(List<int> bytes) => sha256.convert(bytes).toString();
