import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'data/database_init.dart';
import 'data/supabase_config.dart';
import 'providers/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initializeDatabaseFactory();
  if (hasSupabaseConfig) {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(
    overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    child: const PowerliftingApp(),
  ));
}
