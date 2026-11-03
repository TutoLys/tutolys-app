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
export 'src/shell/board_actor.dart';
export 'src/shell/idle_cue.dart' show IdleCueController, IdleCueScope, IdleHand;
export 'src/shell/learning_activity_view.dart';
export 'src/shell/legacy_engine_host.dart';
export 'src/shell/shell_strings.dart';
export 'src/shell/stop_sheet.dart';
export 'src/single_choice/single_choice_engine.dart';
export 'src/widgets/answer_tile.dart';
export 'src/widgets/answer_slot.dart';
export 'src/widgets/countdown_bar.dart';
export 'src/widgets/idle_hand_hint.dart';
export 'src/compose_build/compose_slots_engine.dart';
export 'src/pair_match/pair_match_board_engine.dart';
export 'src/speed_tap/timed_choice_engine.dart';
export 'src/shell/activity_complete_view.dart';
export 'src/sort_buckets/sort_buckets_engine.dart';
export 'src/timeline/timeline_order_engine.dart';
export 'src/find_it/find_it_engine.dart';
export 'src/timeline/timeline_axis_engine.dart';
export 'src/timeline/timeline_calendar_engine.dart';
export 'src/data_graph/data_graph_engine.dart';
export 'src/passage_reader/passage_reader_engine.dart';
export 'src/balance_scale/balance_scale_engine.dart';
export 'src/label_image/label_image_engine.dart';
export 'src/fill_blank/fill_blank_engine.dart';
export 'src/pattern_machine/pattern_machine_engine.dart';
export 'src/measure_tool/measure_tool_engine.dart';
export 'src/widgets/pick_one.dart';
export 'src/path_planner/path_planner_engine.dart';
export 'src/fraction_slice/fraction_slice_engine.dart';
export 'src/geometry_lab/geometry_lab_engine.dart';
export 'src/experiment_lab/experiment_lab_engine.dart';
export 'src/counters_board/counters_board_engine.dart';
export 'src/sky_model/sky_model_engine.dart';
export 'src/mail_studio/mail_studio_engine.dart';
export 'src/widgets/village_characters.dart';
export 'src/feedback_studio/feedback_studio_engine.dart';
export 'src/stage_presenter/stage_presenter_engine.dart';
export 'src/my_gallery/my_gallery_engine.dart';
export 'src/phrase_lab/phrase_lab_engine.dart';
export 'src/proofread/proofread_engine.dart';
export 'src/widgets/creations.dart';
