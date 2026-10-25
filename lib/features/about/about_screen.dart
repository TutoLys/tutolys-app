import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../core/i18n/strings.dart';
import '../pairing/pairing_controller.dart';

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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Space.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
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
                      _Row(label: t.aboutVersion, value: appVersion, p: p),
                      Divider(height: Space.lg, color: p.line),
                      _Row(label: t.aboutCurriculum, value: 'PFEQ', p: p),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Space.md),
              Text(
                t.aboutMadeIn,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: p.inkMuted),
              ),
              const SizedBox(height: Space.xl),
            ],
          ),
        ),
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
