import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insign/core/theme/app_theme.dart';

void main() {
  test('AppTheme.lightTheme returns ThemeData', () {
    final theme = AppTheme.lightTheme;
    expect(theme, isA<ThemeData>());
    expect(theme.fontFamily, 'Bariol');
  });
}

