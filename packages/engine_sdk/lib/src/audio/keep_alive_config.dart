/// What keeps the audio output awake, and how loud (ADR 0043).
///
/// Bluetooth is why this is a choice at all. Hafid listens over Bluetooth
/// (Chrome, Linux, PipeWire), and the first version's DC constant at gain
/// 0.0001 (~-80 dBFS, a few LSB at 16-bit) can reach the codec as digital
/// silence — or be filtered out as DC — so the headset still powered its
/// audio path down and lost the first ~0.5–1 s of the next clip. The
/// default is now a very low tone that survives the codec but not the ear.
///
/// Every field can be overridden from the page URL, so variants are tried
/// on the one machine that shows the bug without a rebuild:
/// `?audiokeepalive=tone|noise|dc|off&audiolevel=0.001&audiopreroll=300`.
class KeepAliveConfig {
  const KeepAliveConfig({
    this.kind = KeepAliveKind.tone,
    this.level = defaultLevel,
    this.toneHz = defaultToneHz,
    this.preRollMs = 0,
  });

  /// -60 dBFS: about 33 LSB at 16-bit, far above any codec's digital-silence
  /// threshold, yet far below hearing for a 25 Hz tone through headphones
  /// (the ear's threshold there is ~60 dB SPL; this is well under that).
  static const defaultLevel = 0.001;

  /// Below what earbuds reproduce well and below easy hearing at
  /// [defaultLevel], but a real AC signal every codec (SBC, AAC) carries and
  /// no DC filter removes.
  static const defaultToneHz = 25.0;

  final KeepAliveKind kind;

  /// Linear gain, 0..0.05 (a cap so a typo can't make it audible).
  final double level;
  final double toneHz;

  /// Extra wait before each clip's first sample, during which the
  /// keep-alive signal is already being transmitted. 0 by default: with the
  /// signal running the sink should already be awake.
  final int preRollMs;

  static KeepAliveConfig fromQuery(Map<String, String> q) {
    final kind = switch (q['audiokeepalive']) {
      'noise' => KeepAliveKind.noise,
      'dc' => KeepAliveKind.dc,
      'off' => KeepAliveKind.off,
      _ => KeepAliveKind.tone,
    };
    final level = double.tryParse(q['audiolevel'] ?? '');
    final preRoll = int.tryParse(q['audiopreroll'] ?? '');
    return KeepAliveConfig(
      kind: kind,
      level: level == null ? defaultLevel : level.clamp(0, 0.05).toDouble(),
      preRollMs: preRoll == null ? 0 : preRoll.clamp(0, 2000),
    );
  }

  @override
  String toString() =>
      '${kind.name} @ $level${kind == KeepAliveKind.tone ? ' ${toneHz}Hz' : ''}'
      ', pre-roll ${preRollMs}ms';
}

enum KeepAliveKind {
  /// A low sine — the default.
  tone,

  /// Low white noise, looped.
  noise,

  /// The first version: a DC constant. Kept to compare against.
  dc,

  /// No keep-alive signal at all.
  off,
}
