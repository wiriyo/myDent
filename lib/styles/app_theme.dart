// v1.2.0 - ✨ Added More Centralized Icon Paths
// 📁 lib/styles/app_theme.dart

import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // --- 🎨 สีพื้นฐานของแอป (Primary Palette) 🎨 ---
  static const Color primary = Color(0xFF9C27B0); 
  static const Color primaryLight = Color(0xFFE0BBFF); 
  static const Color background = Color(0xFFEFE0FF); 
  static const Color bottomNav = Color(0xFFFBEAFF); 
  
  // --- 🎨 สีสำหรับข้อความ (Text Colors) 🎨 ---
  static const Color textPrimary = Colors.black87;
  static const Color textSecondary = Colors.black54;
  static const Color textDisabled = Colors.grey;

  // --- 🎨 สีของการ์ดคนไข้ตาม Rating 🎨 ---
  static const Color rating5Star = Color(0xFFD0F8CE);
  static const Color rating4Star = Color(0xFFFFF9C4);
  static const Color rating3StarAndBelow = Color(0xFFFFCDD2);

  static const Color rating5StarBorder = Color(0xFFA5D6A7);
  static const Color rating4StarBorder = Color(0xFFFFF176);
  static const Color rating3StarAndBelowBorder = Color(0xFFEF9A9A);

  // --- 🎨 สีของปุ่ม Action 🎨 ---
  static const Color buttonCallBg = Color(0xFFE8F5E9); 
  static const Color buttonCallFg = Color(0xFF1B5E20); 
  
  static const Color buttonEditBg = Color(0xFFFFF3E0); 
  static const Color buttonEditFg = Color(0xFFE65100); 

  static const Color buttonDeleteBg = Color(0xFFFFEBEE); 
  static const Color buttonDeleteFg = Color(0xFFB71C1C); 

  // --- 🎨 สีของไอคอน 🎨 ---
  static const Color iconMaleColor = Color(0xFF64B5F6);
  static const Color iconFemaleColor = Color(0xFFF06292);
  static const Color ratingInflamedTooth = Color(0xFFFFB6C1); // LightPink
  //static const Color iconDefaultColor = Colors.black54;

  // --- 🖋️ ฟอนต์ของแอป 🖋️ ---
  static const String fontFamily = 'Poppins';

  // --- ✨ [UPDATE v1.2.0] ที่อยู่ของไอคอนที่เราจะใช้ร่วมกันทั้งแอปค่ะ ✨ ---
  static const String iconPathUser = 'assets/icons/user.png';
  static const String iconPathAge = 'assets/icons/age.png';
  static const String iconPathPhone = 'assets/icons/mobile_phone.png';
  static const String iconPathCall = 'assets/icons/phone.png';
  static const String iconPathAddress = 'assets/icons/house.png';
  static const String iconPathMale = 'assets/icons/male.png';
  static const String iconPathFemale = 'assets/icons/female.png';
  static const String iconPathGender = 'assets/icons/gender.png';
  static const String iconPathEdit = 'assets/icons/edit.png';
  static const String iconPathDelete = 'assets/icons/delete.png';
  static const String iconPathTreatment = 'assets/icons/report.png';
  static const String iconPathTooth = 'assets/icons/tooth.png';
  static const String iconPathMoney = 'assets/icons/money.png';
  static const String iconPathCalendar = 'assets/icons/calendar.png';
  static const String iconPathXRay = 'assets/icons/x_ray.png';
  static const String iconPathHn = 'assets/icons/hn_id.png';
  static const String iconPathNotes = 'assets/icons/note.png';
  static const String iconPathClock = 'assets/icons/clock.png';
  static const String iconPathReceipt = 'assets/icons/id_card.png';







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
      bottomAppBarTheme: const BottomAppBarThemeData(
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
