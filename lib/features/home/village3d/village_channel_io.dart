import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:village_webview_linux/village_webview_linux.dart';

import 'village_channel.dart';

/// Linux desktop hosts the scene in a WebKitGTK WebView (ADR 0126). Other
/// native platforms keep the 2D village for now. Never under `flutter
/// test`: the VM runs on Linux but has no WebView plugin behind it.
bool get villageScenePlatform =>
    Platform.isLinux && !Platform.environment.containsKey('FLUTTER_TEST');

VillageSceneChannel? createVillageSceneChannel({required String title}) =>
    villageScenePlatform ? _LinuxVillageChannel(title: title) : null;

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
