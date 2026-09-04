import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/widgets/conservation_warning.dart';

void main() {
  Widget app(String locale, String? status, {bool compact = false}) => MaterialApp(
        locale: Locale(locale),
        supportedLocales: const [Locale('nl'), Locale('en'), Locale('de')],
        home: Scaffold(
          body: ConservationWarning(
            speciesId: 42,
            compact: compact,
            statusLoader: (_) async => status,
          ),
        ),
      );

  testWidgets('shows Dutch warning for threatened IUCN status', (tester) async {
    await tester.pumpWidget(app('nl', 'Vulnerable'));
    await tester.pumpAndSettle();
    expect(find.text('Beschermingswaarschuwing'), findsOneWidget);
    expect(find.textContaining('IUCN Rode Lijst: Vulnerable'), findsOneWidget);
    expect(find.textContaining('niet automatisch een wettelijke'), findsOneWidget);
  });

  testWidgets('hides least-concern status', (tester) async {
    await tester.pumpWidget(app('en', 'Least Concern'));
    await tester.pumpAndSettle();
    expect(find.textContaining('IUCN'), findsNothing);
  });

  testWidgets('shows compact badge in determination results', (tester) async {
    await tester.pumpWidget(app('de', 'EN', compact: true));
    await tester.pumpAndSettle();
    expect(find.text('IUCN EN'), findsOneWidget);
  });
}
