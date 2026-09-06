import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'data/learning_materials_service.dart';
import 'features/home/home_screen.dart';
import 'features/home/splash_screen.dart';
import 'theme/app_theme.dart';

class MycologyApp extends StatefulWidget {
  const MycologyApp({super.key, this.learningMaterialsService});

  final LearningMaterialsService? learningMaterialsService;

  @override
  State<MycologyApp> createState() => _MycologyAppState();
}

class _MycologyAppState extends State<MycologyApp> {
  Locale _locale = const Locale('nl');

  void _setLocale(Locale locale) => setState(() => _locale = locale);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: _locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: AppTheme.light,
      home: SplashGate(
        child: HomeScreen(
          locale: _locale,
          onLocaleChanged: _setLocale,
          learningMaterialsService: widget.learningMaterialsService,
        ),
      ),
    );
  }
}
