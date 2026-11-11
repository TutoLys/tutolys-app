import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// The parents' portal, where account, subscription and privacy live (the
/// app is for playing: Hafid, 2026-10-24). Zone parent opens it in the
/// device's browser, so the kid app never holds guardian credentials.
///
/// Set per build, like the API base: `--dart-define=TUTOLYS_PORTAL_URL`.
/// The default is the dev-stack's website on :4321 (tool/build_demo.sh
/// passes the demo host's).
const portalUrl = String.fromEnvironment(
  'TUTOLYS_PORTAL_URL',
  defaultValue: 'http://127.0.0.1:4321/portail/',
);

/// Opens [uri] outside the app; false when nothing could open it.
typedef ExternalUrlOpener = Future<bool> Function(Uri uri);

/// Overridden in tests: the VM has no browser.
final externalUrlOpenerProvider = Provider<ExternalUrlOpener>(
  (ref) => (uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      return false;
    }
  },
);
