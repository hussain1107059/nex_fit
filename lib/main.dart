import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common/sqflite.dart' show databaseFactory;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'app.dart';
import 'injection/dependency_injection.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // sqflite has no web implementation; sqflite_common_ffi_web provides the
  // IndexedDB-backed engine used on browsers. The no-web-worker variant runs
  // sqlite directly in the UI thread and only requires web/sqlite3.wasm.
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWebNoWebWorker;
  }

  final SharedPreferences preferences = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: <Override>[
        sharedPreferencesProvider.overrideWithValue(preferences),
      ],
      child: const NexFitApp(),
    ),
  );
}
