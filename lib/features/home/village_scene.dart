import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// One subject's building in the village.
class VillageBuilding {
  const VillageBuilding({
    required this.label,
    required this.asset,
    required this.left,
    required this.top,
    this.accent = VillageColors.quebecBlueBright,
    this.small = false,
    this.progress,
  });

  final String label;
  final String asset;

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
        left: left,
        top: top,
        accent: accent,
        small: small,
        progress: value,
      );
}

/// The six subject buildings, at the exact positions the design places them.
const villageBuildings = <VillageBuilding>[
  VillageBuilding(
    label: 'Mathématiques',
    asset: 'asset-bldg-math.webp',
    left: 0.17,
    top: 0.40,
  ),
  VillageBuilding(
    label: 'Français',
    asset: 'asset-bldg-francais.webp',
    left: 0.50,
    top: 0.22,
  ),
  VillageBuilding(
    label: 'Univers social',
    asset: 'asset-bldg-univers-social.webp',
    left: 0.83,
    top: 0.32,
  ),
  VillageBuilding(
    label: 'Anglais',
    asset: 'asset-bldg-anglais.webp',
    left: 0.12,
    top: 0.76,
  ),
  VillageBuilding(
    label: 'Science et techno.',
    asset: 'asset-bldg-science.webp',
    left: 0.84,
    top: 0.82,
  ),
  VillageBuilding(
    label: 'Culture québécoise',
    asset: 'asset-bldg-ccq.webp',
    left: 0.37,
    top: 0.72,
    accent: VillageColors.gold,
    small: true,
  ),
];

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
    super.key,
  });

  final List<VillageBuilding> buildings;
  final String signTitle;
  final String signSubtitle;

  /// What the fox says. Null hides the mascot entirely.
  final String? greeting;
  final ValueChanged<VillageBuilding>? onTapBuilding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: DecoratedBox(
        decoration: BoxDecoration(
          // `linear-gradient(180deg, #CFE8FF, #E4F3FF 38%, #DCEEDD 68%,
          // #CFE6D2)` — sky into grass.
          gradient: const LinearGradient(
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
            return Stack(
              children: [
                Positioned(
                  top: 22,
                  left: 26,
                  child: _Sign(title: signTitle, subtitle: signSubtitle),
                ),
                if (greeting != null)
                  Positioned(
                    left: w * 0.46,
                    top: h * 0.56,
                    width: w * 0.42,
                    child: _MascotGreeting(text: greeting!),
                  ),
                for (final b in buildings)
                  Positioned(
                    left: w * b.left,
                    top: h * b.top,
                    child: FractionalTranslation(
                      // `transform: translate(-50%, -50%)`.
                      translation: const Offset(-0.5, -0.5),
                      child: _Building(
                        building: b,
                        onTap: onTapBuilding == null
                            ? null
                            : () => onTapBuilding!(b),
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
    return Transform.rotate(
      angle: -0.035, // `rotate(-2deg)`
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFC9904F), Color(0xFFA66B33)],
          ),
          border: Border.all(color: const Color(0xFF8B5A2B), width: 3),
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(
              color: VillageColors.shadow,
              blurRadius: 40,
              offset: Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontFamily: VillageType.display,
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: Colors.white,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: Color(0xFFF3E3CF),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Building extends StatelessWidget {
  const _Building({required this.building, this.onTap});

  final VillageBuilding building;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/${building.asset}',
            width: building.small ? 104 : 136,
            fit: BoxFit.contain,
          ),
          // `margin-top: -16px` — the pill overlaps the building's base.
          Transform.translate(
            offset: const Offset(0, -16),
            child: _Pill(building: building),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.building});

  final VillageBuilding building;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 6, 14, 6),
      decoration: BoxDecoration(
        color: VillageColors.surface,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: VillageColors.shadowSmall,
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            building.label,
            style: const TextStyle(
              fontFamily: VillageType.display,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: VillageColors.ink,
            ),
          ),
          const SizedBox(width: 8),
          ...[
            SizedBox(
              width: 56,
              height: 6,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: building.progress ?? 0,
                  backgroundColor: VillageColors.track,
                  valueColor: AlwaysStoppedAnimation(building.accent),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${((building.progress ?? 0) * 100).round()}/100',
              style: const TextStyle(
                fontFamily: VillageType.display,
                fontWeight: FontWeight.w700,
                fontSize: 11,
                color: VillageColors.inkMuted,
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
  const _MascotGreeting({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: VillageColors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: VillageColors.shadowSmall,
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: VillageType.display,
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
              color: VillageColors.ink,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 24, top: 4),
          child: Image.asset(
            'assets/images/asset-mascot-welcome.webp',
            height: 120,
            fit: BoxFit.contain,
          ),
        ),
      ],
    );
  }
}
