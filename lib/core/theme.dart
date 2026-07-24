import 'package:flutter/material.dart';

/// Central palette and text styles for the Nova Token Drop UI.
class NovaColors {
  static const Color deepSpace = Color(0xFF060818);
  static const Color panelDark = Color(0xFF0E1330);
  static const Color panelGlass = Color(0x33121A45);
  static const Color stroke = Color(0xFF2B3A78);

  static const Color cyan = Color(0xFF35E7FF);
  static const Color blue = Color(0xFF3D7BFF);
  static const Color violet = Color(0xFF9B5BFF);
  static const Color magenta = Color(0xFFFF4FD8);
  static const Color pink = Color(0xFFFF5C8A);
  static const Color gold = Color(0xFFFFC24B);
  static const Color green = Color(0xFF56F09B);
  static const Color red = Color(0xFFFF5B57);

  static const Color textHi = Color(0xFFEAF2FF);
  static const Color textLo = Color(0xFF9AA9D8);

  static const List<Color> heroGradient = [cyan, blue, violet];
  static const List<Color> goldGradient = [Color(0xFFFFE39A), gold, Color(0xFFFF8A3D)];
}

class NovaText {
  static const String display = 'Orbitron';
  static const String body = 'Exo2';

  static TextStyle title(double size, {Color color = NovaColors.textHi, double spacing = 1.5}) =>
      TextStyle(
        fontFamily: display,
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: color,
        letterSpacing: spacing,
        height: 1.05,
      );

  static TextStyle label(double size, {Color color = NovaColors.textHi, FontWeight w = FontWeight.w600}) =>
      TextStyle(
        fontFamily: body,
        fontSize: size,
        fontWeight: w,
        color: color,
        letterSpacing: 0.3,
      );
}

class NovaTheme {
  static ThemeData build() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: NovaColors.deepSpace,
      fontFamily: NovaText.body,
      colorScheme: const ColorScheme.dark(
        primary: NovaColors.cyan,
        secondary: NovaColors.violet,
        surface: NovaColors.panelDark,
      ),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
    );
  }
}
