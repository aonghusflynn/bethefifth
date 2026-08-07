// BeTheFifth — App Theme
// Ports the brand tokens (Pitch Lime, Match Night, Chalk Line) to Flutter's
// Material 3 ThemeData. Uses Space Grotesk (display), Inter (body), and
// JetBrains Mono (timestamps / score values).
//
// Usage:
//   MaterialApp(
//     theme: BtfTheme.light(),
//     darkTheme: BtfTheme.dark(),
//     themeMode: ThemeMode.system,
//   );

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Brand color tokens. Keep these in one place — mirror CSS custom properties.
class BtfColors {
  BtfColors._();

  // Core
  static const ink      = Color(0xFF0B0D0C); // Match Night
  static const ink2     = Color(0xFF16191A);
  static const paper    = Color(0xFFF6F5F1); // Chalk Line
  static const paper2   = Color(0xFFECEAE2);
  static const chalk    = Color(0xFFD9D6C8);
  static const muted    = Color(0xFF6E7370);

  // Accent
  static const lime     = Color(0xFFD5F24A); // Pitch Lime · oklch(0.88 0.22 125)
  static const limeDeep = Color(0xFFBFD93A);

  // Secondary signals
  static const coral    = Color(0xFFE66849); // Stoppage · alerts
  static const flood    = Color(0xFF4A9EE0); // Floodlight · links / night

  // Status semantics
  static const success  = lime;
  static const warning  = Color(0xFFE8B84A);
  static const danger   = coral;
}

/// Radius + spacing scale.
class BtfRadius {
  BtfRadius._();
  static const xs = 6.0;
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 20.0;
  static const xl = 28.0;
  static const pill = 100.0;
}

class BtfSpace {
  BtfSpace._();
  static const x1 = 4.0;
  static const x2 = 8.0;
  static const x3 = 12.0;
  static const x4 = 16.0;
  static const x5 = 24.0;
  static const x6 = 32.0;
  static const x7 = 48.0;
  static const x8 = 64.0;
}

/// Typography — Space Grotesk (display), Inter (body), JetBrains Mono (data).
class BtfText {
  BtfText._();

  static TextTheme _base(Color ink) {
    final display = GoogleFonts.spaceGroteskTextTheme();
    final body    = GoogleFonts.interTextTheme();

    return TextTheme(
      // Display — headlines, hero. Tight tracking, heavy weight.
      displayLarge: display.displayLarge?.copyWith(
        fontSize: 96, fontWeight: FontWeight.w700, letterSpacing: -4.0,
        height: 0.9, color: ink,
      ),
      displayMedium: display.displayMedium?.copyWith(
        fontSize: 64, fontWeight: FontWeight.w700, letterSpacing: -2.5,
        height: 0.95, color: ink,
      ),
      displaySmall: display.displaySmall?.copyWith(
        fontSize: 48, fontWeight: FontWeight.w700, letterSpacing: -1.8,
        height: 1.0, color: ink,
      ),

      // Headline — screen titles.
      headlineLarge: display.headlineLarge?.copyWith(
        fontSize: 36, fontWeight: FontWeight.w700, letterSpacing: -1.0,
        height: 1.05, color: ink,
      ),
      headlineMedium: display.headlineMedium?.copyWith(
        fontSize: 28, fontWeight: FontWeight.w600, letterSpacing: -0.6,
        height: 1.1, color: ink,
      ),
      headlineSmall: display.headlineSmall?.copyWith(
        fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.3,
        height: 1.15, color: ink,
      ),

      // Title — card titles, section leads.
      titleLarge: display.titleLarge?.copyWith(
        fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.2,
        height: 1.2, color: ink,
      ),
      titleMedium: body.titleMedium?.copyWith(
        fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0,
        height: 1.3, color: ink,
      ),
      titleSmall: body.titleSmall?.copyWith(
        fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1,
        height: 1.3, color: ink,
      ),

      // Body — long-form copy.
      bodyLarge: body.bodyLarge?.copyWith(
        fontSize: 17, fontWeight: FontWeight.w400, letterSpacing: 0,
        height: 1.45, color: ink,
      ),
      bodyMedium: body.bodyMedium?.copyWith(
        fontSize: 15, fontWeight: FontWeight.w400, letterSpacing: 0,
        height: 1.5, color: ink,
      ),
      bodySmall: body.bodySmall?.copyWith(
        fontSize: 13, fontWeight: FontWeight.w400, letterSpacing: 0,
        height: 1.5, color: ink.withOpacity(0.75),
      ),

      // Label — UI chrome, buttons, tabs.
      labelLarge: body.labelLarge?.copyWith(
        fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0,
        color: ink,
      ),
      labelMedium: body.labelMedium?.copyWith(
        fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: 0.2,
        color: ink,
      ),
      labelSmall: body.labelSmall?.copyWith(
        fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.3,
        color: ink,
      ),
    );
  }

  /// Monospace style for timestamps, scorelines, IDs.
  /// Use: Text('19:30 · 4/5 · €0', style: BtfText.mono())
  static TextStyle mono({double size = 12, Color? color, double letterSpacing = 1.4}) {
    return GoogleFonts.jetBrainsMono(
      fontSize: size,
      fontWeight: FontWeight.w500,
      letterSpacing: letterSpacing,
      color: color ?? BtfColors.muted,
      height: 1.3,
    );
  }

  static TextTheme light() => _base(BtfColors.ink);
  static TextTheme dark()  => _base(BtfColors.paper);
}

/// Theme factory.
class BtfTheme {
  BtfTheme._();

  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);

    final colorScheme = const ColorScheme.light(
      brightness: Brightness.light,
      primary:          BtfColors.ink,
      onPrimary:        BtfColors.paper,
      primaryContainer: BtfColors.lime,
      onPrimaryContainer: BtfColors.ink,
      secondary:        BtfColors.lime,
      onSecondary:      BtfColors.ink,
      secondaryContainer: BtfColors.paper2,
      onSecondaryContainer: BtfColors.ink,
      tertiary:         BtfColors.coral,
      onTertiary:       BtfColors.paper,
      error:            BtfColors.coral,
      onError:          BtfColors.paper,
      surface:          BtfColors.paper,
      onSurface:        BtfColors.ink,
      surfaceContainerHighest: BtfColors.paper2,
      outline:          BtfColors.chalk,
      outlineVariant:   BtfColors.paper2,
    );

    return base.copyWith(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: BtfColors.paper,
      textTheme: BtfText.light(),

      // Top-level chrome
      appBarTheme: AppBarTheme(
        backgroundColor: BtfColors.paper,
        foregroundColor: BtfColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.spaceGrotesk(
          fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.4,
          color: BtfColors.ink,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),

      // Cards
      cardTheme: CardThemeData(
        color: BtfColors.paper,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BtfRadius.md),
          side: BorderSide(color: BtfColors.ink.withOpacity(0.08)),
        ),
      ),

      // Primary filled button — ink pill with lime dot.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: BtfColors.ink,
          foregroundColor: BtfColors.paper,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.spaceGrotesk(
            fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.2,
          ),
        ),
      ),

      // Secondary outlined button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: BtfColors.ink,
          side: const BorderSide(color: BtfColors.ink, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.spaceGrotesk(
            fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: -0.1,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: BtfColors.ink,
          textStyle: GoogleFonts.spaceGrotesk(
            fontSize: 15, fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Input fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: BtfColors.paper2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BtfRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BtfRadius.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BtfRadius.md),
          borderSide: const BorderSide(color: BtfColors.ink, width: 2),
        ),
        hintStyle: GoogleFonts.inter(color: BtfColors.muted, fontSize: 15),
        labelStyle: GoogleFonts.inter(color: BtfColors.muted, fontSize: 13),
      ),

      // Chips (filter pills: Tonight / Tomorrow / This week)
      chipTheme: ChipThemeData(
        backgroundColor: Colors.transparent,
        selectedColor: BtfColors.ink,
        side: BorderSide(color: BtfColors.ink.withOpacity(0.15)),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        labelStyle: GoogleFonts.jetBrainsMono(
          fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 1.2,
          color: BtfColors.ink,
        ),
        secondaryLabelStyle: GoogleFonts.jetBrainsMono(
          fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 1.2,
          color: BtfColors.paper,
        ),
      ),

      // Dividers
      dividerTheme: DividerThemeData(
        color: BtfColors.ink.withOpacity(0.08),
        thickness: 1,
        space: 1,
      ),

      // Bottom nav
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: BtfColors.paper,
        selectedItemColor: BtfColors.ink,
        unselectedItemColor: BtfColors.muted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        showUnselectedLabels: true,
      ),

      // FAB — primary CTA floating
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: BtfColors.ink,
        foregroundColor: BtfColors.lime,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BtfRadius.lg),
        ),
        extendedTextStyle: GoogleFonts.spaceGrotesk(
          fontSize: 16, fontWeight: FontWeight.w600,
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: BtfColors.ink,
        contentTextStyle: GoogleFonts.inter(color: BtfColors.paper, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BtfRadius.sm)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);

    final colorScheme = const ColorScheme.dark(
      brightness: Brightness.dark,
      primary:          BtfColors.lime,
      onPrimary:        BtfColors.ink,
      primaryContainer: BtfColors.ink2,
      onPrimaryContainer: BtfColors.lime,
      secondary:        BtfColors.lime,
      onSecondary:      BtfColors.ink,
      tertiary:         BtfColors.coral,
      onTertiary:       BtfColors.paper,
      error:            BtfColors.coral,
      onError:          BtfColors.paper,
      surface:          BtfColors.ink,
      onSurface:        BtfColors.paper,
      surfaceContainerHighest: BtfColors.ink2,
      outline:          Color(0xFF3D4240),
      outlineVariant:   BtfColors.ink2,
    );

    return base.copyWith(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: BtfColors.ink,
      textTheme: BtfText.dark(),
      appBarTheme: AppBarTheme(
        backgroundColor: BtfColors.ink,
        foregroundColor: BtfColors.paper,
        elevation: 0,
        titleTextStyle: GoogleFonts.spaceGrotesk(
          fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.4,
          color: BtfColors.paper,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: BtfColors.lime,
          foregroundColor: BtfColors.ink,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.spaceGrotesk(
            fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.2,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: BtfColors.lime,
        foregroundColor: BtfColors.ink,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BtfRadius.lg),
        ),
      ),
    );
  }
}
