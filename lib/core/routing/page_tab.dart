import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local_db/database.dart';
import '../../features/pairing/pairing_controller.dart';

/// The pages that switch categories with [PillTabs], by the name their
/// remembered tab is stored under.
abstract final class TabbedPage {
  static const settings = 'settings';
  static const profile = 'profile';
}

/// Which pill tab a page shows, remembered per kid (app ADR 0051).
///
/// Stored in `app_state` under the kid's own owner (ADR 0014), key
/// `ui.<page>.tab`, so switching kid restores that kid's tab. Null means
/// "the page's first tab": a page validates the value against its own
/// tabs, so a renamed tab falls back rather than showing nothing.
///
/// A deep link is just [PageTabController.select] before opening the page:
/// it wins over what was remembered because it *becomes* what's remembered.
class PageTabController extends Notifier<String?> {
  PageTabController(this.page);

  final String page;

  String get _key => 'ui.$page.tab';

  @override
  String? build() {
    final kid = ref.watch(activeKidIdProvider) ?? unpairedKidId;
    _selected = false;
    Future.microtask(() => _load(kid));
    return null;
  }

  /// Set once a tab is chosen, so a slow read can't undo the choice.
  bool _selected = false;

  Future<void> _load(String kid) async {
    final db = ref.read(localDatabaseProvider);
    final row =
        await (db.select(db.appStateTable)
              ..where((t) => t.kidId.equals(kid))
              ..where((t) => t.key.equals(_key)))
            .getSingleOrNull();
    if (!ref.mounted || _selected) return;
    state = row?.value;
  }

  Future<void> select(String tab) async {
    _selected = true;
    state = tab;
    final db = ref.read(localDatabaseProvider);
    await db
        .into(db.appStateTable)
        .insert(
          AppStateTableCompanion.insert(
            kidId: ref.read(activeKidIdProvider) ?? unpairedKidId,
            key: _key,
            value: tab,
            updatedAt: DateTime.now(),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }
}

final pageTabProvider =
    NotifierProvider.family<PageTabController, String?, String>(
      PageTabController.new,
    );
