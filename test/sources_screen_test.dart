import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gerards_paddestoelen_wegwijzer/l10n/app_localizations.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/features/home/sources_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget app(Locale locale) => MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SourcesScreen(),
      );

  testWidgets('Dutch sources screen exposes NSR licence and source boundaries',
      (tester) async {
    await tester.pumpWidget(app(const Locale('nl')));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();

    expect(find.text('Bronnen & licenties'), findsOneWidget);
    expect(
      find.text('Checklist Dutch Species Register - Nederlands Soortenregister'),
      findsOneWidget,
    );
    expect(find.textContaining('CC BY 4.0'), findsOneWidget);
    expect(find.text('First Nature fungus identification guides'), findsOneWidget);
    expect(
      find.textContaining('Geen hergebruiklicentie vastgelegd'),
      findsOneWidget,
    );
    expect(find.textContaining('Veiligheidswaarschuwing'), findsOneWidget);
  });
}
