/// Set A: the first three engines, one per interaction shape.
///
/// `mcq` (tap), `pair_match` (select-and-connect), `compose_build`
/// (assemble) — chosen specifically because they are mechanically distinct,
/// so together they prove the engine abstraction rather than three variants
/// of tapping.
library;

export 'src/compose_build_engine.dart';
export 'src/mcq_engine.dart';
export 'src/pair_match_engine.dart';
