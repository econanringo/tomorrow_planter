import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';
import 'theme.dart';

class TomorrowPlanterApp extends ConsumerWidget {
  const TomorrowPlanterApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final materialTheme = MaterialTheme(ThemeData.light().textTheme);

    return MaterialApp.router(
      title: 'Tomorrow Planter',
      debugShowCheckedModeBanner: false,
      theme: materialTheme.light(),
      darkTheme: materialTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
