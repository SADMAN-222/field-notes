import 'package:flutter/material.dart';

class AppColors {
  // Brand Primary & Secondary
  static const Color primary = Color(0xFF0F766E); // Teal 700
  static const Color primaryLight = Color(0xFF14B8A6); // Teal 500
  static const Color primaryDark = Color(0xFF115E59); // Teal 800
  static const Color secondary = Color(0xFF0284C7); // Sky 600

  // Background & Surfaces
  static const Color background = Color(0xFFF8FAFC); // Slate 50
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSubtle = Color(0xFFF1F5F9); // Slate 100
  static const Color surfaceElevated = Color(0xFFFFFFFF);

  // Borders & Dividers
  static const Color border = Color(0xFFE2E8F0); // Slate 200
  static const Color borderSubtle = Color(0xFFF1F5F9); // Slate 100
  static const Color borderStrong = Color(0xFFCBD5E1); // Slate 300

  // Text Colors
  static const Color textPrimary = Color(0xFF0F172A); // Slate 900
  static const Color textSecondary = Color(0xFF475569); // Slate 600
  static const Color textMuted = Color(0xFF94A3B8); // Slate 400

  // Status & Badges
  static const Color statusDraft = Color(0xFF64748B); // Slate 500
  static const Color statusDraftBg = Color(0xFFF1F5F9);
  
  static const Color statusInProgress = Color(0xFFD97706); // Amber 600
  static const Color statusInProgressBg = Color(0xFFFEF3C7); // Amber 100
  
  static const Color statusCompleted = Color(0xFF059669); // Emerald 600
  static const Color statusCompletedBg = Color(0xFFD1FAE5); // Emerald 100
  
  static const Color statusFlagged = Color(0xFFE11D48); // Rose 600
  static const Color statusFlaggedBg = Color(0xFFFFE4E6); // Rose 100

  // Sync Status
  static const Color syncPending = Color(0xFFEAB308); // Yellow 500
  static const Color syncWarning = Color(0xFFF59E0B); // Amber 500
  static const Color syncSuccess = Color(0xFF10B981); // Emerald 500
  static const Color syncSynced = Color(0xFF10B981); // Emerald 500
  static const Color syncError = Color(0xFFEF4444); // Red 500

  // Card Shadow
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get elevatedShadow => [
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.08),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];
}
