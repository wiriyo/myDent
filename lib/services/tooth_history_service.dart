import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ToothHistoryService {
  static const String _prefsKey = 'tooth_history_entries';
  static const int _maxEntries = 50;

  Future<List<String>> loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getStringList(_prefsKey);
      if (history == null) {
        return const <String>[];
      }
      return history.where((entry) => entry.trim().isNotEmpty).toList();
    } catch (error) {
      debugPrint('ToothHistoryService loadHistory error: $error');
      return const <String>[];
    }
  }

  Future<void> addEntries(Iterable<String> entries) async {
    final cleanedEntries =
        entries
            .map((entry) => entry.trim())
            .where((entry) => entry.isNotEmpty)
            .toList();

    if (cleanedEntries.isEmpty) {
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getStringList(_prefsKey) ?? <String>[];

      final List<String> updated = <String>[];
      final Set<String> seen = <String>{};

      void addValue(String value) {
        final trimmed = value.trim();
        if (trimmed.isEmpty) return;
        final normalized = trimmed.toLowerCase();
        if (seen.add(normalized)) {
          updated.add(trimmed);
        }
      }

      for (final entry in cleanedEntries) {
        addValue(entry);
      }

      for (final value in existing) {
        addValue(value);
      }

      if (updated.length > _maxEntries) {
        updated.removeRange(_maxEntries, updated.length);
      }

      await prefs.setStringList(_prefsKey, updated);
    } catch (error) {
      debugPrint('ToothHistoryService addEntries error: $error');
    }
  }
}
