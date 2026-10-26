import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../core/diagnostics/boot_log.dart';
import '../../core/diagnostics/diag_log.dart';
import '../../core/i18n/strings.dart';
import 'widgets/launch_backdrop.dart';

/// Shown instead of a loader that never ends (ADR 0038).
///
/// Calm and child-safe: a short line and "Réessayer". The adult's view is
/// behind "Détails": the boot steps, the one boot is waiting on, and the
/// recent errors. No red, no stack trace unless asked for.
class BootStuckView extends StatefulWidget {
  const BootStuckView({
    required this.onRetry,
    required this.bootLog,
    required this.diagLog,
    super.key,
  });

  final VoidCallback onRetry;
  final BootLog bootLog;
  final DiagLog diagLog;

  @override
  State<BootStuckView> createState() => _BootStuckViewState();
}

class _BootStuckViewState extends State<BootStuckView> {
  var _details = false;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final stuck = widget.bootLog.stuckOn;
    return Material(
      color: LaunchBackdrop.night,
      child: LaunchBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      s.bootStuckTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: VillageType.display,
                        fontWeight: FontWeight.w700,
                        fontSize: 26,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      s.bootStuckBody,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: widget.onRetry,
                      child: Text(s.retry),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => setState(() => _details = !_details),
                      child: Text(
                        s.bootDetails,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                    if (_details)
                      _Details(
                        stuckOn: stuck == null
                            ? null
                            : s.bootStuckOn(stuck.name),
                        lines: [
                          for (final step in widget.bootLog.steps)
                            step.describe(),
                          for (final entry in widget.diagLog.entries.reversed)
                            '$entry',
                          if (widget.diagLog.previousRun.isNotEmpty) ...[
                            '— ${s.bootPreviousRun} —',
                            for (final entry
                                in widget.diagLog.previousRun.reversed)
                              '$entry',
                          ],
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.stuckOn, required this.lines});

  final String? stuckOn;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SelectableText(
        [?stuckOn, ...lines].join('\n'),
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: Colors.white.withValues(alpha: 0.85),
        ),
      ),
    );
  }
}
