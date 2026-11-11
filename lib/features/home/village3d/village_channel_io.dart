import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:village_webview_linux/village_webview_linux.dart';
import 'package:webview_all_windows/webview_all_windows.dart';
import 'package:webview_flutter/webview_flutter.dart' as wf;
import 'package:webview_platform_interface/webview_platform_interface.dart'
    as wp;

import 'village_channel.dart';

/// Every native platform hosts the scene in a WebView over a loopback
/// server (ADR 0126 for Linux, ADR 0127 for the others):
/// - Linux: WebKitGTK, a native layer drawn above Flutter;
/// - Android, iOS, macOS: the official `webview_flutter`;
/// - Windows: WebView2 through `webview_all_windows`.
///
/// Never under `flutter test`: the VM has no WebView plugin behind it.
bool get villageScenePlatform =>
    !Platform.environment.containsKey('FLUTTER_TEST') &&
    (Platform.isLinux ||
        Platform.isAndroid ||
        Platform.isIOS ||
        Platform.isMacOS ||
        Platform.isWindows);

VillageSceneChannel? createVillageSceneChannel({required String title}) {
  if (!villageScenePlatform) return null;
  if (Platform.isLinux) return _LinuxVillageChannel(title: title);
  if (Platform.isWindows) return _WindowsVillageChannel();
  return _FlutterWebViewVillageChannel();
}

class _LinuxVillageChannel implements VillageSceneChannel {
  _LinuxVillageChannel({required String title})
    : _view = LinuxVillageView(title: title);

  final LinuxVillageView _view;

  @override
  Stream<Object?> get messages => _view.messages;

  @override
  void send(Map<String, Object?> message) => _view.send(message);

  @override
  Widget buildView() => _view.build();

  /// A GTK layer over Flutter: the host lifts it off screen while a
  /// dialog, sheet or page covers the Village.
  @override
  bool get drawsAboveFlutter => true;

  /// Lifted instead (above); a covered native view takes no input.
  @override
  void setInteractive(bool on) {}

  @override
  void dispose() => _view.dispose();
}

/// The bundled scene, read from the app's assets: inside the APK on
/// Android, in the app bundle on iOS and macOS, next to the exe on Windows.
Future<List<int>?> _loadBundled(List<String> path) async {
  final data = await rootBundle.load('assets/village3d/${path.join('/')}');
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

/// The JS that hands one message to the scene. A JSON string literal of the
/// JSON text: nothing in the message can break out of the call.
String villageReceiveScript(Map<String, Object?> message) =>
    'window.villageReceive && '
    'window.villageReceive(${jsonEncode(jsonEncode(message))})';

/// Shared by the composited WebViews: the server, the message stream and
/// the input switch. Subclasses make the controller.
abstract class _CompositedVillageChannel implements VillageSceneChannel {
  _CompositedVillageChannel() {
    unawaited(_start());
  }

  final messagesOut = StreamController<Object?>.broadcast();
  final interactive = ValueNotifier<bool>(false);
  VillageAssetServer? _server;
  var disposed = false;

  @override
  Stream<Object?> get messages => messagesOut.stream;

  Future<void> _start() async {
    try {
      final server = await VillageAssetServer.startWith(_loadBundled);
      if (disposed) {
        await server.close();
        return;
      }
      _server = server;
      await open(server);
    } catch (_) {
      // No WebView, no bundle: the scene never says ready, and the host
      // keeps the 2D village (its ready timeout).
    }
  }

  /// Loads [server]'s entry, locked to its origin, with `VillageHost`.
  Future<void> open(VillageAssetServer server);

  void receive(String text) {
    try {
      messagesOut.add(jsonDecode(text));
    } on FormatException {
      // Not a bridge message: ignored, like any other.
    }
  }

  /// Composited inside Flutter: a dialog draws over it as over any widget.
  @override
  bool get drawsAboveFlutter => false;

  /// Off while it loads or anything covers it, so a tap meant for a
  /// Flutter widget on top never reaches the scene.
  @override
  void setInteractive(bool on) => interactive.value = on;

  Widget view(BuildContext context);

  @override
  Widget buildView() => ValueListenableBuilder<bool>(
    valueListenable: interactive,
    builder: (context, on, child) => IgnorePointer(ignoring: !on, child: child),
    child: Builder(builder: view),
  );

  @override
  void dispose() {
    disposed = true;
    unawaited(_server?.close());
    unawaited(messagesOut.close());
    interactive.dispose();
  }
}

/// Android, iOS and macOS.
class _FlutterWebViewVillageChannel extends _CompositedVillageChannel {
  final _ready = ValueNotifier<wf.WebViewController?>(null);

  @override
  Future<void> open(VillageAssetServer server) async {
    final controller = wf.WebViewController();
    await controller.setJavaScriptMode(wf.JavaScriptMode.unrestricted);
    await controller.setBackgroundColor(const Color(0x00000000));
    await controller.setNavigationDelegate(
      wf.NavigationDelegate(
        onNavigationRequest: (request) =>
            Uri.tryParse(request.url)?.origin == server.origin.origin
            ? wf.NavigationDecision.navigate
            : wf.NavigationDecision.prevent,
      ),
    );
    await controller.addJavaScriptChannel(
      'VillageHost',
      onMessageReceived: (m) => receive(m.message),
    );
    await controller.loadRequest(server.entry);
    if (disposed) return;
    _ready.value = controller;
  }

  @override
  void send(Map<String, Object?> message) {
    final controller = _ready.value;
    if (controller == null) return;
    unawaited(
      controller
          .runJavaScript(villageReceiveScript(message))
          .catchError((Object _) {}),
    );
  }

  @override
  Widget view(BuildContext context) =>
      ValueListenableBuilder<wf.WebViewController?>(
        valueListenable: _ready,
        builder: (context, controller, _) => controller == null
            ? const SizedBox.expand()
            : wf.WebViewWidget(controller: controller),
      );

  @override
  void dispose() {
    _ready.value = null;
    super.dispose();
  }
}

/// Windows: WebView2, drawn into a Flutter texture.
class _WindowsVillageChannel extends _CompositedVillageChannel {
  final _ready = ValueNotifier<WindowsWebViewController?>(null);

  @override
  Future<void> open(VillageAssetServer server) async {
    final controller = WindowsWebViewController(
      const wp.PlatformWebViewControllerCreationParams(),
    );
    await controller.setJavaScriptMode(wp.JavaScriptMode.unrestricted);
    final navigation = WindowsNavigationDelegate(
      const wp.PlatformNavigationDelegateCreationParams(),
    );
    await navigation.setOnNavigationRequest(
      (request) => Uri.tryParse(request.url)?.origin == server.origin.origin
          ? wp.NavigationDecision.navigate
          : wp.NavigationDecision.prevent,
    );
    await controller.setPlatformNavigationDelegate(navigation);
    await controller.addJavaScriptChannel(
      wp.JavaScriptChannelParams(
        name: 'VillageHost',
        onMessageReceived: (m) => receive(m.message),
      ),
    );
    await controller.loadRequest(wp.LoadRequestParams(uri: server.entry));
    if (disposed) return;
    _ready.value = controller;
  }

  @override
  void send(Map<String, Object?> message) {
    final controller = _ready.value;
    if (controller == null) return;
    unawaited(
      controller
          .runJavaScript(villageReceiveScript(message))
          .catchError((Object _) {}),
    );
  }

  @override
  Widget view(BuildContext context) =>
      ValueListenableBuilder<WindowsWebViewController?>(
        valueListenable: _ready,
        builder: (context, controller, _) => controller == null
            ? const SizedBox.expand()
            : WindowsWebViewWidget(
                WindowsWebViewWidgetCreationParams(controller: controller),
              ).build(context),
      );

  @override
  void dispose() {
    _ready.value = null;
    super.dispose();
  }
}
