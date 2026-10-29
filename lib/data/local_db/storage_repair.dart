/// Repairing the local store when it can't be opened (K5, ADR 0099).
library;

export 'storage_repair_stub.dart'
    if (dart.library.js_interop) 'storage_repair_web.dart';
