import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local_db/local_inbox.dart';
import '../pairing/pairing_controller.dart';
import 'local_facts.dart';

/// The playing kid's own inbox on this device (ADR 0097).
final localInboxProvider = Provider<LocalInbox>(
  (ref) => LocalInbox(
    ref.watch(localDatabaseProvider),
    kidId: ref.watch(activeKidIdProvider) ?? unpairedKidId,
  ),
);

/// Writes what the quest board just learned, and returns how many facts
/// were new. A level is announced only
/// when it rises past the last one announced at this grade; the first look
/// only remembers it.
Future<int> writeLocalNotifications(
  LocalInbox inbox, {
  required String day,
  required Set<String> newQuests,
  required Set<String> newUnlocks,
  Map<String, int> questTargets = const {},
  int? level,
  int? grade,
}) async {
  int? levelReached;
  if (level != null && grade != null) {
    final seen = await inbox.levelSeen(grade);
    if (seen == null || level > seen) await inbox.setLevelSeen(grade, level);
    if (seen != null && level > seen) levelReached = level;
  }
  var added = 0;
  for (final fact in notificationFacts(
    day: day,
    newQuests: newQuests,
    newUnlocks: newUnlocks,
    questTargets: questTargets,
    levelReached: levelReached,
    grade: grade,
  )) {
    if (await inbox.add(fact.factKey, fact.type, params: fact.params)) {
      added++;
    }
  }
  return added;
}
