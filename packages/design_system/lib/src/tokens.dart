import 'package:flutter/widgets.dart';

/// Brand tokens.
///
/// Values recovered from the old desktop client's `main.css` during the Phase 0
/// audit, which the design system itself named as authoritative. Quebec blue
/// and gold are LOCKED in the handoff plan; these are the exact hexes that were
/// already shipping, so the rebuild does not drift from the existing brand.
///
/// Everything visual references this file. The old project kept tokens in three
/// hand-synced places and they disagreed — one source is the whole point.
abstract final class TutolysColors {
  /// Quebec blue. The primary brand colour.
  static const Color blue = Color(0xFF1F3C88);
  static const Color blueLight = Color(0xFF3F5FBF);
  static const Color blueOnSurface = Color(0xFFA8C4FF);

  /// Gold. Used for reward, progress and emphasis — never for large areas.
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldLight = Color(0xFFFBBF24);
  static const Color goldPale = Color(0xFFFDE68A);

  static const Color success = Color(0xFF52C97E);
  static const Color successDeep = Color(0xFF34D399);
  static const Color warning = Color(0xFFE8B84A);
  static const Color danger = Color(0xFFE85D5D);

  // Dark surfaces, deepest first.
  static const Color darkBackground = Color(0xFF0F1524);
  static const Color darkSurface = Color(0xFF161F33);
  static const Color darkCard = Color(0xFF1E2A45);
  static const Color darkTrack = Color(0xFF2A3858);

  // Light surfaces.
  static const Color lightBackground = Color(0xFFF8F9FA);
  static const Color lightSurface = Color(0xFFF1F4F8);
  static const Color lightCard = Color(0xFFFFFFFF);

  static const Color textOnDark = Color(0xFFF1F4F8);
  static const Color textOnDarkMuted = Color(0xFF9AA8C4);
  static const Color textOnLight = Color(0xFF1A1C1E);
  static const Color textOnLightMuted = Color(0xFF5A6478);
}

/// The 2026-10-24 design's learner palette — "the village".
///
/// A third direction, superseding both of its predecessors: not the
/// ink-outline sticker style of `Platforms/3-student-village.html`, and not
/// ADR 0004's dark A7.2 layer. Pale blue grounds, white cards with a soft
/// shadow, illustrated buildings per subject, gold pill CTAs, navy accents.
///
/// It also reverses a documented decision. ADR 0004 chose a **dark** learner
/// register on the reasoning that "gold reads as reward against a deep blue
/// rather than as a warning against white". The design says light, so light
/// it is — but the old argument was a real one, and gold-on-white needs
/// watching as the pages land.
///
/// Brand hues come from `Platforms/shared.css`, which `TutolysColors` above
/// already treats as authoritative. The ground and card values are read from
/// the design rather than from a stylesheet, so they are **approximate until
/// confirmed against the artifact's own CSS** — flagged rather than passed
/// off as exact.
abstract final class VillageColors {
  /// Page ground. A pale blue wash, lighter toward the bottom.
  static const Color groundTop = Color(0xFFE3EFFB);
  static const Color groundBottom = Color(0xFFF5FAFF);

  /// Cards and panels sit on the ground in plain white.
  static const Color card = Color(0xFFFFFFFF);

  /// Rails, sidebars and inset wells.
  static const Color surface = Color(0xFFF1F6FD);

  /// Navy, for headings and the "activité recommandée" band.
  static const Color navy = TutolysColors.blue;
  static const Color navyLight = TutolysColors.blueLight;

  /// The primary call to action is gold, always a pill.
  static const Color cta = Color(0xFFF2B13B);
  static const Color ctaDeep = Color(0xFFD99A22);

  static const Color textPrimary = TutolysColors.textOnLight;
  static const Color textMuted = Color(0xFF5B6475);

  /// Per-subject accents, from `shared.css`'s own `--math`/`--fr`/… set.
  /// Used on progress bars, pills and building labels.
  static const Color math = Color(0xFFF2A93B);
  static const Color francais = Color(0xFFE8667A);
  static const Color anglais = Color(0xFF3BB3C3);
  static const Color science = Color(0xFF52C97E);
  static const Color universSocial = Color(0xFF9B7AE0);

  /// Progress tracks, under every one of those accents.
  static const Color track = Color(0xFFE2E8F2);

  /// The card shadow. Softer and cooler than the learner-dark register's
  /// navy "cloud" — on a pale ground a heavy shadow reads as grime.
  static const Color shadow = Color(0x14334155);
  static const double shadowElevation = 3;
}

/// Spacing scale. A 4pt base, so every gap is a multiple and layouts line up
/// without eyeballed numbers.
abstract final class Space {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double huge = 64;
}

/// Corner radii. Learner surfaces are rounder than adult ones — a deliberate
/// part of the "playful vs calm" split the two shells use. `lg` matches the
/// real desktop app's own `--radius-lg: 2rem` exactly (confirmed from its
/// shipped `main.css`, not just the mined spec) — the learner register is
/// where that app's actual rounding should read as familiar.
abstract final class Radii {
  static const Radius sm = Radius.circular(8);
  static const Radius md = Radius.circular(14);
  static const Radius lg = Radius.circular(32);
  static const Radius pill = Radius.circular(999);

  static const BorderRadius cardSm = BorderRadius.all(sm);
  static const BorderRadius cardMd = BorderRadius.all(md);
  static const BorderRadius cardLg = BorderRadius.all(lg);
  static const BorderRadius pillAll = BorderRadius.all(pill);
}

/// Ambient shadow. The real desktop app's signature "cloud shadow" is a
/// navy-tinted, soft ambient shadow (`0 20px 40px rgba(31, 60, 136, 0.08)`
/// in its `main.css`) — not a neutral grey drop shadow. `Card`'s
/// `shadowColor` + a non-zero `elevation` renders the same effect natively.
abstract final class Shadows {
  static const Color cloud = Color(0x141F3C88); // #1F3C88 at 8% alpha
  static const double cloudElevation = 6;
}

/// Motion. Durations are short enough to feel responsive and long enough for a
/// six-year-old to follow what moved.
abstract final class Motion {
  static const Duration instant = Duration(milliseconds: 120);
  static const Duration quick = Duration(milliseconds: 220);
  static const Duration normal = Duration(milliseconds: 340);
  static const Duration slow = Duration(milliseconds: 560);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve bounce = Curves.elasticOut;
}

/// Breakpoints.
///
/// One widget tree per screen; only presentation adapts (plan §6.3). Logic is
/// never forked per platform.
abstract final class Breakpoints {
  /// Phones and narrow windows.
  static const double compact = 600;

  /// Tablets.
  static const double medium = 1024;

  /// Desktop and web are ~95% identical above this.
  static const double expanded = 1440;
}
