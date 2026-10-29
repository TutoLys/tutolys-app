import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// On the web the store is the browser's IndexedDB (and OPFS when the
/// browser offers it), and a reload starts the app on fresh assets.
bool get canRepairStorage => true;

/// Deletes the browser's copy of [name]. Everything local goes with it:
/// the caller says so first, and counts it in the technical log.
Future<void> repairStorage(String name) async {
  final done = Completer<void>();
  void finish(web.Event _) {
    if (!done.isCompleted) done.complete();
  }

  final request = web.window.indexedDB.deleteDatabase(name);
  request.onsuccess = finish.toJS;
  request.onerror = finish.toJS;
  // Another tab still holds it open: give up waiting rather than hang.
  request.onblocked = finish.toJS;
  await done.future.timeout(const Duration(seconds: 5), onTimeout: () {});
  try {
    final root = await web.window.navigator.storage.getDirectory().toDart;
    await root
        .removeEntry('drift_db', web.FileSystemRemoveOptions(recursive: true))
        .toDart;
  } on Object {
    // No OPFS copy (the usual case: sharedIndexedDb). Nothing to remove.
  }
}

void reloadApp() => web.window.location.reload();
