import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/profile_api.dart';
import '../../data/local_db/database.dart';
import '../pairing/pairing_controller.dart';
import '../progress/local_progress.dart';
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

/// Reached level [level] of the school year (app ADR 0033).
class AvatarAtLevel extends AvatarUnlock {
  const AvatarAtLevel(this.level);
  final int level;
}

/// Earned [achievement], so the avatar and its badge unlock together.
class AvatarForAchievement extends AvatarUnlock {
  const AvatarForAchievement(this.achievement);
  final Achievement achievement;
}

/// Completed [skills] skills of [subject] (a `pathSubjects` code), by this
/// device's own measure: a skill is completed when every lesson on it is
/// finished (ADR 0033). The scientist for science, the knight for CCQ.
class AvatarForSubject extends AvatarUnlock {
  const AvatarForSubject(this.subject, this.skills);
  final String subject;
  final int skills;
}

/// Found by chance on a perfect lesson ([rareDropFor]), never earned from
/// the kid's data. Shown as "?" until found. With a [subject], only a
/// lesson of that subject can reveal it.
class AvatarRare extends AvatarUnlock {
  const AvatarRare({this.subject});
  final String? subject;
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
  const AvatarDef(this.key, this.unlock, {this.sex, this.group, this.asset});

  /// Stored as `Kid.avatar_key` on the backend. Never renamed once shipped.
  final String key;
  final AvatarUnlock unlock;

  /// Who it's offered to. Null means everyone.
  final KidSex? sex;

  /// The character, when it's drawn as a girl and a boy under two keys
  /// (`scientist_girl`, `scientist_boy`). They're one unlock: earning it
  /// unlocks both keys, and each kid is offered the one for their sex.
  final String? group;

  /// The bundled art under `assets/images/`, or null while it isn't drawn
  /// yet. `KidAvatar` draws a placeholder face for a null asset, so the
  /// picker works before the art arrives.
  final String? asset;

  String get character => group ?? key;

  /// A real historical figure, not a "me" character: offered to every kid,
  /// shown in its own picker section with a one-line caption.
  bool get isHistorical => key.startsWith(historicalKeyPrefix);
}

/// Keys of real historical figures start with this (`docs/design/AVATARS.md`).
const historicalKeyPrefix = 'hist_';

const defaultAvatarKey = 'kid_wavy';
const _defaultBoyAvatarKey = 'kid_curly';

/// What a kid wears before choosing. A boy never defaults to Léa.
String defaultAvatarFor(KidSex sex) =>
    sex == KidSex.boy ? _defaultBoyAvatarKey : defaultAvatarKey;

/// Whether the picker offers [a] to a kid of [sex]. An unspecified kid is
/// offered everything.
bool offeredTo(AvatarDef a, KidSex sex) =>
    sex == KidSex.unspecified || a.sex == null || a.sex == sex;

const _girl = KidSex.girl;
const _boy = KidSex.boy;

/// The catalog, in the picker's order: free ones, then by subject, then
/// milestones, then the rare ones. Keys match `docs/design/AVATARS.md`,
/// which also says how to add one (`tool/export_avatars.py` makes the art).
/// A key is stored by the backend, so it is never renamed once shipped.
const avatarCatalog = <AvatarDef>[
  // Free from day one: the kid themself, then two everyday characters.
  AvatarDef(
    defaultAvatarKey,
    AvatarFree(),
    sex: _girl,
    asset: 'avatar-kid-wavy.webp',
  ),
  AvatarDef(
    _defaultBoyAvatarKey,
    AvatarFree(),
    sex: _boy,
    asset: 'avatar-kid-curly.webp',
  ),
  AvatarDef(
    'kid_glasses',
    AvatarFree(),
    sex: _girl,
    asset: 'avatar-kid-glasses.webp',
  ),
  AvatarDef('kid_hijab', AvatarFree(), sex: _girl),
  AvatarDef(
    'kid_freckles',
    AvatarFree(),
    sex: _boy,
    asset: 'avatar-kid-freckles.webp',
  ),
  AvatarDef(
    'kid_braids',
    AvatarFree(),
    sex: _girl,
    asset: 'avatar-kid-braids.webp',
  ),
  AvatarDef(
    'camper_girl',
    AvatarFree(),
    sex: _girl,
    group: 'camper',
    asset: 'avatar-camper-girl.webp',
  ),
  AvatarDef(
    'camper_boy',
    AvatarFree(),
    sex: _boy,
    group: 'camper',
    asset: 'avatar-camper-boy.webp',
  ),
  AvatarDef(
    'explorer_girl',
    AvatarFree(),
    sex: _girl,
    group: 'explorer',
    asset: 'avatar-explorer-girl.webp',
  ),
  AvatarDef(
    'explorer_boy',
    AvatarFree(),
    sex: _boy,
    group: 'explorer',
    asset: 'avatar-explorer-boy.webp',
  ),

  // One per subject, two tiers where the art allows.
  AvatarDef(
    'scientist_girl',
    AvatarForSubject('SCI', 5),
    sex: _girl,
    group: 'scientist',
    asset: 'avatar-scientist-girl.webp',
  ),
  AvatarDef(
    'scientist_boy',
    AvatarForSubject('SCI', 5),
    sex: _boy,
    group: 'scientist',
    asset: 'avatar-scientist-boy.webp',
  ),
  AvatarDef(
    'knight_girl',
    AvatarForSubject('CCQ', 5),
    sex: _girl,
    group: 'knight',
    asset: 'avatar-knight-girl.webp',
  ),
  AvatarDef(
    'knight_boy',
    AvatarForSubject('CCQ', 5),
    sex: _boy,
    group: 'knight',
    asset: 'avatar-knight-boy.webp',
  ),
  AvatarDef(
    'mathematician_girl',
    AvatarForSubject('MATH', 10),
    sex: _girl,
    group: 'mathematician',
    asset: 'avatar-mathematician-girl.webp',
  ),
  AvatarDef(
    'mathematician_boy',
    AvatarForSubject('MATH', 10),
    sex: _boy,
    group: 'mathematician',
    asset: 'avatar-mathematician-boy.webp',
  ),
  AvatarDef(
    'french_teacher_girl',
    AvatarForSubject('FR', 10),
    sex: _girl,
    group: 'french_teacher',
    asset: 'avatar-french-teacher-girl.webp',
  ),
  AvatarDef(
    'french_teacher_boy',
    AvatarForSubject('FR', 10),
    sex: _boy,
    group: 'french_teacher',
    asset: 'avatar-french-teacher-boy.webp',
  ),
  AvatarDef(
    'english_girl',
    AvatarForSubject('EN', 10),
    sex: _girl,
    group: 'english',
    asset: 'avatar-english-girl.webp',
  ),
  AvatarDef(
    'english_boy',
    AvatarForSubject('EN', 10),
    sex: _boy,
    group: 'english',
    asset: 'avatar-english-boy.webp',
  ),
  AvatarDef(
    'historian_girl',
    AvatarForSubject('SOC', 10),
    sex: _girl,
    group: 'historian',
    asset: 'avatar-historian-girl.webp',
  ),
  AvatarDef(
    'historian_boy',
    AvatarForSubject('SOC', 10),
    sex: _boy,
    group: 'historian',
    asset: 'avatar-historian-boy.webp',
  ),
  AvatarDef(
    'chemist_girl',
    AvatarForSubject('SCI', 15),
    sex: _girl,
    group: 'chemist',
    asset: 'avatar-chemist-girl.webp',
  ),
  AvatarDef(
    'chemist_boy',
    AvatarForSubject('SCI', 15),
    sex: _boy,
    group: 'chemist',
    asset: 'avatar-chemist-boy.webp',
  ),
  AvatarDef(
    'fleur_knight_girl',
    AvatarForSubject('CCQ', 15),
    sex: _girl,
    group: 'fleur_knight',
    asset: 'avatar-fleur-knight-girl.webp',
  ),
  AvatarDef(
    'fleur_knight_boy',
    AvatarForSubject('CCQ', 15),
    sex: _boy,
    group: 'fleur_knight',
    asset: 'avatar-fleur-knight-boy.webp',
  ),

  // Milestones: the year's level, the streak, the quests.
  AvatarDef(
    'tuque_girl',
    AvatarAtLevel(2),
    sex: _girl,
    group: 'tuque',
    asset: 'avatar-tuque-girl.webp',
  ),
  AvatarDef(
    'hero_girl',
    AvatarForAchievement(Achievement.streak7),
    sex: _girl,
    group: 'hero',
    asset: 'avatar-hero-girl.webp',
  ),
  AvatarDef(
    'hero_boy',
    AvatarForAchievement(Achievement.streak7),
    sex: _boy,
    group: 'hero',
    asset: 'avatar-hero-boy.webp',
  ),
  AvatarDef(
    'captain_girl',
    AvatarAtLevel(10),
    sex: _girl,
    group: 'captain',
    asset: 'avatar-captain-girl.webp',
  ),
  AvatarDef(
    'captain_boy',
    AvatarAtLevel(10),
    sex: _boy,
    group: 'captain',
    asset: 'avatar-captain-boy.webp',
  ),
  AvatarDef(
    'artist_girl',
    AvatarForAchievement(Achievement.quests50),
    sex: _girl,
    group: 'artist',
    asset: 'avatar-artist-girl.webp',
  ),
  AvatarDef(
    'artist_boy',
    AvatarForAchievement(Achievement.quests50),
    sex: _boy,
    group: 'artist',
    asset: 'avatar-artist-boy.webp',
  ),
  AvatarDef('fox_hood', AvatarAtLevel(20)),

  // Rare: only ever found on a perfect lesson.
  AvatarDef(
    'wizard_girl',
    AvatarRare(),
    sex: _girl,
    group: 'wizard',
    asset: 'avatar-wizard-girl.webp',
  ),
  AvatarDef(
    'wizard_boy',
    AvatarRare(),
    sex: _boy,
    group: 'wizard',
    asset: 'avatar-wizard-boy.webp',
  ),
  AvatarDef(
    'astronaut_girl',
    AvatarRare(),
    sex: _girl,
    group: 'astronaut',
    asset: 'avatar-astronaut-girl.webp',
  ),
  AvatarDef(
    'astronaut_boy',
    AvatarRare(),
    sex: _boy,
    group: 'astronaut',
    asset: 'avatar-astronaut-boy.webp',
  ),
  AvatarDef(
    'coder_girl',
    AvatarRare(),
    sex: _girl,
    group: 'coder',
    asset: 'avatar-coder-girl.webp',
  ),
  AvatarDef(
    'coder_boy',
    AvatarRare(),
    sex: _boy,
    group: 'coder',
    asset: 'avatar-coder-boy.webp',
  ),
  AvatarDef('mermaid', AvatarRare(), sex: _girl, asset: 'avatar-mermaid.webp'),
  AvatarDef('pirate', AvatarRare(), sex: _boy, asset: 'avatar-pirate.webp'),

  // Historical figures of Québec: rare, and only on a perfect CCQ lesson.
  // Real people, offered to everyone whatever their sex.
  AvatarDef(
    'hist_therese_casgrain',
    AvatarRare(subject: 'CCQ'),
    asset: 'avatar-hist-therese-casgrain.webp',
  ),
  AvatarDef(
    'hist_rene_levesque',
    AvatarRare(subject: 'CCQ'),
    asset: 'avatar-hist-rene-levesque.webp',
  ),
];

/// Whether [key] is in the catalog. A key that isn't (from a newer app, or
/// one retired before release) is worn as the kid's default instead.
bool isKnownAvatar(String? key) => avatarCatalog.any((a) => a.key == key);

/// The catalog entry for [key], or the default for an unknown or empty one:
/// a key set by a newer app or in the portal still draws something.
AvatarDef avatarFor(String? key) => avatarCatalog.firstWhere(
  (a) => a.key == key,
  orElse: () => avatarCatalog.first,
);

/// Every key of [character]: its girl and boy versions, or the one key.
List<String> keysOf(String character) => [
  for (final a in avatarCatalog)
    if (a.character == character) a.key,
];

/// Which avatars the kid's data earns right now. Free ones always, rare
/// ones never (they're found, see [rareDropFor]). Both keys of a character
/// unlock together; the picker then offers the kid the one for their sex.
///
/// [level] is null offline. That only means nothing new unlocks by level
/// until the next online read; what unlocked before stays recorded in
/// [AvatarStore].
Set<String> earnedAvatars({
  required int? level,
  required bool Function(Achievement) has,
  int Function(String subject)? completedIn,
}) {
  bool earned(AvatarUnlock u) => switch (u) {
    AvatarFree() => true,
    AvatarAtLevel(level: final needed) => (level ?? 0) >= needed,
    AvatarForAchievement(:final achievement) => has(achievement),
    AvatarForSubject(:final subject, :final skills) =>
      (completedIn?.call(subject) ?? 0) >= skills,
    AvatarRare() => false,
  };
  return {
    for (final a in avatarCatalog)
      if (earned(a.unlock)) a.key,
  };
}

/// The chance that a perfect lesson reveals a rare avatar: about one in 20.
const rareDropPerMille = 50;

/// The rare character a perfect [lessonId] reveals to [kidId], or null.
///
/// Deterministic per kid and lesson, so replaying a lesson can't reroll
/// it. Whether a lesson drops never changes; [AvatarStore] also records
/// each lesson that has dropped, so a lucky one can't be replayed for the
/// rest of the pool. Siblings roll differently on the same lesson.
///
/// Only characters offered to [sex] and not yet [unlocked] can drop, so
/// nothing is wasted on a duplicate. A rare avatar tied to a subject (the
/// historical figures, CCQ) drops only from a lesson of that [subject].
String? rareDropFor({
  required String kidId,
  required String lessonId,
  required KidSex sex,
  required Set<String> unlocked,
  String? subject,
}) {
  if (stableHash('$kidId|$lessonId') % 1000 >= rareDropPerMille) return null;
  final pool = <String>{
    for (final a in avatarCatalog)
      if (a.unlock case AvatarRare(subject: final only)
          when (only == null || only == subject) &&
              offeredTo(a, sex) &&
              !unlocked.contains(a.key))
        a.character,
  }.toList()..sort();
  if (pool.isEmpty) return null;
  return pool[stableHash('$lessonId|$kidId') % pool.length];
}

/// 32-bit FNV-1a over UTF-8, the same on every platform. `String.hashCode`
/// isn't: it can change between runs. The multiply is split so it stays
/// exact on web, where ints are doubles.
int stableHash(String s) {
  var h = 0x811c9dc5;
  for (final b in utf8.encode(s)) {
    h ^= b;
    // h * 16777619 mod 2^32, with 16777619 = 2^24 + 403.
    h = (h * 403 + (h & 0xff) * 0x1000000) & 0xffffffff;
  }
  return h;
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
  static const _dropsKey = 'avatar.drops';

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

  /// Lessons that have revealed a rare avatar, by lesson id, with the
  /// character each one revealed. A lesson is in here at most once, which
  /// is what stops a lucky lesson being replayed for the rest of the pool.
  Future<Map<String, String>> drops() async {
    final raw = await _read(_dropsKey);
    if (raw == null) return {};
    return (jsonDecode(raw) as Map<String, dynamic>).cast<String, String>();
  }

  /// Adds [other] (the backend's copy) to the recorded drops. A lesson
  /// already recorded here keeps its value, as on the backend.
  Future<Map<String, String>> mergeDrops(Map<String, String> other) async {
    final current = await drops();
    final merged = {...other, ...current};
    if (merged.length != current.length) {
      await _write(_dropsKey, jsonEncode(merged));
    }
    return merged;
  }

  /// Records that [lessonId] revealed [character] and unlocks its keys.
  Future<void> recordDrop(String lessonId, String character) async {
    final current = await drops();
    current[lessonId] = character;
    await _write(_dropsKey, jsonEncode(current));
    await recordUnlocked(keysOf(character));
  }

  Future<String?> _read(String key) async {
    final row =
        await (db.select(db.appStateTable)
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
  List<AvatarDef> get offered => [
    for (final a in avatarCatalog)
      if (offeredTo(a, sex)) a,
  ];
}

final profileApiProvider = Provider<ProfileApi>(
  (ref) => ProfileApi(dio: ref.watch(dioProvider)),
);

/// Completed skills per subject code, by this device's own measure (a skill
/// is completed when every lesson on it is finished, ADR 0033). What the
/// subject avatars unlock on. It recomputes the moment a lesson ends,
/// because the play screen invalidates the record it reads.
final completedSkillsBySubjectProvider = FutureProvider<Map<String, int>>((
  ref,
) async {
  final kid = ref.watch(sessionControllerProvider).kid;
  if (kid == null) return const {};
  final local = await ref.watch(localNodeProgressProvider.future);
  if (local.isEmpty) return const {};
  final db = ref.watch(localDatabaseProvider);
  final leaves = await (db.select(
    db.skillNodeTable,
  )..where((t) => t.id.isIn(local.keys))).get();
  final out = <String, int>{};
  for (final leaf in leaves) {
    if ((local[leaf.id] ?? 0) >= 1) {
      out[leaf.subject] = (out[leaf.subject] ?? 0) + 1;
    }
  }
  return out;
});

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
    final board = await ref
        .watch(questBoardProvider.future)
        .then<QuestBoard?>((b) => b, onError: (_) => null);
    final bySubject = await ref
        .watch(completedSkillsBySubjectProvider.future)
        .then<Map<String, int>>(
          (m) => m,
          onError: (_) => const <String, int>{},
        );
    final unlocked = await store.recordUnlocked(
      earnedAvatars(
        level: level,
        has: (a) => board?.has(a) ?? false,
        completedIn: (subject) => bySubject[subject] ?? 0,
      ),
    );

    // Kept server-side too (backend ADR 0064), so a reinstall or a second
    // device never loses one. Both sides only add, so syncing is a union
    // and nothing is ever taken away.
    final unlockedNow = await _syncUnlocks(store, unlocked);

    // Read on every build, not only the first: an adult can set the sex
    // in the portal long after pairing. Offline keeps the cached value.
    final remote = await _remote();
    var sex = await store.sex();
    if (remote?.sex case final reported? when reported != sex) {
      sex = reported;
      await store.setSex(sex);
    }

    // A key the catalog doesn't know is worn as the default, not as Léa
    // for a boy: one from a newer app, or one retired before release.
    var selected = await store.selected();
    if (!isKnownAvatar(selected)) selected = null;
    final remoteKey = remote?.avatarKey;
    if (selected == null && isKnownAvatar(remoteKey)) {
      selected = remoteKey;
      await store.select(remoteKey!);
    }
    return AvatarState(
      selected: selected ?? defaultAvatarFor(sex),
      unlocked: unlockedNow,
      sex: sex,
    );
  }

  /// Posts this device's unlocks and drops, and records whatever the
  /// backend adds. Offline or without the endpoint, the local set stands.
  Future<Set<String>> _syncUnlocks(
    AvatarStore store,
    Set<String> local,
  ) async {
    final token = ref.read(sessionControllerProvider).accessToken;
    if (token == null) return local;
    final remote = await ref.read(profileApiProvider).mergeAvatarUnlocks(
          accessToken: token,
          unlocked: local,
          drops: await store.drops(),
        );
    if (remote == null) return local;
    await store.mergeDrops(remote.drops);
    return store.recordUnlocked(remote.unlocked);
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
    state = AsyncData(
      AvatarState(selected: key, unlocked: current.unlocked, sex: current.sex),
    );
    // Best effort: offline, or a backend without the endpoint yet, leaves
    // the choice local. The next pick pushes again.
    final token = ref.read(sessionControllerProvider).accessToken;
    if (token != null) {
      await ref
          .read(profileApiProvider)
          .saveAvatarKey(accessToken: token, avatarKey: key);
    }
  }

  /// Rolls for a rare avatar after [lessonId] was completed perfectly
  /// ([rareDropFor]). Returns the key this kid was given, offered to their
  /// sex, or null. Never twice for the same lesson.
  Future<String?> rollRareDrop(String rawLessonId, {String? subject}) async {
    // The backend stores lesson ids lowercase; matching it keeps one entry
    // per lesson after a sync.
    final lessonId = rawLessonId.toLowerCase();
    final store = ref.read(avatarStoreProvider);
    final kidId = ref.read(activeKidIdProvider);
    if (kidId == null) return null;
    if ((await store.drops()).containsKey(lessonId)) return null;
    final sex = await store.sex();
    final unlocked = await store.unlocked();
    final character = rareDropFor(
      kidId: kidId,
      lessonId: lessonId,
      sex: sex,
      unlocked: unlocked,
      subject: subject,
    );
    if (character == null) return null;
    await store.recordDrop(lessonId, character);
    ref.invalidateSelf();
    return keysOf(character).firstWhere(
      (k) => offeredTo(avatarFor(k), sex),
      orElse: () => keysOf(character).first,
    );
  }
}

final avatarControllerProvider =
    AsyncNotifierProvider<AvatarController, AvatarState>(AvatarController.new);

/// The active kid's avatar key, the default until it's read.
final selectedAvatarKeyProvider = Provider<String>(
  (ref) =>
      ref.watch(avatarControllerProvider).value?.selected ?? defaultAvatarKey,
);
