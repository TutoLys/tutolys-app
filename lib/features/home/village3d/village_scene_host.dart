import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/routing/root_cover_observer.dart';
import '../../settings/settings_controller.dart';
import 'village_bridge.dart';
import 'village_channel.dart';
import 'village_scene_loading.dart';

/// Whether this run of the app may still try the 3D village. Turns false
/// for good once a scene said it can't draw here (no WebGL), was too slow,
/// or never answered: the 2D village is then the village until the next
/// launch, and no new scene is started on every return to the tab.
class Village3dSupport extends Notifier<bool> {
  @override
  bool build() => true;

  void markUnsupported() => state = false;
}

final village3dSupportProvider = NotifierProvider<Village3dSupport, bool>(
  Village3dSupport.new,
);

/// Whether the Village should place the 3D scene: the kid's setting, a
/// platform that can host it, and no failure yet this run. A layout that
/// differs between 3D and 2D (the phone one) reads this; the host itself
/// still falls back on its own if the scene then fails.
final village3dActiveProvider = Provider<bool>(
  (ref) =>
      ref.watch(settingsControllerProvider.select((s) => s.village3d)) &&
      ref.watch(villageScenePlatformProvider) &&
      ref.watch(village3dSupportProvider),
);

/// How long a scene has to say it's ready before the 2D village stays.
const village3dReadyTimeout = Duration(seconds: 20);

/// After a low `perf`, how long the scene runs uninterrupted before the app
/// asks again. A first figure can straddle a pause (seen live: `fps: 0`
/// after the scene loaded under a dialog), so it alone never decides.
const village3dPerfRecheck = Duration(seconds: 3);

/// The Village's scene: the 3D village where it can run, the 2D one
/// ([fallback]) everywhere else (ADR 0126).
///
/// Until the 3D village is `ready` the box shows [VillageSceneLoading], the
/// sky and a loader, never the 2D village: showing 2D first and then
/// switching read as a bug (Hafid, 2026-11-10). [fallback] shows only when
/// the 3D one is off or can't run (no channel, `unavailable`, too slow, the
/// ready timeout).
class VillageSceneHost extends ConsumerStatefulWidget {
  const VillageSceneHost({
    required this.state,
    required this.fallback,
    this.onOpen,
    this.onMascot,
    super.key,
  });

  final VillageSceneState state;
  final Widget fallback;

  /// A building the scene reported tapped, by its subject code. Only codes
  /// the app sent reach here, and only for live buildings.
  final ValueChanged<String>? onOpen;
  final VoidCallback? onMascot;

  @override
  ConsumerState<VillageSceneHost> createState() => _VillageSceneHostState();
}

enum _Phase { loading, ready, failed }

class _VillageSceneHostState extends ConsumerState<VillageSceneHost> {
  VillageSceneChannel? _channel;
  StreamSubscription<Object?>? _sub;
  Timer? _timeout;
  AppLifecycleListener? _lifecycle;
  var _phase = _Phase.loading;
  var _foreground = true;
  var _visible = true;

  /// A dialog, sheet or page is over the Village.
  var _covered = false;

  /// What the scene was last told, so a pause or resume is sent once.
  bool? _sentPaused;

  bool get _paused => !_foreground || !_visible || _covered;

  /// What the scene was last told about input.
  bool? _sentInteractive;

  /// A low frame rate waits on a second reading (`getStats`).
  var _perfInDoubt = false;
  var _statsAsked = false;
  Timer? _recheck;

  /// The building whose portal is playing, from `opening` to `open`.
  String? _opening;

  /// Set when the village was hidden or covered while a portal played: the
  /// child went elsewhere, so its late `open` must not pull them to the
  /// Carte once they come back.
  var _openingAbandoned = false;

  void _armRecheck() {
    _recheck?.cancel();
    _statsAsked = false;
    if (!_perfInDoubt || _paused) return;
    _recheck = Timer(village3dPerfRecheck, () {
      if (_perfInDoubt && !_paused) {
        _statsAsked = true;
        _channel?.send(HostMessage.getStats);
      }
    });
  }

  void _onRootCover() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    rootCoverObserver.covered.addListener(_onRootCover);
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        // Not `inactive`: on web a tap into the scene's iframe takes focus
        // from the page, which Flutter reports as inactive. Pausing then
        // froze the village under the child's finger.
        _foreground = switch (state) {
          AppLifecycleState.resumed || AppLifecycleState.inactive => true,
          AppLifecycleState.hidden ||
          AppLifecycleState.paused ||
          AppLifecycleState.detached => false,
        };
        _syncPaused();
      },
    );
  }

  bool get _wanted =>
      ref.read(settingsControllerProvider).village3d &&
      ref.read(village3dSupportProvider);

  void _start() {
    if (_channel != null || _phase == _Phase.failed) return;
    final channel = ref.read(villageSceneChannelFactoryProvider)(
      title: widget.state.signTitle,
    );
    if (channel == null) {
      _phase = _Phase.failed;
      return;
    }
    _channel = channel;
    _phase = _Phase.loading;
    _sentPaused = null;
    _sub = channel.messages.listen(_onMessage);
    _timeout = Timer(village3dReadyTimeout, () {
      if (_phase == _Phase.loading) _fail();
    });
  }

  void _stop() {
    _sentInteractive = null;
    _recheck?.cancel();
    _perfInDoubt = false;
    _channel?.send(HostMessage.dispose);
    _timeout?.cancel();
    _timeout = null;
    _sub?.cancel();
    _sub = null;
    _channel?.dispose();
    _channel = null;
  }

  void _fail() {
    _stop();
    ref.read(village3dSupportProvider.notifier).markUnsupported();
    if (mounted) setState(() => _phase = _Phase.failed);
  }

  void _onMessage(Object? raw) {
    switch (SceneEvent.parse(raw)) {
      case SceneLoading():
        // Answered every time: a scene that reloaded starts blank.
        _channel?.send(HostMessage.init(widget.state));
      case SceneReady():
        // A scene runs from its first frame: only a pause needs sending.
        _sentPaused = false;
        _timeout?.cancel();
        if (_phase != _Phase.ready) setState(() => _phase = _Phase.ready);
        _syncPaused();
      case SceneError():
        break;
      case SceneUnavailable():
        _fail();
      case ScenePerf(:final fps):
        if (fps < village3dMinFps) {
          _perfInDoubt = true;
          _armRecheck();
        }
      case SceneStats(:final fps):
        // Only the reading this host asked for, after an unbroken run.
        if (!_perfInDoubt || !_statsAsked) break;
        _perfInDoubt = false;
        _statsAsked = false;
        if (fps < village3dMinFps) _fail();
      case SceneOpening(:final id):
        // Portal frames are no fair measure of the village: a pending
        // recheck waits until after (the cut pauses and resume re-arms it).
        _opening = id;
        _openingAbandoned = _paused;
        _recheck?.cancel();
        _statsAsked = false;
      case SceneOpen(:final id):
        final abandoned = _openingAbandoned && _opening == id;
        _opening = null;
        _openingAbandoned = false;
        if (abandoned) {
          _armRecheck();
          break;
        }
        final known = widget.state.buildings.any(
          (b) => b.subject == id && b.live,
        );
        if (known) widget.onOpen?.call(id);
      case SceneMascot():
        widget.onMascot?.call();
      case SceneIgnored():
        break;
    }
  }

  void _syncPaused() {
    final channel = _channel;
    if (channel == null || _phase != _Phase.ready) return;
    if (_sentPaused == _paused) return;
    _sentPaused = _paused;
    if (_paused && _opening != null) _openingAbandoned = true;
    channel.send(_paused ? HostMessage.pause : HostMessage.resume);
    // A pause breaks the run a recheck needs; a resume starts a new one.
    _armRecheck();
  }

  @override
  void didUpdateWidget(VillageSceneHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_phase == _Phase.ready && widget.state != oldWidget.state) {
      _channel?.send(HostMessage.update(widget.state));
    }
  }

  @override
  void dispose() {
    rootCoverObserver.covered.removeListener(_onRootCover);
    _lifecycle?.dispose();
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watched, so turning the setting off (or a failure elsewhere) drops
    // the scene at once, and turning it back on starts one.
    final setting = ref.watch(
      settingsControllerProvider.select((s) => s.village3d),
    );
    final supported = ref.watch(village3dSupportProvider);
    if (!setting || !supported) {
      if (_channel != null) _stop();
      if (!supported) _phase = _Phase.failed;
      return widget.fallback;
    }
    if (_phase == _Phase.failed && supported) _phase = _Phase.loading;
    if (_wanted) _start();
    final channel = _channel;
    if (channel == null) return widget.fallback;

    // Hidden behind another tab of the shell's IndexedStack, or under a
    // dialog, sheet or pushed page: pause. Both lookups rebuild this widget
    // when they change.
    _visible = Visibility.of(context);
    _covered =
        !(ModalRoute.of(context)?.isCurrent ?? true) ||
        rootCoverObserver.covered.value;
    _syncPaused();
    // A native layer would draw over the dialog: take it off screen, with
    // the loader's sky in its place until the dialog closes.
    final lifted = _covered && channel.drawsAboveFlutter;
    final interactive = _phase == _Phase.ready && !_covered;
    if (_sentInteractive != interactive) {
      _sentInteractive = interactive;
      channel.setInteractive(interactive);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        if (!lifted)
          KeyedSubtree(
            key: const ValueKey('village-3d-view'),
            child: channel.buildView(),
          ),
        if (_phase != _Phase.ready || lifted)
          VillageSceneLoading(loading: _phase != _Phase.ready),
      ],
    );
  }
}
