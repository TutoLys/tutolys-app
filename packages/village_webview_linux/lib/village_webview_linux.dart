import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:webview_all_linux/webview_all_linux.dart';
import 'package:webview_platform_interface/webview_platform_interface.dart';

import 'village_asset_server.dart';

export 'village_asset_server.dart';

/// The 3D village in a WebKitGTK WebView (ADR 0126). Shaped like the app's
/// `VillageSceneChannel`, which wraps it on Linux.
///
/// The scene talks back through the `VillageHost` JavaScript channel
/// (BRIDGE.md: "WebView transport"); the app talks in through
/// `window.villageReceive`. Navigation is locked to the loopback origin.
class LinuxVillageView {
  LinuxVillageView({required String title, Directory? bundle})
    : _bundle = bundle ?? _bundledScene() {
    unawaited(_start());
  }

  static Directory _bundledScene() => Directory(
    [
      File(Platform.resolvedExecutable).parent.path,
      'data',
      'flutter_assets',
      'assets',
      'village3d',
    ].join(Platform.pathSeparator),
  );

  final Directory _bundle;
  final _messages = StreamController<Object?>.broadcast();
  final _ready = ValueNotifier<LinuxWebViewController?>(null);
  VillageAssetServer? _server;
  var _disposed = false;

  Stream<Object?> get messages => _messages.stream;

  Future<void> _start() async {
    try {
      final server = await VillageAssetServer.start(_bundle);
      if (_disposed) {
        await server.close();
        return;
      }
      _server = server;
      final controller = LinuxWebViewController(
        const PlatformWebViewControllerCreationParams(),
      );
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      final navigation = LinuxNavigationDelegate(
        const PlatformNavigationDelegateCreationParams(),
      );
      await navigation.setOnNavigationRequest(
        (request) => Uri.tryParse(request.url)?.origin == server.origin.origin
            ? NavigationDecision.navigate
            : NavigationDecision.prevent,
      );
      await controller.setPlatformNavigationDelegate(navigation);
      await controller.addJavaScriptChannel(
        JavaScriptChannelParams(
          name: 'VillageHost',
          onMessageReceived: (message) {
            try {
              _messages.add(jsonDecode(message.message));
            } on FormatException {
              // Not a bridge message: ignored, like any other.
            }
          },
        ),
      );
      await controller.loadRequest(LoadRequestParams(uri: server.entry));
      if (_disposed) return;
      _ready.value = controller;
    } catch (_) {
      // Missing bundle, no WebKit: the scene never says ready, and the app
      // keeps the 2D village (its ready timeout).
    }
  }

  void send(Map<String, Object?> message) {
    final controller = _ready.value;
    if (controller == null) return;
    // A JSON string literal of the JSON text: nothing in the message can
    // break out of the call.
    final arg = jsonEncode(jsonEncode(message));
    unawaited(
      controller
          .runJavaScript('window.villageReceive && window.villageReceive($arg)')
          .catchError((_) {}),
    );
  }

  /// Runs [javaScript] in the scene and returns its result: for the
  /// on-device integration test only (reading the scene's frame counter,
  /// clicking a pill inside WebKit, where Flutter's gestures can't reach).
  @visibleForTesting
  Future<Object?> evaluate(String javaScript) async {
    final controller = _ready.value;
    if (controller == null) return null;
    return controller.runJavaScriptReturningResult(javaScript);
  }

  Widget build() => ValueListenableBuilder<LinuxWebViewController?>(
    valueListenable: _ready,
    builder: (context, controller, _) => controller == null
        ? const SizedBox.expand()
        : LinuxWebViewWidget(
            PlatformWebViewWidgetCreationParams(controller: controller),
          ).build(context),
  );

  void dispose() {
    _disposed = true;
    _ready.value = null;
    unawaited(_server?.close());
    unawaited(_messages.close());
  }
}
