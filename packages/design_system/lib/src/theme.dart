import 'package:flutter/material.dart';

import 'tokens.dart';

/// The two visual registers.
///
/// The design system calls them "learner playful" and "adult calm". They share
/// the brand and the token scale, and differ in roundness, weight and density —
/// one codebase, two shells (plan §6.3, spec decision D4).
enum TutolysRegister { learner, adult }

/// Extra theme values Material does not model.
@immutable
class TutolysThemeExtras extends ThemeExtension<TutolysThemeExtras> {
  const TutolysThemeExtras({
    required this.register,
    required this.gold,
    required this.success,
    required this.danger,
    required this.cardRadius,
    required this.mutedText,
    required this.progressTrack,
  });

  final TutolysRegister register;
  final Color gold;
  final Color success;
  final Color danger;
  final BorderRadius cardRadius;
  final Color mutedText;
  final Color progressTrack;

  @override
  TutolysThemeExtras copyWith({
    TutolysRegister? register,
    Color? gold,
    Color? success,
    Color? danger,
    BorderRadius? cardRadius,
    Color? mutedText,
    Color? progressTrack,
  }) {
    return TutolysThemeExtras(
      register: register ?? this.register,
      gold: gold ?? this.gold,
      success: success ?? this.success,
      danger: danger ?? this.danger,
      cardRadius: cardRadius ?? this.cardRadius,
      mutedText: mutedText ?? this.mutedText,
      progressTrack: progressTrack ?? this.progressTrack,
    );
  }

  @override
  TutolysThemeExtras lerp(TutolysThemeExtras? other, double t) {
    if (other == null) return this;
    return TutolysThemeExtras(
      register: t < 0.5 ? register : other.register,
      gold: Color.lerp(gold, other.gold, t)!,
      success: Color.lerp(success, other.success, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      cardRadius: BorderRadius.lerp(cardRadius, other.cardRadius, t)!,
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
      progressTrack: Color.lerp(progressTrack, other.progressTrack, t)!,
    );
  }
}

abstract final class TutolysTheme {
  /// The learner's theme: dark, high contrast, generous radii.
  ///
  /// Dark by default because the kid app is played in the evening as often as
  /// not, and because gold reads as reward against a deep blue rather than as
  /// a warning against white.
  static ThemeData learner() {
    const scheme = ColorScheme.dark(
      primary: TutolysColors.blueLight,
      onPrimary: Colors.white,
      primaryContainer: TutolysColors.blue,
      onPrimaryContainer: TutolysColors.blueOnSurface,
      secondary: TutolysColors.gold,
      onSecondary: Color(0xFF2A2000),
      surface: TutolysColors.darkSurface,
      onSurface: TutolysColors.textOnDark,
      surfaceContainerHighest: TutolysColors.darkCard,
      error: TutolysColors.danger,
      onError: Colors.white,
    );

    return _base(scheme, TutolysRegister.learner).copyWith(
      scaffoldBackgroundColor: TutolysColors.darkBackground,
      extensions: const [
        TutolysThemeExtras(
          register: TutolysRegister.learner,
          gold: TutolysColors.gold,
          success: TutolysColors.success,
          danger: TutolysColors.danger,
          cardRadius: Radii.cardLg,
          mutedText: TutolysColors.textOnDarkMuted,
          progressTrack: TutolysColors.darkTrack,
        ),
      ],
    );
  }

  /// The learner's theme as the 2026-10-24 design draws it: light, pale-blue
  /// ground, white cards, gold pill CTAs.
  ///
  /// Added alongside [learner] rather than replacing it, so the seven pages
  /// can move across one at a time instead of every screen changing register
  /// in a single commit. [learner] goes when the last page has moved.
  ///
  /// Note this reverses ADR 0004's explicit reasoning for a dark learner
  /// register — see [VillageColors].
  static ThemeData village() {
    const scheme = ColorScheme.light(
      primary: VillageColors.quebecBlue,
      onPrimary: Colors.white,
      primaryContainer: VillageColors.surface,
      onPrimaryContainer: VillageColors.quebecBlue,
      secondary: VillageColors.gold,
      onSecondary: Color(0xFF3A2A00),
      surface: VillageColors.surface,
      onSurface: VillageColors.ink,
      surfaceContainerHighest: VillageColors.surface,
      error: TutolysColors.danger,
      onError: Colors.white,
    );

    return _base(scheme, TutolysRegister.learner).copyWith(
      // Flat, and the *bottom* of the sky gradient: `--sky-top` to
      // `--sky-bottom` is painted by the shell widget, not the scaffold, so
      // the two never both try to own the background. Anything the shell
      // does not cover meets the gradient at its lighter end.
      scaffoldBackgroundColor: VillageColors.skyBottom,
      extensions: const [
        TutolysThemeExtras(
          register: TutolysRegister.learner,
          gold: VillageColors.gold,
          success: TutolysColors.success,
          danger: TutolysColors.danger,
          cardRadius: VillageMetrics.mdAll,
          mutedText: VillageColors.inkMuted,
          progressTrack: VillageColors.track,
        ),
      ],
    );
  }

  /// The adult's theme: light, denser, squarer. Calm, not playful.
  static ThemeData adult() {
    const scheme = ColorScheme.light(
      primary: TutolysColors.blue,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFDCE4F7),
      onPrimaryContainer: TutolysColors.blue,
      secondary: TutolysColors.gold,
      onSecondary: Color(0xFF2A2000),
      surface: TutolysColors.lightCard,
      onSurface: TutolysColors.textOnLight,
      surfaceContainerHighest: TutolysColors.lightSurface,
      error: TutolysColors.danger,
      onError: Colors.white,
    );

    return _base(scheme, TutolysRegister.adult).copyWith(
      scaffoldBackgroundColor: TutolysColors.lightBackground,
      extensions: const [
        TutolysThemeExtras(
          register: TutolysRegister.adult,
          gold: TutolysColors.gold,
          success: TutolysColors.success,
          danger: TutolysColors.danger,
          cardRadius: Radii.cardSm,
          mutedText: TutolysColors.textOnLightMuted,
          progressTrack: Color(0xFFE2E8F0),
        ),
      ],
    );
  }

  static ThemeData _base(ColorScheme scheme, TutolysRegister register) {
    final isLearner = register == TutolysRegister.learner;
    final radius = isLearner ? Radii.cardLg : Radii.cardSm;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: _textTheme(scheme, isLearner),
      // A kid taps with a whole finger and sometimes the side of a hand.
      // 56 is comfortably above the 48 minimum; adults get the standard.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: Size(0, isLearner ? 56 : 44),
          padding: EdgeInsets.symmetric(
            horizontal: isLearner ? Space.lg : Space.md,
            vertical: isLearner ? Space.md : Space.sm,
          ),
          // Pill, not the card radius — the brand spec's own button rule
          // (`border-radius: 9999px`) is unconditional, unlike cards/inputs
          // which deliberately differ between the two registers.
          shape: const RoundedRectangleBorder(borderRadius: Radii.pillAll),
          textStyle: TextStyle(
            fontSize: isLearner ? 18 : 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: Size(0, isLearner ? 56 : 44),
          shape: const RoundedRectangleBorder(borderRadius: Radii.pillAll),
          side: BorderSide(color: scheme.primary.withValues(alpha: 0.5), width: 1.5),
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerHighest,
        elevation: Shadows.cloudElevation,
        shadowColor: Shadows.cloud,
        shape: RoundedRectangleBorder(borderRadius: radius),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: TutolysColors.danger, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Space.md,
          vertical: Space.md,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearMinHeight: isLearner ? 12 : 6,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      visualDensity: isLearner ? VisualDensity.comfortable : VisualDensity.standard,
    );
  }

  static TextTheme _textTheme(ColorScheme scheme, bool isLearner) {
    // Scale up for the learner: a grade-1 reader needs larger type, and
    // tighter tracking on headlines keeps them from looking washed out.
    final scale = isLearner ? 1.12 : 1.0;
    TextStyle style(double size, FontWeight weight, {double tracking = 0}) {
      return TextStyle(
        fontSize: size * scale,
        fontWeight: weight,
        letterSpacing: tracking,
        color: scheme.onSurface,
        height: 1.25,
      );
    }

    return TextTheme(
      displaySmall: style(36, FontWeight.w800, tracking: -0.5),
      headlineMedium: style(28, FontWeight.w800, tracking: -0.3),
      headlineSmall: style(22, FontWeight.w700),
      titleLarge: style(19, FontWeight.w700),
      titleMedium: style(16, FontWeight.w600),
      bodyLarge: style(16, FontWeight.w400).copyWith(height: 1.45),
      bodyMedium: style(14, FontWeight.w400).copyWith(height: 1.45),
      labelLarge: style(14, FontWeight.w700, tracking: 0.3),
      labelSmall: style(12, FontWeight.w600, tracking: 0.4),
    );
  }
}

/// Convenience accessor so widgets read `context.extras.gold` rather than
/// reaching into `Theme.of(context).extension<...>()!` every time.
extension TutolysThemeContext on BuildContext {
  TutolysThemeExtras get extras => Theme.of(this).extension<TutolysThemeExtras>()!;
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;

  /// True on phones and narrow windows.
  bool get isCompact => MediaQuery.sizeOf(this).width < Breakpoints.compact;
}
