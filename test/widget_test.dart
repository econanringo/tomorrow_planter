import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:tomorrow_planter/theme.dart';

void main() {
  testWidgets('MaterialTheme builds light ThemeData with Material 3',
      (tester) async {
    final theme = MaterialTheme(ThemeData.light().textTheme).light();
    expect(theme.useMaterial3, isTrue);
    expect(theme.colorScheme.primary, const Color(0xff136b55));

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const Scaffold(body: Text('Tomorrow Planter')),
      ),
    );
    expect(find.text('Tomorrow Planter'), findsOneWidget);
  });
}
