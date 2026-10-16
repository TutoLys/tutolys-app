/// The durable write boundary for telemetry.
///
/// Engines never reach the network. Every telemetry call lands here first, and
/// a flusher (A4) uploads batches later. That ordering is the whole reason the
/// app can be played on a plane and still produce a complete report.
///
/// Two properties the implementation must preserve:
///
/// 1. **Durable before acknowledged.** An event is only "logged" once it is on
///    disk. Buffering in memory and flushing on a timer loses the last minute
///    of play every time the app is killed — and the end of a session is
///    exactly where the interesting signal is.
/// 2. **Never silently dropped.** A write that cannot be persisted is an error
///    the app surfaces, not something swallowed. The product is the data.
abstract interface class EventOutbox {
  /// Persist one event. Must not throw for a duplicate `event_id`.
  Future<void> add(Map<String, Object?> event);

  /// Events awaiting upload, oldest first.
  Future<List<Map<String, Object?>>> pending({int limit});

  /// Mark events as delivered, by `event_id`.
  Future<void> markDelivered(List<String> eventIds);

  /// How many events are waiting. Reported as a health counter (plan §8).
  Future<int> depth();
}

/// In-memory outbox.
///
/// Used by tests and by the engine SDK's own test suite. A4 replaces it with
/// a drift-backed implementation; nothing outside this file changes, which is
/// the point of the interface.
class InMemoryEventOutbox implements EventOutbox {
  final Map<String, Map<String, Object?>> _events = {};
  final List<String> _order = [];
  final Set<String> _delivered = {};

  @override
  Future<void> add(Map<String, Object?> event) async {
    final id = event['event_id'] as String;
    // Idempotent on event_id, matching the server's contract. A retry inside
    // the app must not produce a second row either.
    if (_events.containsKey(id)) return;
    _events[id] = Map<String, Object?>.unmodifiable(event);
    _order.add(id);
  }

  @override
  Future<List<Map<String, Object?>>> pending({int limit = 50}) async {
    return _order
        .where((id) => !_delivered.contains(id))
        .take(limit)
        .map((id) => _events[id]!)
        .toList(growable: false);
  }

  @override
  Future<void> markDelivered(List<String> eventIds) async {
    _delivered.addAll(eventIds);
  }

  @override
  Future<int> depth() async =>
      _order.where((id) => !_delivered.contains(id)).length;

  /// Everything ever written, in order. Test affordance.
  List<Map<String, Object?>> get all =>
      _order.map((id) => _events[id]!).toList(growable: false);
}
