import 'package:design_system/design_system.dart';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';

import '../../core/i18n/strings.dart';
import '../../data/local_db/database.dart';
import 'weekly_league.dart';
import 'weekly_league_card.dart';

/// Which promotion this kid has already seen celebrated, so the
/// celebration shows each one once (app ADR 0117). One `app_state` row per
/// kid: the `week_start` of the last promotion celebrated. Weeks only move
/// forward, so a newer week is a new promotion.
class LeagueCelebrations {
  const LeagueCelebrations(this.db, {required this.kidId});

  final LocalDatabase db;
  final String kidId;

  static const _key = 'league.celebrated';

  /// True, and recorded, the first time [promotion] is asked about.
  Future<bool> claim(LeaguePromotion promotion) async {
    final row =
        await (db.select(db.appStateTable)
              ..where((t) => t.kidId.equals(kidId) & t.key.equals(_key)))
            .getSingleOrNull();
    final last = row?.value;
    // ISO dates compare as strings.
    if (last != null && last.compareTo(promotion.weekStart) >= 0) return false;
    await db
        .into(db.appStateTable)
        .insert(
          AppStateTableCompanion.insert(
            kidId: kidId,
            key: _key,
            value: promotion.weekStart,
            updatedAt: DateTime.now(),
          ),
          mode: InsertMode.insertOrReplace,
        );
    return true;
  }
}

/// The celebration's promotion row: « Tu passes en ligue Or ! » beside the
/// new medal. The medal pops in, or sits still under reduced motion.
class LeaguePromotedRow extends StatelessWidget {
  const LeaguePromotedRow({required this.division, super.key});

  final LeagueDivision division;

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final p = VillagePalette.of(context);
    final still = MediaQuery.disableAnimationsOf(context);
    final text = t.leaguePromoted(divisionName(t, division));
    final medal = LeagueMedal(
      color: medalColor(division, p.gold, p.quebecBlueBright),
      size: 56,
    );
    return Semantics(
      liveRegion: true,
      label: text,
      child: ExcludeSemantics(
        child: Container(
          key: const ValueKey('league-promoted'),
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: Space.sm),
          padding: const EdgeInsets.all(Space.md),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: p.gold, width: 2),
          ),
          child: Row(
            children: [
              if (still)
                medal
              else
                TweenAnimationBuilder<double>(
                  key: const ValueKey('league-promoted-pop'),
                  tween: Tween(begin: 0.4, end: 1),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.elasticOut,
                  builder: (_, scale, child) =>
                      Transform.scale(scale: scale, child: child),
                  child: medal,
                ),
              const SizedBox(width: Space.md),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontFamily: VillageType.display,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: p.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
