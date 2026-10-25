/// Outcome of parsing untrusted content at a runtime boundary.
///
/// Three cases, not two, because the host reacts differently: [ParseInvalid]
/// is a content bug (log it, skip the exercise), [ParseUnsupported] means
/// this app is too old (show "update needed"). Neither throws — a child's
/// session must never crash over content.
sealed class ParseResult<T> {
  const ParseResult();

  const factory ParseResult.ok(T value) = ParseOk<T>;
  const factory ParseResult.invalid(String reason) = ParseInvalid<T>;
  const factory ParseResult.unsupported(String reason) = ParseUnsupported<T>;

  /// The parsed value, or null for either failure.
  T? get valueOrNull => switch (this) {
    ParseOk(:final value) => value,
    _ => null,
  };
}

class ParseOk<T> extends ParseResult<T> {
  const ParseOk(this.value);
  final T value;
}

class ParseInvalid<T> extends ParseResult<T> {
  const ParseInvalid(this.reason);
  final String reason;
}

class ParseUnsupported<T> extends ParseResult<T> {
  const ParseUnsupported(this.reason);
  final String reason;
}
