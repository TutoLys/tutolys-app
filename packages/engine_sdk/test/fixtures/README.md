# Test fixtures

`play_event.v1.json` is a **copy** of the event contract owned by
`tutolys-telemetry/docs/schemas/play_event.v1.json` (plan §4).

It is copied rather than referenced across repos so this package's tests are
self-contained. The contract test in `../telemetry_contract_test.dart` asserts
that every event the telemetry client can produce validates against it, so a
drift between the app and the server surfaces as a failing test rather than as
rejected events in production.

When the owning repo changes the schema, re-copy this file.
