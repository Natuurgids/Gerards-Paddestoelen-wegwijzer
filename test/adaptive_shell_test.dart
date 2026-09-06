import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gerards_paddestoelen_wegwijzer/l10n/app_localizations.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/features/home/home_screen.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/features/home/splash_screen.dart';

void main() {
  Widget localized(Widget home) => MaterialApp(
        locale: const Locale('nl'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      );

  testWidgets('wide home uses desktop navigation shell', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      localized(
        HomeScreen(
          locale: const Locale('nl'),
          onLocaleChanged: (_) {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Gerards Paddestoelen Wegwijzer'), findsWidgets);
    expect(find.text('Determineren'), findsWidgets);
    expect(find.text('Soorten bekijken'), findsWidgets);
    expect(find.text('Leren'), findsWidgets);
    expect(find.text('Nieuwe leermaterialen'), findsWidgets);
    expect(find.text('Identify • Learn • Explore'), findsWidgets);
    expect(find.byType(Drawer), findsNothing);
  });

  testWidgets('compact home keeps drawer navigation and cards', (tester) async {
    tester.view.physicalSize = const Size(420, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      localized(
        HomeScreen(
          locale: const Locale('nl'),
          onLocaleChanged: (_) {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Determineren'), findsOneWidget);
    expect(find.byIcon(Icons.menu), findsOneWidget);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.byType(Drawer), findsOneWidget);
    expect(find.text('Determineren'), findsWidgets);
    expect(find.text('Leren'), findsWidgets);
    expect(find.text('Nieuwe leermaterialen'), findsWidgets);
  });

  testWidgets('brand splash shows app name, credits and can be skipped', (
    tester,
  ) async {
    var continued = false;
    await tester.pumpWidget(
      localized(
        BrandSplashScreen(onContinue: () => continued = true),
      ),
    );

    expect(find.text('Gerards Paddestoelen Wegwijzer'), findsOneWidget);
    expect(find.text('Ontdek. Leer. Bescherm.'), findsOneWidget);
    expect(find.text('Met respect voor natuur en soorten'), findsOneWidget);
    expect(find.textContaining('Natuurgids.org'), findsOneWidget);
    expect(find.textContaining('Bronnen en beeldrechten'), findsOneWidget);

    await tester.tap(find.text('Tik om door te gaan'));
    expect(continued, isTrue);
  });
}
