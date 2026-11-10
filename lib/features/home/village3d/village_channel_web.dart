import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import 'village_channel.dart';

const villageScenePlatform = true;

VillageSceneChannel? createVillageSceneChannel({required String title}) =>
    _WebVillageChannel(title: title);

int _views = 0;

/// The scene in a same-origin iframe. Messages are taken only from that
/// iframe's own window and only from this origin; replies go to this origin
/// only, never `*`.
class _WebVillageChannel implements VillageSceneChannel {
  _WebVillageChannel({required String title}) {
    final src = ui_web.assetManager.getAssetUrl(village3dEntry);
    _iframe = web.HTMLIFrameElement()
      ..src = '$src?embed=1&v=$village3dBundleVersion'
      ..title = title;
    _iframe.style
      ..border = '0'
      ..width = '100%'
      ..height = '100%'
      ..display = 'block'
      // Until it's ready the 2D village covers it, and takes the taps.
      ..pointerEvents = 'none';
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int _) => _iframe,
    );
    _listener = _onMessage.toJS;
    web.window.addEventListener('message', _listener);
  }

  final _viewType = 'tutolys-village3d-${_views++}';
  late final web.HTMLIFrameElement _iframe;
  late final JSFunction _listener;
  final _messages = StreamController<Object?>.broadcast();

  String get _origin => web.window.location.origin;

  void _onMessage(web.MessageEvent event) {
    final source = event.source as JSAny?;
    final own = _iframe.contentWindow as JSAny?;
    if (own == null || source == null || !source.strictEquals(own).toDart) {
      return;
    }
    if (event.origin != _origin) return;
    _messages.add(event.data.dartify());
  }

  @override
  Stream<Object?> get messages => _messages.stream;

  @override
  void send(Map<String, Object?> message) {
    _iframe.contentWindow?.postMessage(message.jsify(), _origin.toJS);
  }

  @override
  Widget buildView() => HtmlElementView(viewType: _viewType);

  @override
  void setInteractive(bool on) {
    _iframe.style.pointerEvents = on ? 'auto' : 'none';
  }

  /// Flutter web composites its own layers above the iframe.
  @override
  bool get drawsAboveFlutter => false;

  @override
  void dispose() {
    web.window.removeEventListener('message', _listener);
    _iframe.src = 'about:blank';
    _messages.close();
  }
}
