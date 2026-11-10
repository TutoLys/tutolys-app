import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../../core/i18n/strings.dart';
import 'village_bridge.dart';

/// « Contrôles du ciel » (ADR 0126): the 3D village's hour, season and
/// weather, picked by hand, plus « En direct » to give all three back to
/// Québec's real clock, date and weather.
///
/// A bar under the scene, not a panel over it: on web the scene's iframe
/// takes every tap inside its box, and on Linux its native view draws above
/// Flutter, so nothing drawn over the scene could be tapped. Pure
/// presentation: [VillageSceneHost] owns the picks and sends the messages.
class VillageSkyBar extends StatelessWidget {
  const VillageSkyBar({
    required this.hour,
    required this.liveHour,
    required this.season,
    required this.sky,
    required this.onHour,
    required this.onSeason,
    required this.onSky,
    required this.onLive,
    super.key,
  });

  /// The picked hour, or null while the clock is live.
  final double? hour;

  /// Where the slider rests while the clock is live.
  final double liveHour;
  final VillageSeason? season;
  final VillageSky? sky;
  final ValueChanged<double> onHour;
  final ValueChanged<VillageSeason> onSeason;
  final ValueChanged<VillageSky> onSky;
  final VoidCallback onLive;

  bool get _live => hour == null && season == null && sky == null;

  static IconData seasonIcon(VillageSeason s) => switch (s) {
    VillageSeason.spring => Icons.local_florist_rounded,
    VillageSeason.summer => Icons.wb_sunny_rounded,
    VillageSeason.autumn => Icons.eco_rounded,
    VillageSeason.winter => Icons.ac_unit_rounded,
  };

  static IconData skyIcon(VillageSky s) => switch (s) {
    VillageSky.clear => Icons.light_mode_rounded,
    VillageSky.clouds => Icons.cloud_rounded,
    VillageSky.rain => Icons.water_drop_rounded,
    VillageSky.snow => Icons.cloudy_snowing,
    VillageSky.storm => Icons.thunderstorm_rounded,
    VillageSky.fog => Icons.foggy,
  };

  static String seasonLabel(Strings t, VillageSeason s) => switch (s) {
    VillageSeason.spring => t.skySpring,
    VillageSeason.summer => t.skySummer,
    VillageSeason.autumn => t.skyAutumn,
    VillageSeason.winter => t.skyWinter,
  };

  static String skyLabel(Strings t, VillageSky s) => switch (s) {
    VillageSky.clear => t.skyClear,
    VillageSky.clouds => t.skyClouds,
    VillageSky.rain => t.skyRain,
    VillageSky.snow => t.skySnow,
    VillageSky.storm => t.skyStorm,
    VillageSky.fog => t.skyFog,
  };

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final p = VillagePalette.of(context);
    final shown = hour ?? liveHour;
    return Semantics(
      container: true,
      label: t.skyPanelLabel,
      // Its own Material: the slider and the ink need one, and the scene
      // box above it is not one.
      child: Material(
        key: const ValueKey('village-sky-bar'),
        color: p.surface,
        shape: Border(top: BorderSide(color: p.line)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          child: SizedBox(
            width: double.infinity,
            child: Wrap(
              spacing: 18,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schedule_rounded, size: 20, color: p.inkMuted),
                    SizedBox(
                      width: 170,
                      child: Slider(
                        key: const ValueKey('sky-hour'),
                        value: shown.clamp(0, 24),
                        max: 24,
                        divisions: 48,
                        label: t.skyHour(shown),
                        semanticFormatterCallback: t.skyHour,
                        activeColor: hour == null
                            ? p.inkMuted
                            : p.quebecBlueBright,
                        inactiveColor: p.line,
                        onChanged: onHour,
                      ),
                    ),
                    SizedBox(
                      width: 52,
                      child: Text(
                        t.skyHour(shown),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: hour == null ? p.inkMuted : p.ink,
                        ),
                      ),
                    ),
                  ],
                ),
                _ChipGroup(
                  label: t.skySeason,
                  children: [
                    for (final s in VillageSeason.values)
                      _SkyChip(
                        key: ValueKey('sky-season-${s.name}'),
                        icon: seasonIcon(s),
                        label: seasonLabel(t, s),
                        selected: season == s,
                        onTap: () => onSeason(s),
                      ),
                  ],
                ),
                _ChipGroup(
                  label: t.skyWeather,
                  children: [
                    for (final s in VillageSky.values)
                      _SkyChip(
                        key: ValueKey('sky-weather-${s.name}'),
                        icon: skyIcon(s),
                        label: skyLabel(t, s),
                        selected: sky == s,
                        onTap: () => onSky(s),
                      ),
                  ],
                ),
                Tooltip(
                  message: t.skyLiveHint,
                  child: Semantics(
                    selected: _live,
                    button: true,
                    child: Material(
                      color: _live ? p.goldPale : p.track,
                      borderRadius: BorderRadius.circular(999),
                      child: InkWell(
                        key: const ValueKey('sky-live'),
                        borderRadius: BorderRadius.circular(999),
                        onTap: onLive,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.sensors_rounded,
                                size: 18,
                                color: _live ? p.ink : p.inkMuted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                t.skyLive,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: _live ? p.ink : p.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
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

class _ChipGroup extends StatelessWidget {
  const _ChipGroup({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: label,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final c in children)
          Padding(padding: const EdgeInsets.only(right: 4), child: c),
      ],
    ),
  );
}

/// One pick: a round icon, named by its tooltip and for screen readers.
class _SkyChip extends StatelessWidget {
  const _SkyChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        selected: selected,
        button: true,
        excludeSemantics: true,
        child: Material(
          color: selected ? p.quebecBlueBright : p.track,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox.square(
              dimension: 36,
              child: Icon(
                icon,
                size: 19,
                color: selected ? p.surface : p.inkMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
