import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/strings.dart';
import '../../core/widgets/pill_tabs.dart';
import 'programme.dart';

/// The subject buildings, shared with the Village, keyed by backend code.
const subjectArt = {
  'MATH': 'asset-bldg-math.webp',
  'FR': 'asset-bldg-francais.webp',
  'EN': 'asset-bldg-anglais.webp',
  'SCI': 'asset-bldg-science.webp',
  'SOC': 'asset-bldg-univers-social.webp',
  'CCQ': 'asset-bldg-ccq.webp',
  // The second languages wear their language's building until they have
  // their own art (ADR 0101, docs/design/SECOND_LANGUAGES.md).
  'ESL': 'asset-bldg-anglais.webp',
  'FLS': 'asset-bldg-francais.webp',
};

/// A subject the app has no art for yet: a new code the backend started
/// serving. It still gets a pill, under a generic building.
const subjectArtFallback = 'asset-bldg-ccq.webp';

String subjectLabel(Strings t, String code) => switch (code) {
  'MATH' => t.subjectMath,
  'FR' => t.subjectFrancais,
  'EN' => t.subjectAnglais,
  'SCI' => t.subjectScience,
  'SOC' => t.subjectUniversSocial,
  'CCQ' => t.subjectCulture,
  // A child knows the subject by its language: « Anglais » at a French
  // school, « French » at an English one. They never have both pairs.
  'ESL' => t.subjectAnglais,
  'FLS' => t.subjectFrancais,
  _ => code,
};

/// `.subject-tabs`: the subject pills, the building as each icon.
/// Shared by the Carte and Progrès, which the design draws identically; the
/// row itself is the app-wide [PillTabs].
class SubjectPills extends ConsumerWidget {
  const SubjectPills({
    required this.selected,
    required this.compact,
    required this.onSelect,
    super.key,
  });

  final String selected;
  final bool compact;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.s;
    return PillTabs<String>(
      keyPrefix: 'subject-pill',
      selected: selected,
      compact: compact,
      onSelect: onSelect,
      tabs: [
        for (final code in ref.watch(programmeSubjectsProvider))
          PillTab(
            value: code,
            label: subjectLabel(t, code),
            leading: Image.asset(
              'assets/images/${subjectArt[code] ?? subjectArtFallback}',
              fit: BoxFit.contain,
            ),
          ),
      ],
    );
  }
}
