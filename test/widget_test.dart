import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gerards_paddestoelen_wegwijzer/l10n/app_localizations.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/features/home/home_screen.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/widgets/safety_notice.dart';

void main() {
  Widget localizedApp(Locale locale, Widget home) => MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      );

  Future<void> pumpNotice(WidgetTester tester, Locale locale) async {
    await tester.pumpWidget(
      localizedApp(
        locale,
        Scaffold(body: SafetyNotice(locale: locale)),
      ),
    );
  }

  testWidgets('safety notice is localized in Dutch', (tester) async {
    await pumpNotice(tester, const Locale('nl'));
    expect(find.textContaining('Veiligheidswaarschuwing'), findsOneWidget);
    expect(find.textContaining('eet nooit een paddenstoel'), findsOneWidget);
  });

  testWidgets('safety notice is localized in English', (tester) async {
    await pumpNotice(tester, const Locale('en'));
    expect(find.textContaining('Safety notice'), findsOneWidget);
    expect(find.textContaining('Never consume a mushroom'), findsOneWidget);
  });

  testWidgets('safety notice is localized in German', (tester) async {
    await pumpNotice(tester, const Locale('de'));
    expect(find.textContaining('Sicherheitshinweis'), findsOneWidget);
    expect(find.textContaining('Verzehren Sie niemals einen Pilz'), findsOneWidget);
  });

  testWidgets('home screen renders localized navigation copy', (tester) async {
    await tester.pumpWidget(
      localizedApp(
        const Locale('de'),
        HomeScreen(
          locale: const Locale('de'),
          onLocaleChanged: (_) {},
        ),
      ),
    );

    expect(find.text('Gerards Pilz-Wegweiser'), findsOneWidget);
    expect(find.text('Bestimmen'), findsOneWidget);
    expect(find.text('Lernen'), findsOneWidget);
    expect(find.text('Arten ansehen'), findsOneWidget);
    expect(find.textContaining('Sicherheitshinweis'), findsOneWidget);
  });

  testWidgets('home language selector emits the selected locale', (tester) async {
    Locale? selectedLocale;
    await tester.pumpWidget(
      localizedApp(
        const Locale('nl'),
        HomeScreen(
          locale: const Locale('nl'),
          onLocaleChanged: (locale) => selectedLocale = locale,
        ),
      ),
    );

    await tester.tap(find.text('NL'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DE').last);
    await tester.pumpAndSettle();

    expect(selectedLocale?.languageCode, 'de');
  });
}
