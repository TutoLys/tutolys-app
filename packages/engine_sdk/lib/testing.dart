/// Test doubles for code built on the engine SDK — a minimal
/// `LearningEngine` and evaluator, so the runtime, the shell and the app can
/// be exercised before any real engine is ported. Never imported by `lib/`
/// code outside tests.
library;

export 'testing/fake_choice_engine.dart';
