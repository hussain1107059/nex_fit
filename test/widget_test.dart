import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:nexfit/app.dart';
import 'package:nexfit/injection/dependency_injection.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('NexFit app boots to the splash screen', (
    WidgetTester tester,
  ) async {
    final SharedPreferences preferences =
        await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: const NexFitApp(),
      ),
    );

    await tester.pump();

    expect(find.text('NexFit'), findsOneWidget);
    expect(find.byType(Scaffold), findsWidgets);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 1));
  });
}
