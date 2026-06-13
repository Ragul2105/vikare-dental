import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/cache/hive_cache.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveCache.init();
  runApp(const ProviderScope(child: DentalClinicApp()));
}
