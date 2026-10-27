import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/assignments_api.dart';
import '../pairing/pairing_controller.dart';

final assignmentsApiProvider = Provider<AssignmentsApi>(
  (ref) => AssignmentsApi(dio: ref.watch(dioProvider)),
);

/// Teachers assign during the school day, not by the second.
const assignmentsPollEvery = Duration(minutes: 5);

/// Off in tests that keep a container alive, like the inbox's polling.
final assignmentsPollingProvider = Provider<bool>((ref) => true);

/// The kid's teacher-assigned work (backend ADR 0123): shown in Quêtes
/// under "De ton enseignant·e", and as a tag on the Carte. Keeps what it
/// last had while offline; never invents work.
class AssignmentsController extends Notifier<List<AssignmentDto>> {
  @override
  List<AssignmentDto> build() {
    // A sibling's homework never shows for another kid.
    ref.watch(activeKidIdProvider);
    if (ref.watch(assignmentsPollingProvider)) {
      final timer = Timer.periodic(assignmentsPollEvery, (_) => refresh());
      ref.onDispose(timer.cancel);
    }
    Future.microtask(refresh);
    return const [];
  }

  Future<void> refresh() async {
    final token = ref.read(sessionControllerProvider).accessToken;
    if (token == null) return;
    final fetched = await ref
        .read(assignmentsApiProvider)
        .fetch(accessToken: token);
    if (!ref.mounted || fetched == null) return;
    state = fetched;
  }
}

final assignmentsControllerProvider =
    NotifierProvider<AssignmentsController, List<AssignmentDto>>(
      AssignmentsController.new,
    );

/// Skill ids with open (not yet done) work, for the Carte's tag.
final assignedSkillIdsProvider = Provider<Set<String>>(
  (ref) => {
    for (final a in ref.watch(assignmentsControllerProvider))
      if (!a.done) a.skillNodeId,
  },
);
