import 'dart:convert';

import 'package:drift/drift.dart';

import '../../data/local_db/database.dart';

/// The XP a finished série earned, shown in the header at once (N7,
/// ADR 0112). The backend's ledger pays it only after telemetry uploads
/// and `award_xp` runs, which took minutes on the review's run: the
/// celebration said +8 and the header stayed at 0.
///
/// Kept as a floor per kid in `app_state`: the header shows the larger of
/// the server's total and the floor. The floor goes once the server
/// reaches it, once the server lowers its total on purpose (a recompute,
/// backend ADR 0047: the server is the authority), or after a day, so a
/// wrong estimate can't stick.
class LocalXp {
  LocalXp(this.db, {required this.kidId, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final LocalDatabase db;
  final String kidId;
  final DateTime Function() _clock;

  static const _key = 'xp.local_floor';
  static const maxAge = Duration(days: 1);

  /// Records [earned] on top of [shown], the total on screen now.
  Future<int> credit({required int shown, required int earned}) async {
    final current = await _read();
    final base = current != null && current.floor > shown
        ? current.floor
        : shown;
    final floor = base + earned;
    await _write(floor: floor, server: current?.server ?? shown);
    return floor;
  }

  /// The total to show for a server read of [server]: never below a live
  /// floor. Clears the floor when it no longer applies.
  Future<int> reconcile(int server) async {
    final current = await _read();
    if (current == null) return server;
    final expired = _clock().difference(current.at) > maxAge;
    if (server >= current.floor || server < current.server || expired) {
      await (db.delete(
        db.appStateTable,
      )..where((t) => t.kidId.equals(kidId) & t.key.equals(_key))).go();
      return server;
    }
    return current.floor;
  }

  Future<({int floor, int server, DateTime at})?> _read() async {
    final row =
        await (db.select(db.appStateTable)
              ..where((t) => t.kidId.equals(kidId) & t.key.equals(_key)))
            .getSingleOrNull();
    if (row == null) return null;
    try {
      final j = jsonDecode(row.value) as Map<String, Object?>;
      return (
        floor: j['floor']! as int,
        server: j['server']! as int,
        at: DateTime.parse(j['at']! as String),
      );
    } on Object {
      return null;
    }
  }

  Future<void> _write({required int floor, required int server}) async {
    final now = _clock();
    await db
        .into(db.appStateTable)
        .insert(
          AppStateTableCompanion.insert(
            kidId: kidId,
            key: _key,
            value: jsonEncode({
              'floor': floor,
              'server': server,
              'at': now.toUtc().toIso8601String(),
            }),
            updatedAt: now,
          ),
          mode: InsertMode.insertOrReplace,
        );
  }
}
