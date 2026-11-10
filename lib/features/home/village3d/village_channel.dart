import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'village_channel_stub.dart'
    if (dart.library.js_interop) 'village_channel_web.dart'
    if (dart.library.io) 'village_channel_io.dart'
    as platform;

/// One live 3D scene and the pipe to it (ADR 0126). The web build mounts an
/// iframe as a platform view; Linux mounts a WebView. Either way the app
/// sees raw decoded JSON in, maps out, and a widget to place.
abstract class VillageSceneChannel {
  /// Raw messages from the scene, already checked to come from it.
  Stream<Object?> get messages;

  void send(Map<String, Object?> message);

  Widget buildView();

  void dispose();
}

/// Makes a channel, or null where this platform can't host the scene.
typedef VillageSceneChannelFactory =
    VillageSceneChannel? Function({required String title});

/// Overridden in tests with a fake. The VM test runner has no scene, so the
/// default there is null and every existing village test keeps the 2D one.
final villageSceneChannelFactoryProvider = Provider<VillageSceneChannelFactory>(
  (ref) => village3dBundled
      ? platform.createVillageSceneChannel
      : ({required String title}) => null,
);

/// False until `assets/village3d/` holds a bundle that speaks the bridge:
/// an iframe on a missing page would only ever time out.
const village3dBundled = false;

/// The bundled scene, under the app's own assets: no CDN (offline-first).
const village3dEntry = 'assets/village3d/village.html';

/// Bumped with every new `dist/`, so a browser never serves a stale module.
const village3dBundleVersion = '1';
