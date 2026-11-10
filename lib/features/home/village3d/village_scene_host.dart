import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/settings_controller.dart';
import 'village_bridge.dart';
import 'village_channel.dart';

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

/// How long a scene has to say it's ready before the 2D village stays.
const village3dReadyTimeout = Duration(seconds: 20);

/// The Village's scene: the 3D village where it can run, the 2D one
/// ([fallback]) everywhere else (ADR 0126).
///
/// The 2D village is shown while the 3D one loads, so a device that can't
/// run it never sees an empty box: it just keeps the village it had.
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

  /// What the scene was last told, so a pause or resume is sent once.
  bool? _sentPaused;

  bool get _paused => !_foreground || !_visible;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        _foreground = state == AppLifecycleState.resumed;
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
      case SceneReady():
        // Sent again on every ready: a scene that reloaded starts blank.
        _channel?.send(HostMessage.init(widget.state));
        _sentPaused = null;
        _syncPaused();
        _timeout?.cancel();
        if (_phase != _Phase.ready) setState(() => _phase = _Phase.ready);
      case SceneUnavailable():
        _fail();
      case ScenePerf(:final fps):
        // A figure measured while paused says nothing about the device.
        if (!_paused && fps < village3dMinFps) _fail();
      case SceneOpen(:final id):
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
    channel.send(_paused ? HostMessage.pause : HostMessage.resume);
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

    // Hidden behind another tab of the shell's IndexedStack: pause.
    _visible = Visibility.of(context);
    _syncPaused();

    return Stack(
      fit: StackFit.expand,
      children: [
        KeyedSubtree(
          key: const ValueKey('village-3d-view'),
          child: channel.buildView(),
        ),
        if (_phase != _Phase.ready)
          KeyedSubtree(
            key: const ValueKey('village-3d-loading'),
            child: widget.fallback,
          ),
      ],
    );
  }
}
