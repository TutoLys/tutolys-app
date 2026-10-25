import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../core/i18n/strings.dart';
import '../../core/widgets/breathing_mascot.dart';

/// One question and its answer.
class HelpEntry {
  const HelpEntry({required this.question, required this.answer});
  final String question;
  final String answer;
}

/// Aide & support — the design's FAQ, written for the kid reading it.
///
/// The answers are the design's own copy rather than paraphrases: they are
/// pitched at a child ("Pas de panique !") and point at where to go in the
/// app, which is harder to get right than it looks.
///
/// Two answers were trimmed against the design: the coins one no longer
/// promises a Boutique, and the streak one no longer tells a kid to look for
/// a bouclier de série in Quêtes. Both of those exist in the design's intent
/// but not in the app, and a FAQ that sends a child to a screen that cannot
/// help them is worse than one that says less.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    final t = context.s;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Space.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const BreathingMascot(height: 86),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.helpTitle,
                          style: TextStyle(
                            fontFamily: VillageType.display,
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                            color: p.ink,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          t.helpSubtitle,
                          style: TextStyle(fontSize: 13, color: p.inkMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.lg),
              Material(
                color: p.surface,
                borderRadius: VillageMetrics.mdAll,
                elevation: VillageColors.elevationSmall,
                shadowColor: p.shadowSmall,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Space.md,
                    vertical: Space.xs,
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: Space.sm),
                        child: Row(
                          children: [
                            Icon(Icons.help_outline, size: 18, color: p.quebecBlue),
                            const SizedBox(width: Space.xs),
                            Text(
                              t.helpFaqTitle,
                              style: TextStyle(
                                fontFamily: VillageType.display,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: p.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                      for (final entry in t.helpEntries)
                        _FaqTile(entry: entry, palette: p),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Space.md),
              _ParentContact(palette: p, strings: t),
              const SizedBox(height: Space.xl),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.entry, required this.palette});

  final HelpEntry entry;
  final VillagePalette palette;

  @override
  Widget build(BuildContext context) {
    return Theme(
      // An ExpansionTile's default dividers fight the card's own hairlines;
      // the rows already read as a list without them.
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: Space.sm),
        iconColor: palette.quebecBlueBright,
        collapsedIconColor: palette.inkMuted,
        title: Text(
          entry.question,
          style: TextStyle(
            fontFamily: VillageType.display,
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
            color: palette.ink,
          ),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              entry.answer,
              style: TextStyle(fontSize: 13, height: 1.45, color: palette.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Pour les parents" — the one block on a kid's screen aimed at an adult.
///
/// It does not open a mail client: no support address is configured
/// anywhere, and a button that opens an empty message to nobody is worse
/// than a line that says where to go. Points at the website, which is where
/// account and billing live.
class _ParentContact extends StatelessWidget {
  const _ParentContact({required this.palette, required this.strings});

  final VillagePalette palette;
  final Strings strings;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: palette.quebecBlue,
      borderRadius: VillageMetrics.mdAll,
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Row(
          children: [
            const Icon(Icons.mail_outline, color: Colors.white, size: 22),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.helpParentsTitle,
                    style: const TextStyle(
                      fontFamily: VillageType.display,
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    strings.helpParentsBody,
                    style: const TextStyle(fontSize: 12, color: Color(0xFFC9D8F5)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
