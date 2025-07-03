// 📁 lib/styles/app_theme.dart

import 'package:flutter/material.dart';

class AppTheme {
  // ทำให้คลาสนี้เป็น singleton คือมี instance เดียวเสมอ
  AppTheme._();

  // --- 🎨 สีพื้นฐานของแอป (Primary Palette) 🎨 ---
  static const Color primary = Color(0xFF9C27B0); // สีม่วงหลัก
  // ✨ [FIX] เปลี่ยนสี AppBar กลับเป็นสีเดิมค่ะ
  static const Color primaryLight = Color(0xFFE0BBFF); 
  // ✨ [FIX] เปลี่ยนสีพื้นหลังกลับเป็นสีเดิมค่ะ
  static const Color background = Color(0xFFEFE0FF); 
  static const Color bottomNav = Color(0xFFFBEAFF); // สี Bottom Nav Bar
  
  // --- 🎨 สีสำหรับข้อความ (Text Colors) 🎨 ---
  static const Color textPrimary = Colors.black87;
  static const Color textSecondary = Colors.black54;
  static const Color textDisabled = Colors.grey;

  // --- 🎨 สีของการ์ดคนไข้ตาม Rating 🎨 ---
  static const Color rating5Star = Color(0xFFD0F8CE); // เขียวอ่อน
  static const Color rating4Star = Color(0xFFFFF9C4); // เหลืองอ่อน
  static const Color rating3StarAndBelow = Color(0xFFFFCDD2); // ชมพูอ่อน

  // --- 🎨 สีของปุ่ม Action 🎨 ---
  static const Color buttonCallBg = Color(0xFFE8F5E9); // เขียวอ่อน
  static const Color buttonCallFg = Color(0xFF1B5E20); // เขียวเข้ม
  
  static const Color buttonEditBg = Color(0xFFFFF3E0); // ส้มอ่อน
  static const Color buttonEditFg = Color(0xFFE65100); // ส้มเข้ม

  static const Color buttonDeleteBg = Color(0xFFFFEBEE); // แดงอ่อน
  static const Color buttonDeleteFg = Color(0xFFB71C1C); // แดงเข้ม

  // --- 🎨 สีของไอคอน 🎨 ---
  static const Color iconMale = Color(0xFF64B5F6); // ฟ้า
  static const Color iconFemale = Color(0xFFF06292); // ชมพู
  static const Color iconDefault = Colors.black54;

  // --- 🖋️ ฟอนต์ของแอป 🖋️ ---
  static const String fontFamily = 'Poppins';

  // --- ✨ สร้าง ThemeData ของเราเลยค่ะ! ✨ ---
  static ThemeData get themeData {
    return ThemeData(
      primaryColor: primary,
      scaffoldBackgroundColor: background,
      fontFamily: fontFamily,
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryLight,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 20,
          fontFamily: fontFamily,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      bottomAppBarTheme: const BottomAppBarTheme(
        color: bottomNav,
        shape: CircularNotchedRectangle(),
        elevation: 8.0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            fontFamily: fontFamily,
          ),
        ),
      ),
    );
  }
}
