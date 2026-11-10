import '../../../data/api/weather_api.dart';
import '../village_scene.dart' show VillageBuilding;

/// The JSON contract between the app and the embedded 3D village (ADR 0126,
/// `Platforms/codex/village-3d/BRIDGE.md`). Pure Dart: no platform view, no
/// browser API, so every message is testable on the VM.
///
/// The app owns the data, the words and the navigation. The scene draws and
/// reports taps. Every message carries `v`, so either side can refuse a
/// version it doesn't speak instead of misreading it.
const villageBridgeVersion = 1;

/// What the app tells the scene: everything it shows, in the app's words.
class VillageSceneState {
  const VillageSceneState({
    required this.buildings,
    required this.lang,
    required this.signTitle,
    required this.signSubtitle,
    required this.greeting,
    required this.reduced,
    required this.strings,
    this.weather,
  });

  final List<VillageBuilding> buildings;

  /// `fr` or `en`: the app's language, never a subject's.
  final String lang;
  final String signTitle;
  final String signSubtitle;

  /// The fox's line. Null: the fox says nothing.
  final String? greeting;

  /// The app's reduced motion, already OR-ed with the OS setting
  /// (`MediaQuery.disableAnimations`). The scene ORs it with the browser's
  /// own `prefers-reduced-motion` again: it can only add a reason.
  final bool reduced;

  /// Every other word the scene shows, keyed as BRIDGE.md lists them.
  final Map<String, String> strings;

  /// The real weather, as last served (BRIDGE.md "Real weather"). Null
  /// clears it: the scene shows a calm sky for the season.
  final VillageWeather? weather;

  Map<String, Object?> toJson() => {
    'buildings': [
      for (final b in buildings)
        {
          'id': b.subject,
          'label': b.label,
          // null is « À découvrir », never 0 (the 2D pill's own rule).
          'progress': b.measured ? b.progress : null,
          'live': b.live,
          // No lessons yet at this grade (ESL, FLS today, ADR 0101): still
          // tappable, its Carte says lessons are coming; the pill says
          // « Bientôt » instead of a figure. Proposed to village-3d.
          'soon': !b.hasLessons,
        },
    ],
    'lang': lang,
    'sign': {'title': signTitle, 'subtitle': signSubtitle},
    'greeting': greeting,
    // The app draws its header outside the scene's box.
    'insets': {'top': 0},
    'reduced': reduced,
    'strings': strings,
    'weather': weather?.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is VillageSceneState && _deepEquals(toJson(), other.toJson());

  @override
  int get hashCode => toJson().toString().hashCode;
}

bool _deepEquals(Object? a, Object? b) {
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || !_deepEquals(a[key], b[key])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_deepEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

/// A season the child can pick (`setSeason`, BRIDGE.md v1).
enum VillageSeason { spring, summer, autumn, winter }

/// A weather the child can pick (`setWeather`, BRIDGE.md v1). The names are
/// the bridge's own values.
enum VillageSky { clear, clouds, rain, snow, storm, fog }

/// Messages the app sends.
abstract final class HostMessage {
  static Map<String, Object?> init(VillageSceneState state) => {
    'v': villageBridgeVersion,
    'type': 'init',
    ...state.toJson(),
  };

  static Map<String, Object?> update(VillageSceneState state) => {
    'v': villageBridgeVersion,
    'type': 'update',
    ...state.toJson(),
  };

  static const Map<String, Object?> pause = {
    'v': villageBridgeVersion,
    'type': 'pause',
  };

  static const Map<String, Object?> resume = {
    'v': villageBridgeVersion,
    'type': 'resume',
  };

  /// The sky's hour, 0–24, or null for Québec's live clock.
  static Map<String, Object?> setTime(double? hour) => {
    'v': villageBridgeVersion,
    'type': 'setTime',
    'hour': hour,
    'animate': false,
  };

  /// A [VillageSeason] name, or `live` for the season of the real date.
  static Map<String, Object?> setSeason(VillageSeason? season) => {
    'v': villageBridgeVersion,
    'type': 'setSeason',
    'season': season?.name ?? 'live',
  };

  /// A [VillageSky] name, or `live` for the real weather.
  static Map<String, Object?> setWeather(VillageSky? sky) => {
    'v': villageBridgeVersion,
    'type': 'setWeather',
    'weather': sky?.name ?? 'live',
  };

  /// Asks for a fresh frame rate; the scene answers with `stats`.
  static const Map<String, Object?> getStats = {
    'v': villageBridgeVersion,
    'type': 'getStats',
  };

  /// Final: stops the loop and frees the GPU before the frame goes.
  static const Map<String, Object?> dispose = {
    'v': villageBridgeVersion,
    'type': 'dispose',
  };
}

/// What the scene can say. Anything else, or another version, is
/// [SceneIgnored]: a newer scene must never make an older app act.
sealed class SceneEvent {
  const SceneEvent();

  static SceneEvent parse(Object? raw) {
    if (raw is! Map) return const SceneIgnored();
    if (raw['v'] != villageBridgeVersion) return const SceneIgnored();
    return switch (raw['type']) {
      'loading' => const SceneLoading(),
      'ready' => const SceneReady(),
      'error' => const SceneError(),
      'unavailable' => SceneUnavailable('${raw['reason'] ?? 'unknown'}'),
      'perf' => switch (raw['fps']) {
        final num fps => ScenePerf(fps.toDouble()),
        _ => const SceneIgnored(),
      },
      'stats' => switch (raw['fps']) {
        final num fps => SceneStats(fps.toDouble()),
        _ => const SceneIgnored(),
      },
      'opening' => switch (raw['id']) {
        final String id when id.isNotEmpty => SceneOpening(id),
        _ => const SceneIgnored(),
      },
      'open' => switch (raw['id']) {
        final String id when id.isNotEmpty => SceneOpen(id),
        _ => const SceneIgnored(),
      },
      'mascot' => const SceneMascot(),
      _ => const SceneIgnored(),
    };
  }
}

/// The scene is listening: the app answers with `init`. Sent again by a
/// scene that reloaded.
final class SceneLoading extends SceneEvent {
  const SceneLoading();
}

/// An uncaught error after start-up. The scene may still be running, so it
/// is not a fallback; its message is not kept (it can carry anything).
final class SceneError extends SceneEvent {
  const SceneError();
}

/// The scene has drawn its first frame.
final class SceneReady extends SceneEvent {
  const SceneReady();
}

/// No WebGL, or the scene failed to set up: show the 2D village.
final class SceneUnavailable extends SceneEvent {
  const SceneUnavailable(this.reason);
  final String reason;
}

/// The frame rate the scene measured once it settled.
final class ScenePerf extends SceneEvent {
  const ScenePerf(this.fps);
  final double fps;
}

/// The frame rate now, in reply to `getStats`.
final class SceneStats extends SceneEvent {
  const SceneStats(this.fps);
  final double fps;
}

/// A building was tapped and the scene's portal has started (scene
/// `.12`+). `open` follows when the gold fills the box; nothing navigates
/// yet. `ms` isn't kept: the host waits for `open`, never times it.
final class SceneOpening extends SceneEvent {
  const SceneOpening(this.id);
  final String id;
}

/// The portal filled the box with gold (or, before scene `.12`, a building
/// was tapped): navigate now.
final class SceneOpen extends SceneEvent {
  const SceneOpen(this.id);
  final String id;
}

/// The fox was tapped.
final class SceneMascot extends SceneEvent {
  const SceneMascot();
}

final class SceneIgnored extends SceneEvent {
  const SceneIgnored();
}

/// Below this the 3D village gives way to the 2D one (INTEGRATION.md: "fps
/// above ~40").
const double village3dMinFps = 40;
