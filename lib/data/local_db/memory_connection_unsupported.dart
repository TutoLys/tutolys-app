import 'package:drift/drift.dart';

QueryExecutor memoryExecutor() {
  throw UnsupportedError(
    'LocalDatabase.memory() is test-only and needs dart:ffi — not available on web.',
  );
}
