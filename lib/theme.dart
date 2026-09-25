import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// كل ألوان التطبيق هنا. غيّري أي لون وهيتغير في كل الشاشات.
class AppColors {
  // الأرضية والكروت: بني دافي
  static const bg = Color(0xFF221C19);
  static const surface = Color(0xFF2E2622);
  static const track = Color(0xFF4A3E37);

  // النصوص
  static const cream = Color(0xFFF2E9D8);
  static const muted = Color(0xFFB5A99C);

  // لوحة الألوان
  static const mustard = Color(0xFFD4A72C);
  static const tealLight = Color(0xFF6FB3B0);
  static const terracotta = Color(0xFFE07A47);
  static const slateLight = Color(0xFF8FA9C4);
  static const sage = Color(0xFF8FA68F);
  static const rose = Color(0xFFC47C8A);

  /// كل تحدي بياخد لون من هنا بالترتيب
  static const challengeColors = [
    mustard,
    tealLight,
    terracotta,
    slateLight,
    sage,
    rose,
  ];
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.mustard,
    brightness: Brightness.dark,
  ).copyWith(
    primary: AppColors.mustard,
    onPrimary: AppColors.bg,
    secondary: AppColors.tealLight,
    surface: AppColors.surface,
    onSurface: AppColors.cream,
  );

  final base = ThemeData(
    brightness: Brightness.dark,
    colorScheme: scheme,
    useMaterial3: true,
  );

  // IBM Plex Sans Arabic لكل الواجهة (نصوص وعناوين وأزرار وخانات)
  final body = GoogleFonts.ibmPlexSansArabicTextTheme(base.textTheme).apply(
    bodyColor: AppColors.cream,
    displayColor: AppColors.cream,
  );

  final textTheme = body.copyWith(
    headlineMedium: GoogleFonts.ibmPlexSansArabic(
      textStyle: body.headlineMedium,
      fontWeight: FontWeight.w600,
    ),
    titleLarge: GoogleFonts.ibmPlexSansArabic(
      textStyle: body.titleLarge,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: GoogleFonts.ibmPlexSansArabic(
      textStyle: body.titleMedium,
      fontWeight: FontWeight.w700,
    ),
  );

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.ibmPlexSansArabic(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: AppColors.cream,
      ),
      iconTheme: const IconThemeData(color: AppColors.cream),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.terracotta,
      foregroundColor: AppColors.bg,
      extendedTextStyle: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w700),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.mustard,
        foregroundColor: AppColors.bg,
        textStyle: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.cream,
        side: BorderSide(color: AppColors.cream.withValues(alpha: 0.35)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
  );
}

/// خط الاقتباسات (Amiri). بيتستخدم للاقتباسات بس، وبحجم كبير عشان يبان واضح.
TextStyle quoteTextStyle({double size = 24, Color color = AppColors.cream}) {
  return GoogleFonts.amiri(fontSize: size, height: 1.9, color: color);
}
