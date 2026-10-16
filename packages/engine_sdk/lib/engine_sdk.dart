/// The engine contract.
///
/// An engine depends on this package and the design system only — never on the
/// app, the API client or the database. That keeps engines widget-testable in
/// isolation and keeps credentials out of game code.
library;

export 'src/engine.dart';
export 'src/outbox.dart';
export 'src/registry.dart';
export 'src/result.dart';
export 'src/settings.dart';
export 'src/telemetry.dart';
