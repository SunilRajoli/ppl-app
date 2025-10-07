extension NullableStringX on String? {
  /// True if there's any non-whitespace text
  bool get hasText => (this?.trim().isNotEmpty ?? false);

  /// Return empty string when null
  String get orEmpty => this ?? '';
}
