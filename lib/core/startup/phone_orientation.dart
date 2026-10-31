import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Whether this device should stay in portrait (AM21, app ADR 0107): a
/// phone on Android or iOS, i.e. a screen whose short side is under 600
/// logical px. Tablets and desktops rotate freely, and so does a phone's
/// browser tab, which no app can lock; the installed web app is already
/// portrait through `web/manifest.json`.
bool shouldLockPortrait({
  required TargetPlatform platform,
  required bool isWeb,
  required Size logicalSize,
}) =>
    !isWeb &&
    (platform == TargetPlatform.android || platform == TargetPlatform.iOS) &&
    logicalSize.shortestSide < 600;

/// Applies [shouldLockPortrait] to the first view. A no-op elsewhere.
Future<void> lockPhonesToPortrait() async {
  final views = WidgetsBinding.instance.platformDispatcher.views;
  if (views.isEmpty) return;
  final view = views.first;
  final size = view.physicalSize / view.devicePixelRatio;
  if (!shouldLockPortrait(
    platform: defaultTargetPlatform,
    isWeb: kIsWeb,
    logicalSize: size,
  )) {
    return;
  }
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
}
