import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../models/user_model.dart';

/// Custom application theme for FamilyGuard
class AppTheme {
  // Brand Colors
  static const Color primaryColor = Color(0xFF2E7CE4); // Professional blue
  static const Color primaryVariant = Color(0xFF1E5BA8);
  static const Color secondaryColor = Color(0xFF4CAF50); // Success green
  static const Color errorColor = Color(0xFFE53E3E);
  static const Color warningColor = Color(0xFFFF9800);
  static const Color surfaceColor = Color(0xFFFAFAFA);
  
  // Parent Theme Colors
  static const Color parentPrimary = Color(0xFF2E7CE4);
  static const Color parentAccent = Color(0xFF1E5BA8);
  static const Color parentBackground = Color(0xFFF8FAFC);
  
  // Child Theme Colors
  static const Color childPrimary = Color(0xFF4CAF50);
  static const Color childAccent = Color(0xFF388E3C);
  static const Color childBackground = Color(0xFFF1F8E9);
  
  // Text Colors
  static const Color textPrimary = Color(0xFF1A202C);
  static const Color textSecondary = Color(0xFF718096);
  static const Color textDisabled = Color(0xFFA0AEC0);
  
  // Background Colors
  static const Color backgroundLight = Color(0xFFFFFFFF);
  static const Color backgroundDark = Color(0xFF1A202C);
  static const Color cardBackground = Color(0xFFFFFFFF);
  
  /// Light theme configuration
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      
      // Color Scheme
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
        primary: primaryColor,
        secondary: secondaryColor,
        error: errorColor,
        surface: surfaceColor,
      ),
      
      // App Bar Theme
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: backgroundLight,
        foregroundColor: textPrimary,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
      
      // Card Theme
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        ),
        color: cardBackground,
        surfaceTintColor: Colors.transparent,
      ),
      
      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, AppConstants.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      // Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          minimumSize: const Size(double.infinity, AppConstants.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          ),
          side: const BorderSide(color: primaryColor, width: 1.5),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          borderSide: const BorderSide(color: errorColor, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingMD,
          vertical: AppConstants.spacingMD,
        ),
      ),
      
      // Text Theme
      textTheme: const TextTheme(
        // Display styles
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          height: 1.2,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          height: 1.2,
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          height: 1.3,
        ),
        
        // Headline styles
        headlineLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          height: 1.3,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          height: 1.3,
        ),
        headlineSmall: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          height: 1.4,
        ),
        
        // Title styles
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          height: 1.4,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textPrimary,
          height: 1.4,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textPrimary,
          height: 1.4,
        ),
        
        // Body styles
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: textPrimary,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textPrimary,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: textSecondary,
          height: 1.4,
        ),
        
        // Label styles
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textPrimary,
          height: 1.4,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textSecondary,
          height: 1.4,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: textDisabled,
          height: 1.4,
        ),
      ),
    );
  }
  
  /// Dark theme configuration
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      
      // Color Scheme
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.dark,
        primary: primaryColor,
        secondary: secondaryColor,
        error: errorColor,
        surface: const Color(0xFF2D3748),
      ),
      
      // Dark theme specific configurations
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: backgroundDark,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
    );
  }
  
  /// Get theme based on user role
  static ThemeData getThemeForRole(UserRole? role, {bool isDark = false}) {
    if (isDark) return darkTheme;
    
    switch (role) {
      case UserRole.parent:
        return lightTheme.copyWith(
          colorScheme: lightTheme.colorScheme.copyWith(
            primary: parentPrimary,
            secondary: parentAccent,
          ),
        );
      case UserRole.child:
        return lightTheme.copyWith(
          colorScheme: lightTheme.colorScheme.copyWith(
            primary: childPrimary,
            secondary: childAccent,
          ),
        );
      default:
        return lightTheme;
    }
  }
}