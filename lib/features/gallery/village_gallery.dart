import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/strings.dart';
import '../../core/routing/paired_router.dart';
import '../../data/local_db/database.dart';
import '../pairing/pairing_controller.dart';

/// The Village's gallery building (ADR 0098): "Ma galerie au village", the
/// `my_gallery` engine (ADR 0092) on the playing kid's own shelf, with no
/// leaf behind it.

/// The building's code in the scene, beside the subject codes. Not a
/// subject: it never reaches the Carte, the backend or telemetry.
const galleryBuildingCode = 'GALLERY';

/// The id the gallery plays under. Its resume snapshot is per kid, like
/// every activity session (ADR 0014).
const galleryExerciseId = 'village-gallery';

/// Stands in for the leaf PlayScreen titles its game with.
CachedSkillNode galleryNode(Strings t, {int grade = 1}) => CachedSkillNode(
  id: galleryExerciseId,
  labelFr: Strings.fr.galleryBuilding,
  labelEn: Strings.en.galleryBuilding,
  stableKey: 'village/gallery',
  subject: galleryBuildingCode,
  grade: grade,
);

/// The gallery as an envelope the shell plays like any game. App-authored,
/// in the app's language: the reasons a child can give, and the village
/// characters who come by to look.
Map<String, Object?> galleryEnvelope(Strings t, {required bool english}) => {
  'schema_version': 1,
  'exercise_id': galleryExerciseId,
  'version': 1,
  'engine_key': 'my_gallery',
  'engine_min_version': 1,
  'skill_node_id': galleryExerciseId,
  'subject': galleryBuildingCode,
  'grade': 1,
  'rank': 0,
  'locale': english ? 'en-CA' : 'fr-CA',
  'prompt': {'text': t.galleryPrompt, 'audio_ref': null, 'image_ref': null},
  'config': {
    'reasons': [
      {'id': 'proud', 'label': t.galleryReasonProud},
      {'id': 'pretty', 'label': t.galleryReasonPretty},
      {'id': 'hard', 'label': t.galleryReasonHard},
      {'id': 'funny', 'label': t.galleryReasonFunny},
    ],
    'visitors': [
      {'character': 'foxy', 'comment': t.galleryVisitorFoxy},
      {'character': 'lea', 'comment': t.galleryVisitorLea},
    ],
    'max_hang': 3,
  },
  'assets': const <Object?>[],
};

/// Opens the gallery as practice: no mastery, no XP, nothing uploaded
/// (ADR 0098). Returns once the kid is back in the Village.
Future<void> openVillageGallery(BuildContext context, WidgetRef ref) {
  final t = context.s;
  final english = Localizations.localeOf(context).languageCode == 'en';
  final grade = ref.read(sessionControllerProvider).kid?.gradeLevel ?? 1;
  return GoRouter.of(context).push(
    '/play',
    extra: PlayRequest(
      node: galleryNode(t, grade: grade),
      envelope: galleryEnvelope(t, english: english),
      practice: true,
    ),
  );
}
