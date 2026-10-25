import 'dart:js_interop';

import 'boot_handoff_types.dart';

/// `web/index.html` keeps `globalThis.tutolysBoot` up to date while the app
/// downloads. A missing or malformed value just means "start from the
/// default" — the hand-off is a nicety, never something to fail on.
@JS('tutolysBoot')
external _Boot? get _boot;

extension type _Boot._(JSObject _) implements JSObject {
  external JSNumber? get progress;
  external JSNumber? get messageIndex;
}

BootHandoff? readBootHandoff() {
  try {
    final boot = _boot;
    final progress = boot?.progress?.toDartDouble;
    if (boot == null || progress == null || progress.isNaN) return null;
    final index = boot.messageIndex?.toDartDouble;
    return (
      progress: progress.clamp(0.0, 1.0),
      messageIndex: index == null || index.isNaN ? 0 : index.toInt(),
    );
  } catch (_) {
    return null;
  }
}

/// Tells the next launch's HTML loader which language to speak.
///
/// The HTML stage runs before Flutter, so it cannot read Réglages' language
/// choice; without this it would greet an English-setting kid in French
/// (or, guessing from the browser, a French kid in English) and then switch
/// language mid-launch when Flutter takes over. `localStorage` is
/// per-origin and best-effort: if it's blocked, the HTML stage falls back
/// to French, the app's own default.
@JS('localStorage')
external _Storage? get _localStorage;

extension type _Storage._(JSObject _) implements JSObject {
  external void setItem(String key, String value);
}

void rememberBootLocale(String languageCode) {
  try {
    _localStorage?.setItem('tutolys.locale', languageCode);
  } catch (_) {
    // Private mode, blocked storage: the HTML stage defaults to French.
  }
}
