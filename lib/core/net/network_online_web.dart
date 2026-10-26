import 'dart:js_interop';

@JS('addEventListener')
external void _addEventListener(JSString type, JSFunction listener);

/// Calls [onOnline] on the browser's `online` event: the network is back.
void listenForNetworkOnline(void Function() onOnline) {
  _addEventListener('online'.toJS, (() => onOnline()).toJS);
}
