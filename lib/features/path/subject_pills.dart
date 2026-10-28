import 'package:flutter/material.dart';

import '../../core/i18n/strings.dart';
import '../../core/widgets/pill_tabs.dart';
import 'path_controller.dart';

/// The subject buildings, shared with the Village, keyed by backend code.
const subjectArt = {
  'MATH': 'asset-bldg-math.webp',
  'FR': 'asset-bldg-francais.webp',
  'EN': 'asset-bldg-anglais.webp',
  'SCI': 'asset-bldg-science.webp',
  'SOC': 'asset-bldg-univers-social.webp',
  'CCQ': 'asset-bldg-ccq.webp',
};

String subjectLabel(Strings t, String code) => switch (code) {
  'MATH' => t.subjectMath,
  'FR' => t.subjectFrancais,
  'EN' => t.subjectAnglais,
  'SCI' => t.subjectScience,
  'SOC' => t.subjectUniversSocial,
  'CCQ' => t.subjectCulture,
  _ => code,
};

/// `.subject-tabs`: the subject pills, the building as each icon.
/// Shared by the Carte and Progrès, which the design draws identically; the
/// row itself is the app-wide [PillTabs].
class SubjectPills extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final t = context.s;
    return PillTabs<String>(
      keyPrefix: 'subject-pill',
      selected: selected,
      compact: compact,
      onSelect: onSelect,
      tabs: [
        for (final code in pathSubjects)
          PillTab(
            value: code,
            label: subjectLabel(t, code),
            leading: Image.asset(
              'assets/images/${subjectArt[code]}',
              fit: BoxFit.contain,
            ),
          ),
      ],
    );
  }
}
