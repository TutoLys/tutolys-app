/// What an engine's interaction means to a character.
///
/// Engines report interactions under wire names chosen before this table
/// existed (`tile_placed`, `move_added`…). Those names are durable, so they
/// stay: renaming one would split every telemetry aggregate that reads it.
/// The motion layer reads the *moment* instead, through [momentOf].
///
/// New engines use only the canonical names: `option_selected`,
/// `item_placed`, `item_removed`, `pair_connected`, `experiment_run` and
/// `reveal`. The app's `architecture_boundaries_test` fails if an engine
/// emits a name missing here (plan PLAN_GRADES_2_6_ENGINES §3.3, fix 6).
enum EngineMoment {
  /// A choice made or changed.
  select,

  /// Something put on the board.
  place,

  /// Something taken back off it.
  remove,

  /// Two things linked.
  connect,

  /// The child ran something to see what happens: an experiment, a trial.
  run,

  /// The engine shows a consequence: an outcome, a clue, a tip.
  reveal,

  /// A countdown ran out (speed_tap, diagnostic tests only).
  timeout,
}

/// Every interaction wire name in use, and its moment.
const Map<String, EngineMoment> interactionMoments = {
  'option_selected': EngineMoment.select,
  'option_deselected': EngineMoment.select,
  'item_placed': EngineMoment.place,
  'tile_placed': EngineMoment.place,
  'tile_moved': EngineMoment.place,
  'move_added': EngineMoment.place,
  'item_removed': EngineMoment.remove,
  'tile_removed': EngineMoment.remove,
  'move_removed': EngineMoment.remove,
  'pair_disconnected': EngineMoment.remove,
  'pair_connected': EngineMoment.connect,
  'experiment_run': EngineMoment.run,
  'reveal': EngineMoment.reveal,
  'time_expired': EngineMoment.timeout,
};

/// The moment behind [type], or null for a name nobody registered.
EngineMoment? momentOf(String type) => interactionMoments[type];
