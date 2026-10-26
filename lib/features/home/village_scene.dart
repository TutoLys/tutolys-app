import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../core/i18n/strings.dart';
import '../../core/widgets/breathing_mascot.dart';
import '../path/path_controller.dart' show pathSubjects;

/// One subject's building in the village.
class VillageBuilding {
  const VillageBuilding({
    required this.label,
    required this.asset,
    required this.subject,
    required this.left,
    required this.top,
    this.live = true,
    this.accent = VillageColors.quebecBlueBright,
    this.small = false,
    this.progress,
  });

  final String label;
  final String asset;

  /// The subject code the backend and the Carte use (`MATH`, `FR`, …).
  /// Tapping the building opens this subject on the Carte.
  final String subject;

  /// Whether the subject has curriculum to play. A building that is not
  /// live is drawn greyed out with a "bientôt" tag and does nothing on tap:
  /// the village shows every subject the program will cover, and lights
  /// each one up as its content lands.
  final bool live;

  /// Fractions of the scene, from the design's own inline positions.
  final double left;
  final double top;

  final Color accent;

  /// CCQ is drawn smaller than the rest in the design.
  final bool small;

  /// 0..1. Null means nothing has been measured for this subject yet, and
  /// renders as an empty track — which is what "no progress recorded" looks
  /// like, and is true for a kid who has not played it.
  ///
  /// The backend reports overall mastery with no per-subject breakdown
  /// today, so every one of these is null in practice. The track is drawn
  /// regardless: the design needs it, and an empty bar reads as zero rather
  /// than as a missing feature.
  final double? progress;

  VillageBuilding withProgress(double? value) => VillageBuilding(
    label: label,
    asset: asset,
    subject: subject,
    live: live,
    left: left,
    top: top,
    accent: accent,
    small: small,
    progress: value,
  );
}

/// Every subject building, at the exact positions the design places them:
/// the six academic subjects of Québec's primary program that this app
/// covers. Live or not, every one is drawn, so the village never changes
/// shape as subjects arrive.
///
/// A function of [Strings] rather than a const list: these labels sit on the
/// most-looked-at screen in the app and must follow the language toggle.
///
/// [live] defaults to the Carte's own [pathSubjects]: a subject goes live in
/// one place, once its curriculum is imported, and the Village lights its
/// building up and the Carte offers its pill together. All six are live
/// since CCQ's curriculum landed (backend ADR 0025); the coming-soon state
/// stays for whatever comes next.
List<VillageBuilding> villageBuildings(
  Strings s, {
  Iterable<String> live = pathSubjects,
}) => [
  VillageBuilding(
    label: s.subjectMath,
    asset: 'asset-bldg-math.webp',
    subject: 'MATH',
    live: live.contains('MATH'),
    left: 0.17,
    top: 0.40,
  ),
  VillageBuilding(
    label: s.subjectFrancais,
    asset: 'asset-bldg-francais.webp',
    subject: 'FR',
    live: live.contains('FR'),
    left: 0.50,
    top: 0.22,
  ),
  VillageBuilding(
    label: s.subjectUniversSocial,
    asset: 'asset-bldg-univers-social.webp',
    subject: 'SOC',
    live: live.contains('SOC'),
    left: 0.83,
    top: 0.32,
  ),
  VillageBuilding(
    label: s.subjectAnglais,
    asset: 'asset-bldg-anglais.webp',
    subject: 'EN',
    live: live.contains('EN'),
    left: 0.12,
    top: 0.76,
  ),
  VillageBuilding(
    label: s.subjectScience,
    asset: 'asset-bldg-science.webp',
    subject: 'SCI',
    live: live.contains('SCI'),
    left: 0.84,
    top: 0.82,
  ),
  VillageBuilding(
    label: s.subjectCulture,
    asset: 'asset-bldg-ccq.webp',
    subject: 'CCQ',
    live: live.contains('CCQ'),
    left: 0.37,
    top: 0.72,
    accent: VillageColors.gold,
    small: true,
  ),
];

/// Greyscale for buildings whose subject is not live yet (Rec. 709 luma).
const _greyscale = ColorFilter.matrix([
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0,
]);

/// A building's art, greyed and faded when its subject is not live.
class VillageBuildingArt extends StatelessWidget {
  const VillageBuildingArt({required this.building, this.width, super.key});

  final VillageBuilding building;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final art = Image.asset(
      'assets/images/${building.asset}',
      width: width,
      fit: BoxFit.contain,
    );
    if (building.live) return art;
    return Opacity(
      opacity: 0.6,
      child: ColorFiltered(colorFilter: _greyscale, child: art),
    );
  }
}

/// The small "BIENTÔT" tag a not-yet-live subject wears in place of its bar.
class ComingSoonTag extends StatelessWidget {
  const ComingSoonTag({super.key});

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: p.track,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        context.s.comingSoonShort.toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          color: p.inkMuted,
        ),
      ),
    );
  }
}

/// How much the scene's contents shrink on narrower canvases. The design is
/// drawn for ~1100px; below that, buildings and their pills keep their
/// fractional positions but scale down, so neighbours never collide. Never
/// below 0.62: under that the phone strip takes over (see `VillageScreen`).
double villageSceneScale(double width) => (width / 1100).clamp(0.62, 1.0);

/// The village itself: a sky-and-grass scene with the subject buildings
/// placed on it, the wooden sign, and the mascot greeting.
///
/// Positions are fractional rather than fixed, so the scene reflows with the
/// window instead of clipping — the design states them as percentages and
/// they are kept that way.
class VillageScene extends StatelessWidget {
  const VillageScene({
    required this.buildings,
    required this.signTitle,
    required this.signSubtitle,
    this.greeting,
    this.onTapBuilding,
    this.onTapMascot,
    super.key,
  });

  final List<VillageBuilding> buildings;
  final String signTitle;
  final String signSubtitle;

  /// What the fox says. Null hides the mascot entirely.
  final String? greeting;
  final ValueChanged<VillageBuilding>? onTapBuilding;

  /// The fox was tapped (it sings, ADR 0035). Null: just decoration.
  final VoidCallback? onTapMascot;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: DecoratedBox(
        decoration: BoxDecoration(
          // `linear-gradient(180deg, #CFE8FF, #E4F3FF 38%, #DCEEDD 68%,
          // #CFE6D2)` — sky into grass.
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFCFE8FF),
              Color(0xFFE4F3FF),
              Color(0xFFDCEEDD),
              Color(0xFFCFE6D2),
            ],
            stops: [0, 0.38, 0.68, 1],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
          borderRadius: BorderRadius.circular(24),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            final scale = villageSceneScale(w);
            return Stack(
              children: [
                Positioned(
                  top: 22,
                  left: 26,
                  child: Transform.scale(
                    scale: scale,
                    alignment: Alignment.topLeft,
                    child: _Sign(title: signTitle, subtitle: signSubtitle),
                  ),
                ),
                if (greeting != null)
                  Positioned(
                    left: w * 0.46,
                    top: h * 0.56,
                    width: w * 0.42 / scale,
                    child: Transform.scale(
                      scale: scale,
                      alignment: Alignment.topLeft,
                      child: _MascotGreeting(
                        text: greeting!,
                        onTapMascot: onTapMascot,
                      ),
                    ),
                  ),
                for (final b in buildings)
                  Positioned(
                    left: w * b.left,
                    top: h * b.top,
                    child: FractionalTranslation(
                      // `transform: translate(-50%, -50%)`.
                      translation: Offset(-0.5, -0.5),
                      child: Transform.scale(
                        scale: scale,
                        child: _Building(
                          building: b,
                          // A subject that isn't live yet has nothing to
                          // open, so it takes no tap at all.
                          onTap: onTapBuilding == null || !b.live
                              ? null
                              : () => onTapBuilding!(b),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Sign extends StatelessWidget {
  const _Sign({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    return Transform.rotate(
      angle: -0.035, // `rotate(-2deg)`
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 9),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFC9904F), Color(0xFFA66B33)],
          ),
          border: Border.all(color: Color(0xFF8B5A2B), width: 3),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(color: p.shadow, blurRadius: 40, offset: Offset(0, 16)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontFamily: VillageType.display,
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: Colors.white,
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: 1),
              child: Text(
                subtitle,
                style: TextStyle(fontSize: 10.5, color: Color(0xFFF3E3CF)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A building, which lifts slightly under the pointer.
///
/// `translateY(-3px)` on hover and `scale(.98)` while pressed, both from the
/// design's own rules. Skipped entirely when animations are reduced — the
/// lift is decoration, and a kid who asked for less motion (or whose OS did)
/// should not get it anyway.
class _Building extends StatefulWidget {
  const _Building({required this.building, this.onTap});

  final VillageBuilding building;
  final VoidCallback? onTap;

  @override
  State<_Building> createState() => _BuildingState();
}

class _BuildingState extends State<_Building> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final building = widget.building;
    final onTap = widget.onTap;
    final still = MediaQuery.disableAnimationsOf(context);

    final lift = still || !_hovered || onTap == null ? 0.0 : -3.0;
    final scale = still || !_pressed ? 1.0 : 0.98;

    final tile = MouseRegion(
      cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: scale,
          duration: still ? Duration.zero : Motion.instant,
          child: AnimatedSlide(
            offset: Offset(0, lift / 100),
            duration: still ? Duration.zero : Motion.quick,
            curve: Motion.enter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                VillageBuildingArt(
                  building: building,
                  width: building.small ? 104 : 136,
                ),
                // `margin-top: -16px` — the pill overlaps the building's
                // base.
                Transform.translate(
                  offset: Offset(0, -16),
                  child: _Pill(building: building),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (building.live) {
      return Semantics(button: true, label: building.label, child: tile);
    }
    final soon = context.s.villageSubjectSoon(building.label);
    return Tooltip(
      message: soon,
      child: Semantics(
        label: soon,
        child: ExcludeSemantics(child: tile),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.building});

  final VillageBuilding building;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(11, 6, 14, 6),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(color: p.shadowSmall, blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            building.label,
            style: TextStyle(
              fontFamily: VillageType.display,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: p.ink,
            ),
          ),
          const SizedBox(width: 8),
          if (!building.live)
            const ComingSoonTag()
          else ...[
            SizedBox(
              width: 56,
              height: 6,
              child: VillageProgressBar(
                value: building.progress ?? 0,
                height: 6,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${((building.progress ?? 0) * 100).round()}/100',
              style: TextStyle(
                fontFamily: VillageType.display,
                fontWeight: FontWeight.w700,
                fontSize: 11,
                color: p.inkMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The fox and its speech bubble, standing in the middle of the village.
class _MascotGreeting extends StatelessWidget {
  const _MascotGreeting({required this.text, this.onTapMascot});

  final String text;
  final VoidCallback? onTapMascot;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: p.shadowSmall,
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Text(
            text,
            style: TextStyle(
              fontFamily: VillageType.display,
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
              color: p.ink,
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(left: 24, top: 4),
          child: TappableMascot(height: 120, onTap: onTapMascot),
        ),
      ],
    );
  }
}

/// The breathing fox, tappable when [onTap] is set: a button for screen
/// readers, a pointer cursor, and the whole fox as the target.
class TappableMascot extends StatelessWidget {
  const TappableMascot({required this.height, this.onTap, super.key});

  final double height;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fox = BreathingMascot(height: height);
    if (onTap == null) return fox;
    return Semantics(
      button: true,
      label: context.s.mascotSingLabel,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: fox,
        ),
      ),
    );
  }
}
