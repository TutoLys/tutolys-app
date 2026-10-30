import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/page_column.dart';
import '../../core/diagnostics/boot_log.dart';
import '../../core/diagnostics/diag_log.dart';
import '../../core/i18n/strings.dart';
import '../../core/widgets/fleur_de_lys.dart';
import '../pairing/pairing_controller.dart';
import '../path/path_controller.dart' show contentSyncProvider;
import '../qa/qa_lesson_picker.dart';

/// À propos de TutoLys.
///
/// Deliberately small. It exists so the row in Réglages leads somewhere real,
/// and so a parent or a support conversation has a version number to quote —
/// which is the only genuinely load-bearing thing on it.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    final t = context.s;

    return PageColumn(
      maxWidth: 560,
      wideMaxWidth: PageWidth.column,
      child: Column(
        children: [
          const SizedBox(height: Space.lg),
          Image.asset(
            'assets/images/asset-logo.webp',
            height: 72,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: Space.md),
          Text(
            'TutoLys',
            style: TextStyle(
              fontFamily: VillageType.display,
              fontWeight: FontWeight.w800,
              fontSize: 26,
              color: p.quebecBlue,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            t.aboutTagline,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: p.inkMuted),
          ),
          const SizedBox(height: Space.lg),
          Material(
            color: p.surface,
            borderRadius: VillageMetrics.mdAll,
            elevation: VillageColors.elevationSmall,
            shadowColor: p.shadowSmall,
            child: Padding(
              padding: const EdgeInsets.all(Space.md),
              child: Column(
                children: [
                  // A long-press opens the technical log, for an adult
                  // helping with support (ADR 0038). Nothing in it
                  // leaves the device.
                  GestureDetector(
                    onLongPress: () => _openTechnicalLog(context),
                    child: _Row(label: t.aboutVersion, value: appVersion, p: p),
                  ),
                  Divider(height: Space.lg, color: p.line),
                  _Row(label: t.aboutCurriculum, value: 'PFEQ', p: p),
                ],
              ),
            ),
          ),
          const SizedBox(height: Space.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                t.aboutMadeIn,
                style: TextStyle(fontSize: 12, color: p.inkMuted),
              ),
              const SizedBox(width: 5),
              const FleurDeLys(key: ValueKey('about-fleur-de-lys'), size: 14),
            ],
          ),
          const SizedBox(height: Space.xl),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, required this.p});

  final String label;
  final String value;
  final VillagePalette p;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: VillageType.display,
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: p.ink,
            ),
          ),
        ),
        SelectableText(
          value,
          style: TextStyle(
            fontFamily: VillageType.display,
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: p.inkMuted,
          ),
        ),
      ],
    );
  }
}

/// The technical log, with what the offline window holds and has evicted
/// (ADR 0095). Sizes and counts only: no lesson text, no kid.
Future<void> _openTechnicalLog(BuildContext context) async {
  var offline = const <String>[];
  try {
    final stats = await ProviderScope.containerOf(
      context,
      listen: false,
    ).read(contentSyncProvider).offlineStats();
    offline = stats.describe();
  } on Object {
    // No database here (a test, a broken boot): the log still opens.
  }
  if (!context.mounted) return;
  await showTechnicalLog(context, offline: offline);
}

/// The on-device technical log: boot steps, this run's errors and the
/// previous run's (ADR 0038), then [offline]'s cache lines.
Future<void> showTechnicalLog(
  BuildContext context, {
  BootLog? bootLog,
  DiagLog? diagLog,
  List<String> offline = const [],
  bool qaTools = qaToolsEnabled,
}) {
  final boot = bootLog ?? BootLog.instance;
  final diag = diagLog ?? DiagLog.instance;
  final t = context.s;
  final lines = [
    for (final step in boot.steps) step.describe(),
    for (final entry in diag.entries.reversed) '$entry',
    if (diag.previousRun.isNotEmpty) ...[
      '— ${t.bootPreviousRun} —',
      for (final entry in diag.previousRun.reversed) '$entry',
    ],
    ...offline,
  ];
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(t.diagJournalTitle),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: SelectableText(
            lines.isEmpty ? t.diagEmpty : lines.join('\n'),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
      ),
      actions: [
        // QA builds only (ADR 0100): a release build compiles this out.
        if (qaTools)
          TextButton(
            key: const ValueKey('qa-open-picker'),
            onPressed: () {
              final navigator = Navigator.of(context);
              navigator.pop();
              navigator.push(
                MaterialPageRoute<void>(
                  builder: (_) => const QaLessonPicker(),
                ),
              );
            },
            child: const Text('QA · lessons'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).closeButtonLabel),
        ),
      ],
    ),
  );
}
