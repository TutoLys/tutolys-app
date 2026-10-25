/// What a learner submitted, normalised so every engine speaks one language.
///
/// **Ids only.** An answer never carries question stems or option labels —
/// the old Godot shell's `answer_submit` had that property and the plan keeps
/// it (frontend spec §3.8). It is what lets an attempt be stored, hashed and
/// compared across content revisions without becoming a copy of the content.
/// The one exception is [TextAnswer], whose value *is* the answer; it is
/// length-capped for that reason.
sealed class AnswerValue {
  const AnswerValue();

  /// Discriminator on the wire. Stable: telemetry and server-side
  /// re-evaluation both key off it.
  String get kind;

  Map<String, Object?> toJson();

  /// Inverse of [toJson]. Returns null for an unknown kind or a malformed
  /// payload rather than throwing — a stored snapshot from a newer app
  /// version must not crash an older one.
  static AnswerValue? fromJson(Map<String, Object?> json) {
    try {
      return switch (json['kind']) {
        'single_choice' => SingleChoiceAnswer(json['selected'] as String),
        'multi_select' => MultiSelectAnswer(_strings(json['selected'])),
        'pairs' => PairsAnswer([
          for (final p in json['pairs'] as List)
            (left: (p as Map)['left'] as String, right: p['right'] as String),
        ]),
        'ordering' => OrderingAnswer(_strings(json['order'])),
        'placements' => PlacementsAnswer(
          (json['placements'] as Map).cast<String, String>(),
        ),
        'text' => TextAnswer(json['value'] as String),
        'blanks' => BlanksAnswer(
          (json['blanks'] as Map).cast<String, String>(),
        ),
        'hotspot' => HotspotAnswer(_strings(json['regions'])),
        _ => null,
      };
    } on Object {
      return null;
    }
  }

  static List<String> _strings(Object? v) => (v as List).cast<String>();
}

class SingleChoiceAnswer extends AnswerValue {
  const SingleChoiceAnswer(this.selectedOptionId);
  final String selectedOptionId;

  @override
  String get kind => 'single_choice';

  @override
  Map<String, Object?> toJson() => {'kind': kind, 'selected': selectedOptionId};
}

class MultiSelectAnswer extends AnswerValue {
  /// Sorted on construction: selection order carries no meaning here, and two
  /// equal answers must hash identically for `repeated_wrong_rate` to work.
  MultiSelectAnswer(Iterable<String> ids)
    : selectedOptionIds = List.unmodifiable([...ids]..sort());
  final List<String> selectedOptionIds;

  @override
  String get kind => 'multi_select';

  @override
  Map<String, Object?> toJson() => {
    'kind': kind,
    'selected': selectedOptionIds,
  };
}

class PairsAnswer extends AnswerValue {
  PairsAnswer(Iterable<({String left, String right})> pairs)
    : pairs = List.unmodifiable(
        [...pairs]..sort((a, b) => a.left.compareTo(b.left)),
      );
  final List<({String left, String right})> pairs;

  @override
  String get kind => 'pairs';

  @override
  Map<String, Object?> toJson() => {
    'kind': kind,
    'pairs': [
      for (final p in pairs) {'left': p.left, 'right': p.right},
    ],
  };
}

class OrderingAnswer extends AnswerValue {
  OrderingAnswer(Iterable<String> ids)
    : orderedItemIds = List.unmodifiable(ids);
  final List<String> orderedItemIds;

  @override
  String get kind => 'ordering';

  @override
  Map<String, Object?> toJson() => {'kind': kind, 'order': orderedItemIds};
}

class PlacementsAnswer extends AnswerValue {
  /// item id → target id.
  PlacementsAnswer(Map<String, String> placements)
    : placements = Map.unmodifiable(placements);
  final Map<String, String> placements;

  @override
  String get kind => 'placements';

  @override
  Map<String, Object?> toJson() => {'kind': kind, 'placements': placements};
}

class TextAnswer extends AnswerValue {
  /// Values longer than this are truncated. A grade-1 numeric or one-word
  /// answer is far shorter; anything longer is not an answer we evaluate,
  /// and capping it keeps a pasted paragraph out of the event store.
  static const maxLength = 64;

  TextAnswer(String value)
    : value = value.length > maxLength ? value.substring(0, maxLength) : value;
  final String value;

  @override
  String get kind => 'text';

  @override
  Map<String, Object?> toJson() => {'kind': kind, 'value': value};
}

class BlanksAnswer extends AnswerValue {
  /// blank id → value, each capped like [TextAnswer].
  BlanksAnswer(Map<String, String> blanks)
    : blanks = Map.unmodifiable({
        for (final e in blanks.entries) e.key: TextAnswer(e.value).value,
      });
  final Map<String, String> blanks;

  @override
  String get kind => 'blanks';

  @override
  Map<String, Object?> toJson() => {'kind': kind, 'blanks': blanks};
}

class HotspotAnswer extends AnswerValue {
  HotspotAnswer(Iterable<String> ids)
    : selectedRegionIds = List.unmodifiable([...ids]..sort());
  final List<String> selectedRegionIds;

  @override
  String get kind => 'hotspot';

  @override
  Map<String, Object?> toJson() => {'kind': kind, 'regions': selectedRegionIds};
}
