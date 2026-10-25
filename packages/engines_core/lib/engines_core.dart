/// Set A (`mcq`, `pair_match`, `compose_build` — one per interaction shape,
/// chosen to prove the engine abstraction rather than three variants of
/// tapping) plus Phase 5's engines as they land. `speed_tap` is the first:
/// same content shape as `mcq`, an arcade/timed presentation layer over it.
library;

export 'src/compose_build_engine.dart';
export 'src/mcq_engine.dart';
export 'src/pair_match_engine.dart';
export 'src/speed_tap_engine.dart';
export 'src/shell/activity_shell.dart';
export 'src/shell/learning_activity_view.dart';
export 'src/shell/legacy_engine_host.dart';
export 'src/shell/shell_strings.dart';
export 'src/single_choice/single_choice_engine.dart';
export 'src/widgets/answer_tile.dart';
export 'src/widgets/answer_slot.dart';
export 'src/widgets/countdown_bar.dart';
export 'src/compose_build/compose_slots_engine.dart';
export 'src/pair_match/pair_match_board_engine.dart';
export 'src/speed_tap/timed_choice_engine.dart';
export 'src/shell/activity_complete_view.dart';
export 'src/sort_buckets/sort_buckets_engine.dart';
