import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'features/home/home_screen.dart';

class MycologyApp extends StatefulWidget {
  const MycologyApp({super.key});

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
      theme: ThemeData(
        colorSchemeSeed: Colors.green,
        useMaterial3: true,
      ),
      home: HomeScreen(locale: _locale, onLocaleChanged: _setLocale),
    );
  }
}
