import 'dart:math' as math;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'shell_strings.dart';

/// What the child did, for the end-of-exercise screen.
class ActivitySummary {
  const ActivitySummary({
    required this.questions,
    required this.solved,
    required this.firstTry,
    required this.xp,
    this.practice = false,
  });

  final int questions;
  final int solved;

  /// Questions right on the first attempt.
  final int firstTry;

  /// The client-side estimate (`estimateXp`); the backend's ledger is the
  /// real total.
  final int xp;

  /// Practice pays no XP (Hafid, N14). The celebration then shows a calm
  /// « Entraînement » label instead of a gold « +0 XP », which a
  /// 6-year-old reads as having earned nothing (UX review K18).
  final bool practice;

  bool get perfect => questions > 0 && firstTry == questions;

  /// Questions the child got right after a retry: fixed by themself.
  int get fixed => (solved - firstTry).clamp(0, questions);
}

/// The moment after the last question — the design's end-of-series panel
/// ("Mise à jour des quêtes !"), made into a celebration.
///
/// A burst of stars behind the character, the XP counting up into a gold
/// pill, what the child got right, then a gold Continuer. [extraRows] is
/// where the host adds what this package can't know — daily-quest progress,
/// a streak extended — in the design's row style ([CelebrationRow]).
///
/// Reduced motion: no burst and no count-up; the numbers simply appear.
/// Nothing here waits on an animation: Continuer works from the first frame.
class ActivityCompleteView extends StatelessWidget {
  const ActivityCompleteView({
    required this.summary,
    required this.locale,
    required this.onContinue,
    this.onNext,
    this.character,
    this.title,
    this.extraRows = const [],
    super.key,
  });

  final ActivitySummary summary;
  final Locale locale;

  /// Back to the Carte. The only button when there's no [onNext].
  final VoidCallback onContinue;

  /// The next lesson (UX review G12: the celebration was a dead end, at the
  /// peak of motivation). When set, « Suivant » is the gold primary button
  /// and Enter's action, and « Retour à la carte » ([onContinue]) sits
  /// under it. Null: the host has no next lesson, and Continuer stays.
  final VoidCallback? onNext;
  final Widget? character;

  /// Overrides the default title (e.g. with the child's name).
  final String? title;
  final List<Widget> extraRows;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    final s = ShellStrings.of(locale);
    final still = MediaQuery.disableAnimationsOf(context);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter): onNext ?? onContinue,
      },
      child: Focus(
        autofocus: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [p.skyTop, p.skyBottom],
            ),
          ),
          // CONTINUER is pinned below the scrolling content: on a short
          // screen, or with quest rows, a child must never have to scroll
          // to find the way out.
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(Space.lg),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              height: 190,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  if (!still)
                                    const Positioned.fill(child: _StarBurst()),
                                  if (character != null)
                                    SizedBox.square(
                                      dimension: 150,
                                      child: character,
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: Space.sm),
                            Semantics(
                              header: true,
                              child: Text(
                                title ??
                                    (summary.perfect
                                        ? s.perfectTitle
                                        : s.doneTitle),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: VillageType.display,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                  color: p.ink,
                                ),
                              ),
                            ),
                            const SizedBox(height: Space.md),
                            if (summary.practice)
                              _PracticeLabel(label: s.practiceLabel)
                            else
                              _XpPill(
                                xp: summary.xp,
                                animate: !still,
                                label: s.xpEarnedLabel,
                              ),
                            const SizedBox(height: Space.lg),
                            // Not « N/N bonnes réponses »: retries are
                            // unlimited, so that was always full (UX review
                            // G15). First try out of all, and the ones the
                            // child fixed by themself, which deserve praise.
                            Row(
                              children: [
                                Expanded(
                                  child: _StatCard(
                                    icon: Icons.bolt_rounded,
                                    color: p.gold,
                                    value:
                                        '${summary.firstTry}/${summary.questions}',
                                    label: s.firstTryLabel,
                                  ),
                                ),
                                if (summary.fixed > 0) ...[
                                  const SizedBox(width: Space.sm),
                                  Expanded(
                                    child: _StatCard(
                                      icon: Icons.auto_fix_high_rounded,
                                      color: p.success,
                                      value: '${summary.fixed}',
                                      label: s.fixedLabel,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (extraRows.isNotEmpty) ...[
                              const SizedBox(height: Space.md),
                              for (final row in extraRows) ...[
                                row,
                                const SizedBox(height: Space.xs),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Space.lg,
                    0,
                    Space.lg,
                    Space.lg,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: SizedBox(
                      width: double.infinity,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: Radii.cardMd,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [p.goldLight, p.gold],
                          ),
                        ),
                        child: TextButton(
                          key: ValueKey(
                            onNext == null
                                ? 'complete-continue'
                                : 'complete-next',
                          ),
                          onPressed: onNext ?? onContinue,
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF241A04),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: const RoundedRectangleBorder(
                              borderRadius: Radii.cardMd,
                            ),
                          ),
                          child: Text(
                            (onNext == null ? s.continueLabel : s.nextLesson)
                                .toUpperCase(),
                            style: const TextStyle(
                              fontFamily: VillageType.display,
                              fontWeight: FontWeight.w800,
                              letterSpacing: .4,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (onNext != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.md),
                    child: TextButton.icon(
                      key: const ValueKey('complete-back-to-map'),
                      onPressed: onContinue,
                      style: TextButton.styleFrom(
                        foregroundColor: p.ink,
                        minimumSize: const Size(48, 48),
                      ),
                      icon: const Icon(Icons.map_rounded),
                      label: Text(
                        s.backToMap,
                        style: const TextStyle(
                          fontFamily: VillageType.display,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One line of progress on the celebration screen — the design's
/// `.quest-update-row`: an icon, a label, a bar and "3/5".
class CelebrationRow extends StatelessWidget {
  const CelebrationRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.max,
    super.key,
  });

  final IconData icon;
  final String label;
  final int value;
  final int max;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    final fraction = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.md,
        vertical: Space.sm,
      ),
      decoration: BoxDecoration(color: p.surface, borderRadius: Radii.cardMd),
      child: Row(
        children: [
          Icon(icon, color: p.quebecBlueBright, size: 20),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontWeight: FontWeight.w700, color: p.ink),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: Radii.pillAll,
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 6,
                    backgroundColor: p.track,
                    color: p.gold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Space.sm),
          Text(
            '$value/$max',
            style: TextStyle(fontWeight: FontWeight.w700, color: p.inkMuted),
          ),
        ],
      ),
    );
  }
}

/// Practice's end: what this round was, with no number.
class _PracticeLabel extends StatelessWidget {
  const _PracticeLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    return Container(
      key: const ValueKey('complete-practice'),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: Radii.pillAll,
        color: p.navHoverFill,
        border: Border.all(color: p.quebecBlueBright, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.replay_rounded,
            color: p.isDark ? p.quebecBlueBright : p.quebecBlue,
            size: 24,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontFamily: VillageType.display,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: p.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _XpPill extends StatelessWidget {
  const _XpPill({required this.xp, required this.animate, required this.label});
  final int xp;
  final bool animate;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    Widget pill(int shown) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: Radii.pillAll,
        gradient: LinearGradient(colors: [p.goldLight, p.gold]),
        boxShadow: [
          BoxShadow(
            color: p.gold.withValues(alpha: .35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: Colors.white, size: 30),
          const SizedBox(width: 8),
          Text(
            '+$shown XP',
            style: const TextStyle(
              fontFamily: VillageType.display,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Color(0xFF241A04),
            ),
          ),
        ],
      ),
    );

    return Semantics(
      label: '$label : $xp',
      excludeSemantics: true,
      child: animate
          ? TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 1100),
              curve: Curves.easeOutBack,
              builder: (context, t, _) => Transform.scale(
                scale: 0.6 + 0.4 * t.clamp(0.0, 1.2),
                child: pill((xp * t.clamp(0.0, 1.0)).round()),
              ),
            )
          : pill(xp),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    return Container(
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: Radii.cardMd,
        boxShadow: [
          BoxShadow(
            color: p.shadowSmall,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color,
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(height: Space.xs),
          Text(
            value,
            style: TextStyle(
              fontFamily: VillageType.display,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: p.ink,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: p.inkMuted),
          ),
        ],
      ),
    );
  }
}

/// Stars flying out from behind the character, once.
class _StarBurst extends StatelessWidget {
  const _StarBurst();

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1400),
        curve: Curves.easeOutCubic,
        builder: (context, t, _) => CustomPaint(
          painter: _BurstPainter(t, [
            p.gold,
            p.goldLight,
            p.quebecBlueBright,
            p.success,
          ]),
        ),
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.t, this.colors);
  final double t;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final reach = size.shortestSide * 0.62;
    const count = 14;
    for (var i = 0; i < count; i++) {
      final angle = (i / count) * 2 * math.pi + (i.isEven ? 0.12 : -0.08);
      final dist = reach * t * (0.75 + 0.25 * ((i * 37) % 10) / 10);
      final pos = c + Offset(math.cos(angle), math.sin(angle)) * dist;
      final r = (i.isEven ? 7.0 : 5.0) * (1 - 0.35 * t);
      final paint = Paint()
        ..color = colors[i % colors.length].withValues(
          alpha: (1 - t * 0.6).clamp(0.0, 1.0),
        );
      canvas.drawPath(_star(pos, r), paint);
    }
  }

  Path _star(Offset o, double r) {
    final path = Path();
    for (var k = 0; k < 10; k++) {
      final rr = k.isEven ? r : r * 0.45;
      final a = -math.pi / 2 + k * math.pi / 5;
      final pt = o + Offset(math.cos(a), math.sin(a)) * rr;
      k == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}
