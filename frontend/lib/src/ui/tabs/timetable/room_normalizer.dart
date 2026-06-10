/// Normalizes free-text room/location strings so visually-identical rooms
/// (e.g. "A강의실" vs "a강의실 ") collapse to a single logical room.
///
/// Pure utility — no Flutter / controller dependency. Used by both the
/// per-class builder (room palette dedupe + location writes) and the
/// whole-school overlay board (room-axis pivot grouping).
class RoomNormalizer {
  const RoomNormalizer._();

  /// Display form: trims leading/trailing whitespace and collapses any run of
  /// internal whitespace to a single space. The original casing is preserved
  /// so the user still sees what they typed.
  static String normalize(String raw) {
    return raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Dedupe key: [normalize] then lowercased so case-insensitive duplicates
  /// map to the same bucket. Use this for grouping / equality, never for
  /// display.
  static String canonical(String raw) {
    return normalize(raw).toLowerCase();
  }
}
