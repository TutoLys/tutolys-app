/// `LocalDatabase.memory()`'s backing executor — test-only, never used by
/// the running app itself. Split out so `database.dart` (which the app's
/// real `main()` needs to compile for web) never directly imports
/// `package:drift/native.dart` (`dart:ffi`), which cannot compile for web
/// at all. On web, the conditional default below is used, which just
/// throws if ever called — acceptable, since nothing on web calls it; VM
/// targets (every test) get the real in-memory sqlite3 implementation.
library;

export 'memory_connection_unsupported.dart'
    if (dart.library.ffi) 'memory_connection_native.dart';
