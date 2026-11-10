import 'package:flutter/widgets.dart';

/// Whether anything sits above the app shell on the root navigator: a
/// dialog, a menu, a sheet shown on the root (ADR 0126).
///
/// The shell's pages live in the nested paired router, so `ModalRoute.of`
/// from a page only sees routes pushed on that inner navigator. A dialog
/// opened with `showDialog` goes on the root navigator, where this observer
/// is the only one watching.
class RootCoverObserver extends NavigatorObserver {
  final _routes = <Route<dynamic>>[];

  /// True while the root navigator holds more than its base route.
  final ValueNotifier<bool> covered = ValueNotifier(false);

  void _sync() => covered.value = _routes.length > 1;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.add(route);
    _sync();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _sync();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _sync();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final i = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (i >= 0 && newRoute != null) {
      _routes[i] = newRoute;
    } else if (newRoute != null) {
      _routes.add(newRoute);
    }
    _sync();
  }
}

/// The one observer on the app's root navigator (`main.dart`).
final rootCoverObserver = RootCoverObserver();
