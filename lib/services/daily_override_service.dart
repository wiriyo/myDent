import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/working_hours_model.dart';

class DailyOverrideService {
  static const String _prefsKeyPrefix = 'daily_working_overrides';

  String _buildPrefsKey(String? clinicId) {
    final id = (clinicId == null || clinicId.isEmpty) ? 'default' : clinicId;
    return '${_prefsKeyPrefix}_$id';
  }

  String _dateKey(DateTime day) {
    final y = day.year.toString().padLeft(4, '0');
    final m = day.month.toString().padLeft(2, '0');
    final d = day.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<Map<DateTime, DayWorkingHours>> loadOverrides({String? clinicId}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_buildPrefsKey(clinicId));
    if (raw == null || raw.isEmpty) {
      return {};
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return {};
    }

    final result = <DateTime, DayWorkingHours>{};
    decoded.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        final parts = key.split('-');
        if (parts.length == 3) {
          final year = int.tryParse(parts[0]);
          final month = int.tryParse(parts[1]);
          final day = int.tryParse(parts[2]);
          if (year != null && month != null && day != null) {
            result[DateTime(year, month, day)] =
                DayWorkingHours.fromJson(value);
          }
        }
      }
    });
    return result;
  }

  Future<void> saveOverride(
    DateTime day,
    DayWorkingHours override, {
    String? clinicId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _buildPrefsKey(clinicId);
    final raw = prefs.getString(key);
    final Map<String, dynamic> data =
        raw != null && raw.isNotEmpty ? jsonDecode(raw) as Map<String, dynamic> : {};
    data[_dateKey(day)] = override.toJson();
    await prefs.setString(key, jsonEncode(data));
  }

  Future<void> removeOverride(DateTime day, {String? clinicId}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _buildPrefsKey(clinicId);
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) {
      return;
    }
    final data = jsonDecode(raw);
    if (data is! Map<String, dynamic>) {
      return;
    }
    data.remove(_dateKey(day));
    await prefs.setString(key, jsonEncode(data));
  }
}
