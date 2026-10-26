import 'dart:async';
import 'dart:math' as math;

import 'package:design_system/design_system.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../core/diagnostics/boot_log.dart';
import '../../core/diagnostics/diag_log.dart';
import '../../data/local_db/session_store.dart';
import 'boot_handoff.dart';
import 'boot_stuck_view.dart';
import 'tutolys_loader_screen.dart';
import 'tutolys_welcome_screen.dart';

/// How far startup has really got. Each value is a fact `AppShell` already
/// knows, not a guess.
enum LaunchStage {
  /// Flutter is running; the device session is being restored.
  restoring,

  /// The session is known; a paired kid's settings are still being read.
  sessionResolved,

  /// Everything the first real screen needs is in memory.
  ready,
}

/// Loader → welcome → [onFinished], once per cold start.
///
/// The bar is driven by [stage]. Each stage owns a span of the bar, and
/// while waiting inside one the fill creeps toward that span's end but never
/// reaches it — so a slow secure-store read still looks alive, and the bar
/// can only cross a span's end when the stage really changes. On web the
/// HTML loader has already covered the download (`readBootHandoff`), and
/// this continues from wherever it stopped.
///
/// Once [stage] is [LaunchStage.ready] the bar fills, "Bienvenue dans
/// TutoLys !" shows for one short beat, and the welcome screen takes over.
/// No minimum time anywhere: a fast start is a short loader.
class LaunchFlow extends StatefulWidget {
  const LaunchFlow({
    required this.stage,
    required this.onFinished,
    this.kidName,
    this.kids,
    this.onPickKid,
    this.onAddProfile,
    this.startProgress,
    this.onRetry,
    this.bootLog,
    this.diagLog,
    this.stuckAfter = defaultStuckAfter,
    super.key,
  });

  /// Re-runs boot from the stuck screen. Without it there is no stuck
  /// screen, only the loader.
  final VoidCallback? onRetry;

  /// What the stuck screen's "Détails" shows. Default to the app's own.
  final BootLog? bootLog;
  final DiagLog? diagLog;

  /// How long the loader may stay up before the stuck screen replaces it
  /// (ADR 0038).
  final Duration stuckAfter;
  static const Duration defaultStuckAfter = Duration(seconds: 15);

  final LaunchStage stage;

  /// The paired kid's name for the welcome screen, or null if unpaired.
  final String? kidName;

  /// Called when the child presses the welcome screen's button.
  final VoidCallback onFinished;

  /// With several kids paired here, the welcome screen is the picker: see
  /// [TutolysWelcomeScreen.kids].
  final List<PairedKid>? kids;
  final ValueChanged<String>? onPickKid;
  final VoidCallback? onAddProfile;

  /// Where the bar starts. Defaults to what the web HTML stage reached, or
  /// a small head start on desktop.
  final double? startProgress;

  /// How long "Bienvenue dans TutoLys !" stays up once the bar is full —
  /// long enough to read the line and see the bar land, no longer.
  static const Duration doneBeat = Duration(milliseconds: 900);
  static const Duration doneBeatReduced = Duration(milliseconds: 500);

  static const Duration _creepTick = Duration(milliseconds: 250);

  @override
  State<LaunchFlow> createState() => _LaunchFlowState();
}

enum _Phase { loading, stuck, done, welcome }

class _LaunchFlowState extends State<LaunchFlow> {
  late final BootHandoff? _handoff = readBootHandoff();

  late final double _start =
      widget.startProgress ?? _handoff?.progress ?? (kIsWeb ? 0.6 : 0.08);

  late double _progress = _start;
  _Phase _phase = _Phase.loading;
  Timer? _creep;
  Timer? _beat;
  Timer? _stuckTimer;

  /// The end of the span the current stage owns.
  double get _ceiling => _ceilingFor(widget.stage);

  double _ceilingFor(LaunchStage stage) => switch (stage) {
        LaunchStage.restoring => _start + (1 - _start) * 0.55,
        LaunchStage.sessionResolved => _start + (1 - _start) * 0.9,
        LaunchStage.ready => 1.0,
      };

  @override
  void initState() {
    super.initState();
    _onStage();
    _armStuckTimer();
  }

  /// Boot that hasn't finished after [LaunchFlow.stuckAfter] shows the
  /// stuck screen instead of a loader that never ends.
  void _armStuckTimer() {
    _stuckTimer?.cancel();
    if (widget.onRetry == null) return;
    _stuckTimer = Timer(widget.stuckAfter, () {
      if (mounted && _phase == _Phase.loading) {
        setState(() => _phase = _Phase.stuck);
      }
    });
  }

  void _retry() {
    setState(() => _phase = _Phase.loading);
    _armStuckTimer();
    widget.onRetry?.call();
  }

  @override
  void didUpdateWidget(LaunchFlow old) {
    super.didUpdateWidget(old);
    if (old.stage != widget.stage) {
      // The stage really changed, so the bar may cross the old span's end.
      _progress = math.max(_progress, _ceilingFor(old.stage));
      _onStage();
    }
  }

  @override
  void dispose() {
    _creep?.cancel();
    _beat?.cancel();
    _stuckTimer?.cancel();
    super.dispose();
  }

  void _onStage() {
    // Boot finishing while the stuck screen is up simply carries on.
    if (_phase == _Phase.stuck && widget.stage == LaunchStage.ready) {
      _phase = _Phase.loading;
    }
    if (_phase != _Phase.loading) return;
    if (widget.stage == LaunchStage.ready) {
      _stuckTimer?.cancel();
      _creep?.cancel();
      _creep = null;
      _progress = 1;
      _phase = _Phase.done;
      // Read here, in a post-frame callback, because initState may run
      // before inherited widgets are reachable.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final still = MediaQuery.disableAnimationsOf(context);
        _beat = Timer(
          still ? LaunchFlow.doneBeatReduced : LaunchFlow.doneBeat,
          () {
            if (mounted) setState(() => _phase = _Phase.welcome);
          },
        );
      });
      if (mounted) setState(() {});
      return;
    }
    // Creep toward this stage's span end (see `_ceiling`).
    _creep ??= Timer.periodic(LaunchFlow._creepTick, (_) {
      // Close 8 % of the remaining gap each tick, stopping just short of
      // the ceiling: the last 2 % of a span is reserved for the stage
      // actually changing.
      final target = _ceiling - 0.02;
      if (_progress >= target) return;
      setState(() => _progress = math.min(target, _progress + (target - _progress) * 0.08));
    });
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: still ? Duration.zero : Motion.slow,
      switchInCurve: Motion.enter,
      switchOutCurve: Motion.exit,
      child: _phase == _Phase.stuck
          ? BootStuckView(
              key: const ValueKey('stuck'),
              onRetry: _retry,
              bootLog: widget.bootLog ?? BootLog.instance,
              diagLog: widget.diagLog ?? DiagLog.instance,
            )
          : _phase == _Phase.welcome
          ? TutolysWelcomeScreen(
              key: const ValueKey('welcome'),
              kidName: widget.kidName,
              onStart: widget.onFinished,
              kids: widget.kids,
              onPickKid: widget.onPickKid,
              onAddProfile: widget.onAddProfile,
            )
          : TutolysLoaderScreen(
              key: const ValueKey('loader'),
              progress: _progress,
              done: _phase == _Phase.done,
              firstMessage: _handoff?.messageIndex ?? 0,
            ),
    );
  }
}
