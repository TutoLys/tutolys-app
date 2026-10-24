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
/// ADR 0004's dark A7.2 layer. Pale blue sky, white cards, gold CTAs.
///
/// It also reverses a documented decision. ADR 0004 chose a **dark** learner
/// register on the reasoning that "gold reads as reward against a deep blue
/// rather than as a warning against white". The design says light, so light
/// it is — but the old argument was a real one, and gold-on-white is worth
/// watching as the pages land.
///
/// **Every value here is copied from the design's own `:root` block**
/// (`docs/design/01-design-system-gallery.html`), which its README names as
/// the source of truth. Do not re-derive these by eye — an earlier pass did
/// exactly that and got the sky, the text colour and the shadow all wrong.
abstract final class VillageColors {
  /// The sky behind everything, top to bottom. `--sky-top` / `--sky-bottom`.
  static const Color skyTop = Color(0xFFBFE3FF);
  static const Color skyBottom = Color(0xFFEAF6FF);

  /// `--surface`. Cards, sidebar, panels.
  static const Color surface = Color(0xFFFFFFFF);

  /// `--quebec-blue` / `--quebec-blue-bright`. The brand, and the brighter
  /// tone used for active navigation and links.
  static const Color quebecBlue = Color(0xFF1F3C88);
  static const Color quebecBlueBright = Color(0xFF2F6FED);

  /// `--gold` family. Achievement and the primary CTA.
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldLight = Color(0xFFFBBF24);
  static const Color goldPale = Color(0xFFFDE68A);

  /// `--ink` / `--ink-muted`. Text. Both are blue-tinted, not neutral grey.
  static const Color ink = Color(0xFF223047);
  static const Color inkMuted = Color(0xFF7C8AA3);

  /// `--line` (borders) and `--track` (progress-bar channels).
  static const Color line = Color(0xFFE4ECF7);
  static const Color track = Color(0xFFE1E9F7);

  static const Color success = Color(0xFF2FB170);
  static const Color successPale = Color(0xFFDFF5E8);

  /// `--retry` / `--retry-pale`. The "almost!" state.
  ///
  /// Amber, never red, and paired with a target icon rather than an X —
  /// because every engine retries until correct and never ends a lesson
  /// early, so red-and-an-X would contradict the actual mechanic. The
  /// design's Decision Log makes this an explicit, repeated ruling, and it
  /// is the same reasoning `EngineFeedback.incorrect` already documents
  /// ("deliberately gentle — a harsh buzzer teaches avoidance").
  static const Color retry = Color(0xFFF2994A);
  static const Color retryPale = Color(0xFFFFF1E0);

  /// `--shadow` / `--shadow-sm`, both navy-tinted rather than neutral grey:
  /// `0 16px 40px rgba(31,60,136,.12)` and `0 6px 16px rgba(31,60,136,.08)`.
  /// Flutter takes the colour here; elevation approximates the blur.
  static const Color shadow = Color(0x1F1F3C88);
  static const Color shadowSmall = Color(0x141F3C88);
  static const double elevation = 10;
  static const double elevationSmall = 4;
}

/// Metrics the design states outright, rather than ones inferred from a
/// screenshot. Same source as [VillageColors].
abstract final class VillageMetrics {
  /// `--radius-shell` — the outer frame and large panels.
  static const Radius shell = Radius.circular(28);

  /// `--radius-md` — cards, rows, pills' containers.
  static const Radius md = Radius.circular(16);

  static const BorderRadius shellAll = BorderRadius.all(shell);
  static const BorderRadius mdAll = BorderRadius.all(md);

  /// `--sidebar-w`. The expanded sidebar at >= 1024px.
  static const double sidebarWidth = 224;

  /// The compact icon rail at 768-1023px. Stated in the design's nav frame
  /// rather than as a custom property.
  static const double railWidth = 84;

  /// `--header-h`.
  static const double headerHeight = 92;
}

/// The display typeface the design specifies: **Baloo 2**, weights 600-800,
/// with the system stack for body text.
///
/// Not yet bundled. It has to ship as a real font asset rather than a Google
/// Fonts CDN call — this app is offline-first, and a runtime network
/// dependency for type would mean a kid on a plane gets fallback glyphs.
/// That tradeoff is ADR 0004's own open question, and the design answers the
/// *which font* half of it without answering the *how delivered* half.
abstract final class VillageType {
  static const String display = 'Baloo2';
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

/// The design's **dark** counterpart, added to
/// `01-design-system-gallery.html` after the light work landed
/// (`[data-theme="dark"]`). Copied, not derived.
///
/// Two of these invert rather than darken, which a mechanical light-to-dark
/// mapping would have got backwards: `goldPale` and `retryPale` are
/// *backgrounds* behind gold and amber text, so in dark they become deep
/// browns rather than pale tints.
abstract final class VillageDarkColors {
  static const Color skyTop = Color(0xFF0B1222);
  static const Color skyBottom = Color(0xFF101B33);
  static const Color pageBackground = Color(0xFF0D1526);

  static const Color surface = Color(0xFF182036);

  static const Color quebecBlue = Color(0xFF2A4A9E);
  static const Color quebecBlueBright = Color(0xFF5B8FFF);

  static const Color gold = Color(0xFFE8C14F);
  static const Color goldLight = Color(0xFFFFC94D);
  static const Color goldPale = Color(0xFF3D3115);

  static const Color ink = Color(0xFFE8EDF8);
  static const Color inkMuted = Color(0xFF96A5CB);

  static const Color line = Color(0xFF2A3655);
  static const Color track = Color(0xFF243150);

  static const Color success = Color(0xFF3FCB83);
  static const Color successPale = Color(0xFF163828);
  static const Color retry = Color(0xFFFFA75C);
  static const Color retryPale = Color(0xFF3D2912);

  static const Color bluePale = Color(0xFF1C2C52);

  /// `0 16px 40px rgba(0,0,0,.45)` / `0 6px 16px rgba(0,0,0,.35)` — black,
  /// not navy: on a dark ground a tinted shadow reads as a halo.
  static const Color shadow = Color(0x73000000);
  static const Color shadowSmall = Color(0x59000000);
}
