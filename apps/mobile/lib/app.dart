import 'package:flutter/material.dart';

import 'core/theme/nyla_theme.dart';
import 'navigation/router.dart';

class NylaApp extends StatelessWidget {
  const NylaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Nyla',
      debugShowCheckedModeBanner: false,
      theme: NylaTheme.light,
      routerConfig: nylaRouter,
    );
  }
}
