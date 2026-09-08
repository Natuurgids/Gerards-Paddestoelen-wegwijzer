import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gerards_paddestoelen_wegwijzer/l10n/app_localizations.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/widgets/safety_notice.dart';

void main() {
  Widget app({Duration duration = const Duration(seconds: 3)}) => MaterialApp(
        locale: const Locale('nl'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SafetyNotice(displayDuration: duration)),
      );

  testWidgets('safety notice is visible initially and disappears after 3 seconds',
      (tester) async {
    await tester.pumpWidget(app());

    expect(find.textContaining('Veiligheidswaarschuwing'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2, milliseconds: 999));
    expect(find.textContaining('Veiligheidswaarschuwing'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1));
    expect(find.textContaining('Veiligheidswaarschuwing'), findsNothing);
  });
}
