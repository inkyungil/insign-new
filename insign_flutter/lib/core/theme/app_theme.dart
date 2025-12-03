// lib/core/theme/app_theme.dart

import 'package:flutter/material.dart';
import 'package:insign/core/constants.dart'; // Using the new constants file

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: false, // devkit uses M2
      fontFamily: 'Bariol',
      primaryColor: primaryColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: IconThemeData(
          color: Colors.black,
        ),
        titleTextStyle: TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontFamily: 'Bariol',
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}