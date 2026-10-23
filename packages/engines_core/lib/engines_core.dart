/// Set A (`mcq`, `pair_match`, `compose_build` — one per interaction shape,
/// chosen to prove the engine abstraction rather than three variants of
/// tapping) plus Phase 5's engines as they land. `speed_tap` is the first:
/// same content shape as `mcq`, an arcade/timed presentation layer over it.
library;

export 'src/compose_build_engine.dart';
export 'src/mcq_engine.dart';
export 'src/pair_match_engine.dart';
export 'src/speed_tap_engine.dart';
