import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gerards_paddestoelen_wegwijzer/src/widgets/safety_notice.dart';

void main() {
  Future<void> pumpNotice(WidgetTester tester, Locale locale) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SafetyNotice(locale: locale),
        ),
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
}
