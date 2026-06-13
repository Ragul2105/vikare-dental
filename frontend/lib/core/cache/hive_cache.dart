import 'package:hive_flutter/hive_flutter.dart';

class HiveCache {
  HiveCache._();

  static late Box<String> _box;

  static Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox<String>('dental_cache');
  }

  static Future<void> putString(String key, String value) =>
      _box.put(key, value);

  static String? getString(String key) => _box.get(key);

  static Future<void> remove(String key) => _box.delete(key);
}
