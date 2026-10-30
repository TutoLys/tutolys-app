import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local_db/programme_store.dart';
import '../pairing/pairing_controller.dart';

export '../../data/local_db/programme_store.dart'
    show Programme, frenchProgramme;

/// The active kid's programme. Starts on the French set, then the stored
/// one, then whatever the backend says next ([adopt]).
class ProgrammeController extends Notifier<Programme> {
  String? _kid;

  @override
  Programme build() {
    final kid = _kid = ref.watch(activeKidIdProvider);
    if (kid != null) {
      final db = ref.watch(localDatabaseProvider);
      Future(() async {
        final stored = await ProgrammeStore(db, kidId: kid).read();
        if (stored != null && ref.mounted && _kid == kid) state = stored;
      }).catchError((Object _) {});
    }
    return const Programme();
  }

  /// What the backend said for [kidId]. Recorded for that kid even if
  /// another kid is playing by the time the answer lands, and shown only
  /// if [kidId] is still the one playing.
  Future<void> adopt(String kidId, Programme programme) async {
    await ProgrammeStore(
      ref.read(localDatabaseProvider),
      kidId: kidId,
    ).write(programme);
    if (!ref.mounted || _kid != kidId || state == programme) return;
    state = programme;
  }
}

final programmeProvider = NotifierProvider<ProgrammeController, Programme>(
  ProgrammeController.new,
);

/// The active kid's subjects, in order: the one list every subject UI
/// draws from (pills, Carte, Village, Progrès, achievements).
final programmeSubjectsProvider = Provider<List<String>>(
  (ref) => ref.watch(programmeProvider.select((p) => p.subjects)),
);
