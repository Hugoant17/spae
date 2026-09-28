import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/navigation/app_router.dart';
import 'core/theme/app_theme.dart';

class SpaeApp extends StatelessWidget {
  const SpaeApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        locale: const Locale('es', 'PE'),
        supportedLocales: const [Locale('es', 'PE')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        title: 'SPAE Capacitaciones',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: appRouter,
      );
}

