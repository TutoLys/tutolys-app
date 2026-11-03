import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local_db/database.dart';
import '../pairing/pairing_controller.dart';
import 'carte_model.dart';

/// Which of the Carte's sections this kid opened or closed themselves
/// (ADR 0124): one `app_state` row, section key to open. A section with no
/// entry follows [isSectionOpen]'s default.
class SectionFoldStore {
  const SectionFoldStore(this.db, {required this.kidId});

  final LocalDatabase db;
  final String kidId;

  static const _key = 'carte.sections';

  Future<Map<String, bool>> read() async {
    final row =
        await (db.select(db.appStateTable)
              ..where((t) => t.kidId.equals(kidId) & t.key.equals(_key)))
            .getSingleOrNull();
    if (row == null) return const {};
    return (jsonDecode(row.value) as Map<String, Object?>).cast<String, bool>();
  }

  Future<void> write(Map<String, bool> folds) => db
      .into(db.appStateTable)
      .insert(
        AppStateTableCompanion.insert(
          kidId: kidId,
          key: _key,
          value: jsonEncode(folds),
          updatedAt: DateTime.now(),
        ),
        mode: InsertMode.insertOrReplace,
      );
}

/// The playing kid's choices.
final sectionFoldsProvider =
    AsyncNotifierProvider<SectionFolds, Map<String, bool>>(SectionFolds.new);

class SectionFolds extends AsyncNotifier<Map<String, bool>> {
  SectionFoldStore? get _store {
    final kidId = ref.read(activeKidIdProvider);
    return kidId == null
        ? null
        : SectionFoldStore(ref.read(localDatabaseProvider), kidId: kidId);
  }

  @override
  Future<Map<String, bool>> build() async {
    ref.watch(activeKidIdProvider);
    return await _store?.read() ?? const {};
  }

  /// The kid opened or closed [key].
  Future<void> set(String key, {required bool open}) =>
      _save({...?state.value, key: open});

  /// Back to the default for [key]: the next lesson moved into it.
  Future<void> forget(String key) async {
    if (state.value?.containsKey(key) != true) return;
    await _save({...state.value!}..remove(key));
  }

  Future<void> _save(Map<String, bool> folds) async {
    state = AsyncData(folds);
    await _store?.write(folds);
  }
}

/// The section holding the kid's next lesson, or the first when nothing is
/// open yet.
String? nextSectionKey(List<PathSection> sections) {
  final focus = focusNodeIdOf(sections);
  for (final section in sections) {
    if (section.nodes.any((n) => n.id == focus)) return section.key;
  }
  return sections.firstOrNull?.key;
}

/// The kid's own choice, or else open only for the next lesson's section,
/// so the Carte opens on what's next.
bool isSectionOpen(
  PathSection section, {
  required Map<String, bool> folds,
  required String? nextKey,
}) => folds[section.key] ?? section.key == nextKey;
