import 'dart:async';

import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter/foundation.dart';

import 'actor_scheduler.dart';
import 'character_manifest.dart';
import 'character_registry.dart';
import 'reaction.dart';
import 'reaction_policy.dart';

/// Turns runtime events into what each character is doing.
///
/// Subscribes to the runtime's event stream and owns one [ActorScheduler]
/// per cast role. Nothing awaits it: gameplay never waits for a reaction to
/// finish, and a reaction never delays the next question (brief §10).
///
/// Failures are contained here. A policy that throws, or a role whose
/// character isn't registered, produces an [AnimationDiagnostic] on
/// [diagnostics] — local, never persisted — and the session carries on.
class AnimationDirector {
  AnimationDirector({
    required Stream<RuntimeEvent> events,
    required CastAssignment cast,
    required CharacterRegistry registry,
    this.policy = const DefaultReactionPolicy(),
    bool reducedMotion = false,
    Duration Function()? clock,
  }) : _now = clock ?? _stopwatch() {
    _reducedMotion = reducedMotion;
    for (final MapEntry(key: role, value: id)
        in cast.characterIdByRole.entries) {
      final manifest = registry.manifest(id);
      if (manifest == null) {
        _diagnose('character_missing', {'role': role.name, 'character_id': id});
        continue;
      }
      _actors[role] = _Actor(manifest, ActorScheduler(idle: manifest.idle));
      _states[role] = ValueNotifier(_stateOf(role));
    }
    _sub = events.listen(_onEvent);
  }

  static Duration Function() _stopwatch() {
    final sw = Stopwatch()..start();
    return () => sw.elapsed;
  }

  final ReactionPolicy policy;
  final Duration Function() _now;
  final Map<ActorRole, _Actor> _actors = {};
  final Map<ActorRole, ValueNotifier<CharacterActorState>> _states = {};
  final Map<ActorRole, Timer> _timers = {};
  final StreamController<AnimationDiagnostic> _diagnostics =
      StreamController.broadcast();
  late final StreamSubscription<RuntimeEvent> _sub;
  late bool _reducedMotion;
  bool _disposed = false;

  /// What the character in [role] is doing, or null if the role is empty.
  ValueListenable<CharacterActorState>? actor(ActorRole role) => _states[role];

  Iterable<ActorRole> get roles => _states.keys;

  /// Local-only health signals (missing characters, policy errors).
  Stream<AnimationDiagnostic> get diagnostics => _diagnostics.stream;

  set reducedMotion(bool value) {
    if (value == _reducedMotion) return;
    _reducedMotion = value;
    for (final role in _states.keys) {
      _publish(role);
    }
  }

  /// Offer a cue directly — for host-level moments that aren't runtime
  /// events (a legacy engine's own reaction call, say).
  void cue(ReactionCue cue) {
    if (_disposed) return;
    final actor = _actors[cue.role];
    if (actor == null) return;
    if (actor.scheduler.offer(cue, _now())) {
      _publish(cue.role);
      _armExpiry(cue.role, cue.hold);
    }
  }

  /// Back to idle (session over, screen leaving).
  void reset() {
    for (final MapEntry(key: role, value: actor) in _actors.entries) {
      actor.scheduler.reset();
      _timers.remove(role)?.cancel();
      _publish(role);
    }
  }

  void _onEvent(RuntimeEvent event) {
    final List<ReactionCue> cues;
    try {
      cues = policy.onEvent(event);
    } on Object catch (e) {
      _diagnose('policy_error', {'event_type': event.type, 'error': '$e'});
      return;
    }
    for (final c in cues) {
      cue(c);
    }
  }

  void _armExpiry(ActorRole role, Duration? hold) {
    _timers.remove(role)?.cancel();
    if (hold == null) return;
    _timers[role] = Timer(hold, () {
      if (_disposed) return;
      if (_actors[role]!.scheduler.expire(_now())) _publish(role);
    });
  }

  CharacterActorState _stateOf(ActorRole role) {
    final a = _actors[role]!;
    return CharacterActorState(
      manifest: a.manifest,
      reaction: a.manifest.resolve(a.scheduler.reaction),
      generation: a.scheduler.generation,
      reducedMotion: _reducedMotion,
    );
  }

  void _publish(ActorRole role) {
    if (_disposed) return;
    _states[role]?.value = _stateOf(role);
  }

  void _diagnose(String type, Map<String, Object?> payload) {
    if (!_diagnostics.isClosed) {
      _diagnostics.add(AnimationDiagnostic(type, payload));
    }
  }

  /// Synchronous on purpose: a screen's `dispose` can't await, and nothing
  /// here is worth waiting for — stream teardown completes on its own.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    unawaited(_sub.cancel());
    for (final n in _states.values) {
      n.dispose();
    }
    unawaited(_diagnostics.close());
  }
}

class _Actor {
  _Actor(this.manifest, this.scheduler);
  final CharacterManifest manifest;
  final ActorScheduler scheduler;
}
