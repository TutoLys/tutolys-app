import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/profile_api.dart';
import '../../data/local_db/database.dart';
import '../pairing/pairing_controller.dart';
import '../progress/progress_controller.dart';
import '../quests/quest_board.dart';

/// What makes an avatar choosable.
sealed class AvatarUnlock {
  const AvatarUnlock();
}

/// Choosable from day one. Every starter is one of these: a kid picks who
/// they look like before they have played anything.
class AvatarFree extends AvatarUnlock {
  const AvatarFree();
}

/// Reached the backend's level [level] (`LevelCurve`, backend ADR 0024).
class AvatarAtLevel extends AvatarUnlock {
  const AvatarAtLevel(this.level);
  final int level;
}

/// Earned [achievement], so the avatar and its badge unlock together.
class AvatarForAchievement extends AvatarUnlock {
  const AvatarForAchievement(this.achievement);
  final Achievement achievement;
}

/// One avatar in the catalog (`docs/design/AVATARS.md`).
class AvatarDef {
  const AvatarDef(this.key, this.unlock, {this.asset});

  /// Stored as `Kid.avatar_key` on the backend. Never renamed once shipped.
  final String key;
  final AvatarUnlock unlock;

  /// The bundled art under `assets/images/`, or null while it isn't drawn
  /// yet. `KidAvatar` draws a placeholder face for a null asset, so the
  /// picker works before the art arrives.
  final String? asset;
}

const defaultAvatarKey = 'kid_wavy';

/// The catalog, in the picker's order: starters, then unlockables from
/// easiest to rarest. Keys match `docs/design/AVATARS.md`.
const avatarCatalog = <AvatarDef>[
  AvatarDef(defaultAvatarKey, AvatarFree(), asset: 'asset-profil.png'),
  AvatarDef('kid_curly', AvatarFree()),
  AvatarDef('kid_glasses', AvatarFree()),
  AvatarDef('kid_hijab', AvatarFree()),
  AvatarDef('kid_freckles', AvatarFree()),
  AvatarDef('kid_braids', AvatarFree()),
  AvatarDef('tuque', AvatarAtLevel(2)),
  AvatarDef('camper', AvatarForAchievement(Achievement.streak3)),
  AvatarDef('astronaut', AvatarAtLevel(3)),
  AvatarDef('explorer', AvatarForAchievement(Achievement.explorer)),
  AvatarDef('captain', AvatarAtLevel(5)),
  AvatarDef('knight', AvatarForAchievement(Achievement.questMaster)),
  AvatarDef('hero', AvatarForAchievement(Achievement.streak7)),
  AvatarDef('wizard', AvatarAtLevel(10)),
  AvatarDef('scientist', AvatarForAchievement(Achievement.allSubjects50)),
  AvatarDef('artist', AvatarForAchievement(Achievement.quests50)),
  AvatarDef('fox_hood', AvatarAtLevel(20)),
];

/// The catalog entry for [key], or the default for an unknown or empty one:
/// a key set by a newer app or in the portal still draws something.
AvatarDef avatarFor(String? key) => avatarCatalog.firstWhere(
      (a) => a.key == key,
      orElse: () => avatarCatalog.first,
    );

/// Which avatars the kid's data earns right now. Free ones always.
///
/// [level] is null offline. That only means nothing new unlocks by level
/// until the next online read; what unlocked before stays recorded in
/// [AvatarStore].
Set<String> earnedAvatars({
  required int? level,
  required bool Function(Achievement) has,
}) {
  bool earned(AvatarUnlock u) => switch (u) {
        AvatarFree() => true,
        AvatarAtLevel(level: final needed) => (level ?? 0) >= needed,
        AvatarForAchievement(:final achievement) => has(achievement),
      };
  return {
    for (final a in avatarCatalog)
      if (earned(a.unlock)) a.key,
  };
}

/// The kid's chosen avatar and every avatar they've unlocked, in
/// `app_state` under the kid's own owner (ADR 0014).
///
/// Unlocks are **monotonic**, like achievements in `QuestLog`: once earned,
/// never taken back. That matters for level unlocks in particular, because
/// retuning the backend's `LevelCurve` restates every level at once, and a
/// kid must not lose an avatar they are wearing.
class AvatarStore {
  const AvatarStore(this.db, {required this.kidId});

  final LocalDatabase db;
  final String kidId;

  static const _selectedKey = 'avatar.selected';
  static const _unlockedKey = 'avatar.unlocked';

  Future<String?> selected() => _read(_selectedKey);

  Future<void> select(String key) => _write(_selectedKey, key);

  Future<Set<String>> unlocked() async {
    final raw = await _read(_unlockedKey);
    if (raw == null) return {};
    return {for (final k in jsonDecode(raw) as List<dynamic>) k as String};
  }

  /// Adds [keys] to the unlocked set. Returns the merged set.
  Future<Set<String>> recordUnlocked(Iterable<String> keys) async {
    final current = await unlocked();
    final before = current.length;
    current.addAll(keys);
    if (current.length != before) {
      await _write(_unlockedKey, jsonEncode(current.toList()..sort()));
    }
    return current;
  }

  Future<String?> _read(String key) async {
    final row = await (db.select(db.appStateTable)
          ..where((t) => t.kidId.equals(kidId))
          ..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> _write(String key, String value) => db
      .into(db.appStateTable)
      .insert(
        AppStateTableCompanion.insert(
          kidId: kidId,
          key: key,
          value: value,
          updatedAt: DateTime.now(),
        ),
        mode: InsertMode.insertOrReplace,
      );
}

/// What Profil's picker and every [KidAvatar] needs.
class AvatarState {
  const AvatarState({required this.selected, required this.unlocked});

  final String selected;
  final Set<String> unlocked;

  bool isUnlocked(String key) => unlocked.contains(key);
}

final profileApiProvider = Provider<ProfileApi>(
  (ref) => ProfileApi(dio: ref.watch(dioProvider)),
);

final avatarStoreProvider = Provider<AvatarStore>(
  (ref) => AvatarStore(
    ref.watch(localDatabaseProvider),
    kidId: ref.watch(activeKidIdProvider) ?? unpairedKidId,
  ),
);

/// The active kid's avatar. Re-evaluated whenever progress or the quest
/// board refresh, which every play session already triggers, so an avatar
/// unlocked by a session is recorded then.
///
/// The selection is local-first. A kid who never picked one here adopts
/// whatever the backend holds (set in the portal, or on another device);
/// after that, this device's choice wins and is pushed up.
class AvatarController extends AsyncNotifier<AvatarState> {
  @override
  Future<AvatarState> build() async {
    final store = ref.watch(avatarStoreProvider);
    final level = ref.watch(progressControllerProvider.select((p) => p.level));
    final board = await ref.watch(questBoardProvider.future).then<QuestBoard?>(
          (b) => b,
          onError: (_) => null,
        );
    final unlocked = await store.recordUnlocked(
      earnedAvatars(level: level, has: (a) => board?.has(a) ?? false),
    );

    var selected = await store.selected();
    if (selected == null) {
      final remote = await _remoteKey();
      if (remote != null && remote.isNotEmpty) {
        selected = remote;
        await store.select(remote);
      }
    }
    return AvatarState(
      selected: selected ?? defaultAvatarKey,
      unlocked: unlocked,
    );
  }

  Future<String?> _remoteKey() async {
    final token = ref.read(sessionControllerProvider).accessToken;
    if (token == null) return null;
    return ref.read(profileApiProvider).fetchAvatarKey(accessToken: token);
  }

  /// Wear [key]. Locked avatars are refused: the picker never offers one,
  /// and this is the one place that would let it through.
  Future<void> select(String key) async {
    final current = state.value;
    if (current == null || !current.isUnlocked(key)) return;
    await ref.read(avatarStoreProvider).select(key);
    state = AsyncData(AvatarState(selected: key, unlocked: current.unlocked));
    // Best effort: offline, or a backend without the endpoint yet, leaves
    // the choice local. The next pick pushes again.
    final token = ref.read(sessionControllerProvider).accessToken;
    if (token != null) {
      await ref
          .read(profileApiProvider)
          .saveAvatarKey(accessToken: token, avatarKey: key);
    }
  }
}

final avatarControllerProvider =
    AsyncNotifierProvider<AvatarController, AvatarState>(AvatarController.new);

/// The active kid's avatar key, the default until it's read.
final selectedAvatarKeyProvider = Provider<String>(
  (ref) =>
      ref.watch(avatarControllerProvider).value?.selected ?? defaultAvatarKey,
);
