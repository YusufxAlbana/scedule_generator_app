import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Service untuk menyimpan dan memuat tasks dari local storage.
/// Data disimpan sebagai JSON string via SharedPreferences.
class TaskStorageService {
  static const String _key = 'saved_tasks';

  /// Simpan semua tasks ke local storage
  static Future<void> saveTasks(List<Map<String, dynamic>> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(tasks);
    await prefs.setString(_key, jsonString);
  }

  /// Muat tasks dari local storage
  /// Mengembalikan list kosong jika belum ada data
  static Future<List<Map<String, dynamic>>> loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);
    if (jsonString == null || jsonString.isEmpty) return [];

    try {
      final List<dynamic> decoded = jsonDecode(jsonString);
      return decoded.map((item) => Map<String, dynamic>.from(item)).toList();
    } catch (e) {
      // Jika data corrupt, kembalikan list kosong
      return [];
    }
  }

  /// Hapus semua tasks dari local storage
  static Future<void> clearTasks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
