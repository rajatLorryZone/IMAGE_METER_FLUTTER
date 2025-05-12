import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/settings_model.dart';

class SettingsService {
  static const String _settingsBoxName = 'settings';
  static const String _settingsKey = 'app_settings';
  
  // Get settings from local storage
  Future<AppSettings> getSettings() async {
    final box = await Hive.openBox(_settingsBoxName);
    final settings = box.get(_settingsKey);
    
    if (settings == null) {
      // Return default settings if none exist
      return const AppSettings();
    }
    
    return settings;
  }
  
  // Save settings to local storage
  Future<void> saveSettings(AppSettings settings) async {
    final box = await Hive.openBox(_settingsBoxName);
    await box.put(_settingsKey, settings);
  }
  
  // Get a specific setting value using SharedPreferences for simple settings
  Future<T?> getSetting<T>(String key, T defaultValue) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (T == String) {
      return prefs.getString(key) as T? ?? defaultValue;
    } else if (T == int) {
      return prefs.getInt(key) as T? ?? defaultValue;
    } else if (T == bool) {
      return prefs.getBool(key) as T? ?? defaultValue;
    } else if (T == double) {
      return prefs.getDouble(key) as T? ?? defaultValue;
    }
    
    return defaultValue;
  }
  
  // Save a specific setting value using SharedPreferences for simple settings
  Future<void> saveSetting<T>(String key, T value) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (T == String) {
      await prefs.setString(key, value as String);
    } else if (T == int) {
      await prefs.setInt(key, value as int);
    } else if (T == bool) {
      await prefs.setBool(key, value as bool);
    } else if (T == double) {
      await prefs.setDouble(key, value as double);
    }
  }
}
