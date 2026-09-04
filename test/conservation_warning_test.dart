import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gerards_paddestoelen_wegwijzer/l10n/app_localizations.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/conservation_status_repository.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/widgets/conservation_warning.dart';

void main() {
  Widget app(String locale, String? status, {bool compact = false}) => MaterialApp(
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ConservationWarning(
            speciesId: 42,
            compact: compact,
            statusLoader: (_) async => status,
          ),
        ),
      );

  Widget recordsApp(
    String locale,
    List<ConservationStatusRecord> records, {
    bool compact = false,
  }) =>
      MaterialApp(
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ConservationWarning(
            speciesId: 42,
            compact: compact,
            recordsLoader: (_) async => records,
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

  testWidgets('Dutch Red List is labeled separately from legal protection',
      (tester) async {
    await tester.pumpWidget(
      recordsApp('nl', const [
        ConservationStatusRecord(
          system: 'nl_red_list',
          scope: 'national',
          jurisdictionCode: 'NL',
          status: 'KW',
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rode Lijst Nederland'), findsOneWidget);
    expect(find.textContaining('Nederlandse Rode Lijst: KW'), findsOneWidget);
    expect(find.textContaining('niet automatisch'), findsOneWidget);
    expect(find.textContaining('wettelijk beschermd'), findsOneWidget);
  });

  testWidgets('IUCN and Dutch Red List can render together', (tester) async {
    await tester.pumpWidget(
      recordsApp('en', const [
        ConservationStatusRecord(
          system: 'iucn_red_list',
          scope: 'global',
          jurisdictionCode: '',
          status: 'VU',
        ),
        ConservationStatusRecord(
          system: 'nl_red_list',
          scope: 'national',
          jurisdictionCode: 'NL',
          status: 'BE',
        ),
      ], compact: true),
    );
    await tester.pumpAndSettle();

    expect(find.text('IUCN VU'), findsOneWidget);
    expect(find.text('NL Red List BE'), findsOneWidget);
  });

  testWidgets('unknown status systems stay hidden', (tester) async {
    await tester.pumpWidget(
      recordsApp('nl', const [
        ConservationStatusRecord(
          system: 'legal_protection',
          scope: 'national',
          jurisdictionCode: 'NL',
          status: 'protected',
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Chip), findsNothing);
    expect(find.textContaining('protected'), findsNothing);
    expect(find.textContaining('beschermd'), findsNothing);
  });
}
