// lib/core/utils/version_utils.dart

class VersionUtils {
  const VersionUtils._();

  /// Compare two semantic version strings.
  /// Returns -1 if [a] < [b], 0 if equal, 1 if [a] > [b].
  static int compareSemanticVersions(String a, String b) {
    final normalizedA = _normalize(a);
    final normalizedB = _normalize(b);

    final maxLength = normalizedA.length > normalizedB.length
        ? normalizedA.length
        : normalizedB.length;

    for (var i = 0; i < maxLength; i++) {
      final partA = i < normalizedA.length ? normalizedA[i] : 0;
      final partB = i < normalizedB.length ? normalizedB[i] : 0;

      if (partA > partB) return 1;
      if (partA < partB) return -1;
    }

    return 0;
  }

  static List<int> _normalize(String input) {
    final sanitized = input.split(RegExp(r"[+\-]"))[0];
    final parts = sanitized.split('.');
    return parts
        .map((part) => int.tryParse(part) ?? 0)
        .where((value) => value >= 0)
        .toList();
  }
}
