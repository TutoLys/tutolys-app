import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../core/i18n/strings.dart';
import 'path_controller.dart';

/// The subject buildings, shared with the Village, keyed by backend code.
const subjectArt = {
  'MATH': 'asset-bldg-math.webp',
  'FR': 'asset-bldg-francais.webp',
  'EN': 'asset-bldg-anglais.webp',
  'SCI': 'asset-bldg-science.webp',
  'SOC': 'asset-bldg-univers-social.webp',
};

String subjectLabel(Strings t, String code) => switch (code) {
  'MATH' => t.subjectMath,
  'FR' => t.subjectFrancais,
  'EN' => t.subjectAnglais,
  'SCI' => t.subjectScience,
  'SOC' => t.subjectUniversSocial,
  _ => code,
};

/// `.subject-tabs`: a scrolling row of pills, the building as each icon.
/// Shared by the Carte and Progrès, which the design draws identically.
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
    final p = VillagePalette.of(context);
    final t = context.s;

    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 14 : 18),
      child: SizedBox(
        height: compact ? 38 : 46,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: pathSubjects.length,
          separatorBuilder: (_, _) => SizedBox(width: compact ? 8 : 10),
          itemBuilder: (context, i) {
            final code = pathSubjects[i];
            final active = code == selected;
            return Material(
              // `.subject-tab.is-active { background: #E8F0FF; border: none }`
              color: active ? p.navActiveFill : p.surface,
              shape: StadiumBorder(
                side: active
                    ? BorderSide.none
                    : BorderSide(color: p.line),
              ),
              child: InkWell(
                key: ValueKey('subject-pill-$code'),
                customBorder: const StadiumBorder(),
                onTap: active ? null : () => onSelect(code),
                mouseCursor: active
                    ? SystemMouseCursors.basic
                    : SystemMouseCursors.click,
                child: Padding(
                  padding: compact
                      ? const EdgeInsets.fromLTRB(6, 6, 13, 6)
                      : const EdgeInsets.fromLTRB(8, 7, 16, 7),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/${subjectArt[code]}',
                        width: compact ? 24 : 30,
                        height: compact ? 24 : 30,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        subjectLabel(t, code),
                        style: TextStyle(
                          fontFamily: VillageType.display,
                          fontWeight: FontWeight.w700,
                          fontSize: compact ? 12 : 13,
                          color: active ? p.quebecBlueBright : p.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
