import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/api/weather_api.dart';
import '../../../data/local_db/database.dart';
import '../../pairing/pairing_controller.dart';

final weatherApiProvider = Provider<WeatherApi>(
  (ref) => WeatherApi(dio: ref.watch(dioProvider)),
);

/// How often the Village asks while it stays on screen.
const villageWeatherEvery = Duration(minutes: 30);

/// Opening the Village again sooner than this doesn't ask again.
const villageWeatherMinGap = Duration(minutes: 10);

/// The last real weather the backend served for the active kid, kept in
/// `app_state` so it holds offline and from the first frame of the next
/// launch. Per kid, like every other kid-scoped key (ADR 0014). The scene
/// decides freshness itself (3 h), so an old value is passed as it is.
class VillageWeatherController extends Notifier<VillageWeather?> {
  static const _key = 'village.weather';
  DateTime? _lastAsked;

  String? get _kidId => ref.read(sessionControllerProvider).kid?.id;

  @override
  VillageWeather? build() {
    ref.watch(sessionControllerProvider.select((s) => s.kid?.id));
    _lastAsked = null;
    unawaited(_load());
    return null;
  }

  Future<void> _load() async {
    final kid = _kidId;
    if (kid == null) return;
    final db = ref.read(localDatabaseProvider);
    final row =
        await (db.select(db.appStateTable)
              ..where((t) => t.kidId.equals(kid) & t.key.equals(_key)))
            .getSingleOrNull();
    if (!ref.mounted || row == null || state != null) return;
    try {
      state = VillageWeather.fromJson(jsonDecode(row.value));
    } on FormatException {
      // A damaged row: the scene shows its calm sky.
    }
  }

  /// Asks the backend unless it was asked less than [minGap] ago. A new
  /// observation replaces the held one; nothing new keeps it.
  Future<void> refresh({
    Duration minGap = villageWeatherMinGap,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    if (_lastAsked case final last? when at.difference(last) < minGap) return;
    final kid = _kidId;
    final token = ref.read(sessionControllerProvider).accessToken;
    if (kid == null || token == null) return;
    _lastAsked = at;
    final fresh = await ref.read(weatherApiProvider).fetch(accessToken: token);
    if (fresh == null || !ref.mounted) return;
    state = fresh;
    final db = ref.read(localDatabaseProvider);
    await db
        .into(db.appStateTable)
        .insertOnConflictUpdate(
          AppStateTableCompanion.insert(
            kidId: kid,
            key: _key,
            value: jsonEncode(fresh.toJson()),
            updatedAt: at,
          ),
        );
  }
}

final villageWeatherProvider =
    NotifierProvider<VillageWeatherController, VillageWeather?>(
      VillageWeatherController.new,
    );

/// Asks for the weather when the Village comes on screen, then every
/// [villageWeatherEvery] while it stays there. Nothing while hidden.
class VillageWeatherPoller extends ConsumerStatefulWidget {
  const VillageWeatherPoller({
    required this.child,
    this.enabled = true,
    super.key,
  });

  final Widget child;

  /// False where no 3D scene can show the weather: nothing is asked.
  final bool enabled;

  @override
  ConsumerState<VillageWeatherPoller> createState() =>
      _VillageWeatherPollerState();
}

class _VillageWeatherPollerState extends ConsumerState<VillageWeatherPoller> {
  Timer? _timer;
  bool? _wasVisible;

  void _sync(bool visible) {
    if (_wasVisible == visible) return;
    _wasVisible = visible;
    _timer?.cancel();
    _timer = null;
    if (!visible) return;
    final weather = ref.read(villageWeatherProvider.notifier);
    unawaited(weather.refresh());
    _timer = Timer.periodic(
      villageWeatherEvery,
      (_) => unawaited(weather.refresh(minGap: Duration.zero)),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.enabled && Visibility.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _sync(visible);
    });
    return widget.child;
  }
}
