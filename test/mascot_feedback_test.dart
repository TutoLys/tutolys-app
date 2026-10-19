import 'package:design_system/design_system.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/features/play/mascot_feedback.dart';

void main() {
  test('starts idle', () {
    final feedback = MascotEngineFeedback();
    addTearDown(feedback.dispose);
    expect(feedback.mood.value, MascotMood.idle);
  });

  test('correct shows the correct mood then settles back to idle', () async {
    final feedback = MascotEngineFeedback(hold: const Duration(milliseconds: 1));
    addTearDown(feedback.dispose);
    final seen = <MascotMood>[];
    feedback.mood.addListener(() => seen.add(feedback.mood.value));

    await feedback.correct();

    expect(seen, [MascotMood.correct, MascotMood.idle]);
    expect(feedback.mood.value, MascotMood.idle);
  });

  test('incorrect shows the incorrect mood then settles back to idle', () async {
    final feedback = MascotEngineFeedback(hold: const Duration(milliseconds: 1));
    addTearDown(feedback.dispose);

    await feedback.incorrect();

    expect(feedback.mood.value, MascotMood.idle);
  });

  test('celebrate shows the celebrating mood then settles back to idle', () async {
    final feedback = MascotEngineFeedback(hold: const Duration(milliseconds: 1));
    addTearDown(feedback.dispose);
    final seen = <MascotMood>[];
    feedback.mood.addListener(() => seen.add(feedback.mood.value));

    await feedback.celebrate();

    expect(seen, [MascotMood.celebrating, MascotMood.idle]);
  });

  test('hint shows the hint mood then settles back to idle', () async {
    final feedback = MascotEngineFeedback(hold: const Duration(milliseconds: 1));
    addTearDown(feedback.dispose);
    final seen = <MascotMood>[];
    feedback.mood.addListener(() => seen.add(feedback.mood.value));

    await feedback.hint();

    expect(seen, [MascotMood.hint, MascotMood.idle]);
  });

  test('each reaction is visually distinct from every other', () async {
    // Never let two of these collapse onto the same mood by accident —
    // that would make a kid unable to tell "right" from "a hint exists".
    final feedback = MascotEngineFeedback(hold: const Duration(milliseconds: 1));
    addTearDown(feedback.dispose);

    final moods = <MascotMood>[];
    feedback.mood.addListener(() {
      if (feedback.mood.value != MascotMood.idle) moods.add(feedback.mood.value);
    });

    await feedback.correct();
    await feedback.incorrect();
    await feedback.celebrate();
    await feedback.hint();

    expect(moods.toSet(), {
      MascotMood.correct,
      MascotMood.incorrect,
      MascotMood.celebrating,
      MascotMood.hint,
    });
  });
}
