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

/// The kid's sex, as an adult set it in the portal (`Kid.sex`). The device
/// only ever reads it. [unspecified] covers kids created before the field
/// existed, and a backend that doesn't send it yet.
enum KidSex {
  girl,
  boy,
  unspecified;

  static KidSex parse(String? raw) => switch (raw) {
        'girl' => girl,
        'boy' => boy,
        _ => unspecified,
      };

  String get wire => this == unspecified ? '' : name;
}

/// One avatar in the catalog (`docs/design/AVATARS.md`).
class AvatarDef {
  const AvatarDef(this.key, this.unlock, {this.sex, this.asset});

  /// Stored as `Kid.avatar_key` on the backend. Never renamed once shipped.
  final String key;
  final AvatarUnlock unlock;

  /// Who it's offered to. Null means everyone: the unlockables, until
  /// their art says otherwise.
  final KidSex? sex;

  /// The bundled art under `assets/images/`, or null while it isn't drawn
  /// yet. `KidAvatar` draws a placeholder face for a null asset, so the
  /// picker works before the art arrives.
  final String? asset;
}

const defaultAvatarKey = 'kid_wavy';
const _defaultBoyAvatarKey = 'kid_curly';

/// What a kid wears before choosing. A boy never defaults to Léa.
String defaultAvatarFor(KidSex sex) =>
    sex == KidSex.boy ? _defaultBoyAvatarKey : defaultAvatarKey;

/// Whether the picker offers [a] to a kid of [sex]. An unspecified kid is
/// offered everything.
bool offeredTo(AvatarDef a, KidSex sex) =>
    sex == KidSex.unspecified || a.sex == null || a.sex == sex;

/// The catalog, in the picker's order: starters, then unlockables from
/// easiest to rarest. Keys match `docs/design/AVATARS.md`, which also says
/// how to add one: a 512px webp in `assets/images/`, plus one line here.
/// A key is stored by the backend, so it is never renamed once shipped.
const avatarCatalog = <AvatarDef>[
  AvatarDef(defaultAvatarKey, AvatarFree(),
      sex: KidSex.girl, asset: 'avatar-kid-wavy.webp'),
  AvatarDef(_defaultBoyAvatarKey, AvatarFree(),
      sex: KidSex.boy, asset: 'avatar-kid-curly.webp'),
  AvatarDef('kid_glasses', AvatarFree(),
      sex: KidSex.girl, asset: 'avatar-kid-glasses.webp'),
  AvatarDef('kid_hijab', AvatarFree(), sex: KidSex.girl),
  AvatarDef('kid_freckles', AvatarFree(), sex: KidSex.boy),
  AvatarDef('kid_braids', AvatarFree(), sex: KidSex.girl),
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
  static const _sexKey = 'kid.sex';

  Future<String?> selected() => _read(_selectedKey);

  /// The last sex the backend reported, so the default and the picker
  /// follow it offline and on "Qui joue ?".
  Future<KidSex> sex() async => KidSex.parse(await _read(_sexKey));

  Future<void> setSex(KidSex sex) => _write(_sexKey, sex.wire);

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
  const AvatarState({
    required this.selected,
    required this.unlocked,
    this.sex = KidSex.unspecified,
  });

  /// What the kid wears. It can be one the picker no longer offers: an
  /// avatar chosen before the kid's sex was set stays on until they pick
  /// another (ADR 0024).
  final String selected;
  final Set<String> unlocked;
  final KidSex sex;

  bool isUnlocked(String key) => unlocked.contains(key);

  /// The catalog as the picker shows it to this kid.
  List<AvatarDef> get offered =>
      [for (final a in avatarCatalog) if (offeredTo(a, sex)) a];
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

    // Read on every build, not only the first: an adult can set the sex
    // in the portal long after pairing. Offline keeps the cached value.
    final remote = await _remote();
    var sex = await store.sex();
    if (remote?.sex case final reported? when reported != sex) {
      sex = reported;
      await store.setSex(sex);
    }

    var selected = await store.selected();
    final remoteKey = remote?.avatarKey;
    if (selected == null && remoteKey != null && remoteKey.isNotEmpty) {
      selected = remoteKey;
      await store.select(remoteKey);
    }
    return AvatarState(
      selected: selected ?? defaultAvatarFor(sex),
      unlocked: unlocked,
      sex: sex,
    );
  }

  Future<RemoteProfile?> _remote() async {
    final token = ref.read(sessionControllerProvider).accessToken;
    if (token == null) return null;
    return ref.read(profileApiProvider).fetchProfile(accessToken: token);
  }

  /// Wear [key]. Locked avatars, and avatars not offered to this kid's
  /// sex, are refused: the picker never offers either, and this is the one
  /// place that would let one through.
  Future<void> select(String key) async {
    final current = state.value;
    if (current == null || !current.isUnlocked(key)) return;
    if (!offeredTo(avatarFor(key), current.sex)) return;
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
