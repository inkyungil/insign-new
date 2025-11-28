import 'package:flutter_test/flutter_test.dart';
import 'package:insign/core/utils/version_utils.dart';

void main() {
  group('VersionUtils.compareSemanticVersions', () {
    test('returns -1 when first version is smaller', () {
      expect(VersionUtils.compareSemanticVersions('1.0.0', '1.0.1'), equals(-1));
    });

    test('returns 1 when first version is greater', () {
      expect(VersionUtils.compareSemanticVersions('2.1.0', '2.0.9'), equals(1));
    });

    test('ignores build metadata and pre-release tags', () {
      expect(
        VersionUtils.compareSemanticVersions('1.2.3+15', '1.2.3'),
        equals(0),
      );
      expect(
        VersionUtils.compareSemanticVersions('1.2.3-hotfix', '1.2.4'),
        equals(-1),
      );
    });
  });
}
