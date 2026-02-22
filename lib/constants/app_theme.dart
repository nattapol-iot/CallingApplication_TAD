import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const primaryRed = Color(0xFFE30613); // แดง Asahi
  static const bgGrey = Color(0xFFF9FAFB);
  static const textDark = Color(0xFF1F2937);
  static const textGrey = Color(0xFF6B7280);

  static Color statusColor(int status) {
    switch (status) {
      case 1:
        return primaryRed; // CALLING
      case 3:
        return const Color(0xFFF59E0B); // WORKING (Amber)
      case 4:
        return const Color(0xFF10B981); // COMPLETED (Emerald)
      case 9:
        return const Color(0xFF64748B); // CLOSED (Slate)
      default:
        return Colors.indigo;
    }
  }

  static ThemeData get themeData {
    // ใช้ Google Fonts
    final baseTextTheme = GoogleFonts.kanitTextTheme();

    return ThemeData(
      useMaterial3: true,
      colorSchemeSeed: primaryRed,
      scaffoldBackgroundColor: bgGrey,
      textTheme: baseTextTheme.apply(
        bodyColor: textDark,
        displayColor: textDark,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: textDark,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.kanit(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textDark,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryRed, width: 2),
        ),
        labelStyle: const TextStyle(color: textGrey),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryRed,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.kanit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      // [แก้ไขจุดสำคัญ]
      // 1. เปลี่ยน CardTheme เป็น CardThemeData (ตามที่ Error แนะนำ)
      // 2. ลบ const ออก เพราะ .withValues() ไม่ใช่ค่าคงที่
      // 3. เปลี่ยน .withOpacity เป็น .withValues(alpha: ...)
      cardTheme: CardThemeData(
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.05), // แก้ไขตรงนี้
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade100),
        ),
        color: Colors.white,
      ),
    );
  }
}
