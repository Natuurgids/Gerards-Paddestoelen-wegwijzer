import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gerards_paddestoelen_wegwijzer/src/data/models.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/repositories.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/features/identify/identify_screen.dart';

void main() {
  testWidgets('invalid measurement shows inline error and blocks ranking',
      (tester) async {
    final repository = _FakeIdentificationRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: IdentifyScreen(
          locale: const Locale('en'),
          repository: repository,
          fieldDataRepository: _FakeFieldDataRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Never consume a mushroom based solely'),
      findsOneWidget,
    );

    final capField = find.widgetWithText(TextField, 'Cap diameter (cm)');
    expect(capField, findsOneWidget);
    await tester.enterText(capField, 'not-a-number');

    final button = find.widgetWithText(FilledButton, 'Show candidates');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();

    expect(find.text('Enter a valid number.'), findsOneWidget);
    expect(repository.identifyCalls, 0);
  });

  testWidgets('non-positive measurement uses localized German error',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: IdentifyScreen(
          locale: const Locale('de'),
          repository: _FakeIdentificationRepository(),
          fieldDataRepository: _FakeFieldDataRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final capField = find.widgetWithText(TextField, 'Hutdurchmesser (cm)');
    await tester.enterText(capField, '0');

    final button = find.widgetWithText(FilledButton, 'Kandidaten anzeigen');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();

    expect(find.text('Verwende einen Wert größer als 0.'), findsOneWidget);
    expect(
      find.textContaining('Verzehren Sie niemals einen Pilz ausschließlich'),
      findsOneWidget,
    );
  });

  testWidgets('selected season region requires observation month',
      (tester) async {
    final repository = _FakeIdentificationRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: IdentifyScreen(
          locale: const Locale('en'),
          repository: repository,
          fieldDataRepository: _RegionFieldDataRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final seasonReference =
        find.widgetWithText(DropdownButtonFormField<String?>, 'Season reference');
    await _dragUntilBuilt(tester, seasonReference);
    await tester.tap(seasonReference);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Britain & Ireland').last);
    await tester.pumpAndSettle();

    expect(find.text('Observation month'), findsOneWidget);

    final button = find.widgetWithText(FilledButton, 'Show candidates');
    await _dragUntilBuilt(tester, button);
    await tester.tap(button);
    await tester.pump();

    expect(find.text('Select an observation month.'), findsOneWidget);
    expect(repository.identifyCalls, 0);
  });

  testWidgets('selected season evidence is forwarded to identification',
      (tester) async {
    final repository = _FakeIdentificationRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: IdentifyScreen(
          locale: const Locale('en'),
          repository: repository,
          fieldDataRepository: _RegionFieldDataRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final seasonReference =
        find.widgetWithText(DropdownButtonFormField<String?>, 'Season reference');
    await _dragUntilBuilt(tester, seasonReference);
    await tester.tap(seasonReference);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Britain & Ireland').last);
    await tester.pumpAndSettle();

    final month =
        find.widgetWithText(DropdownButtonFormField<int>, 'Observation month');
    await _dragUntilBuilt(tester, month);
    await tester.tap(month);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oct').last);
    await tester.pumpAndSettle();

    final button = find.widgetWithText(FilledButton, 'Show candidates');
    await _dragUntilBuilt(tester, button);
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(repository.identifyCalls, 1);
    expect(repository.lastSeasonRegionCode, 'GB-IE');
    expect(repository.lastObservationMonth, 10);
    expect(find.text('Select an observation month.'), findsNothing);
  });
}

Future<void> _dragUntilBuilt(WidgetTester tester, Finder target) async {
  final listView = find.byType(ListView);
  for (var attempt = 0; attempt < 8 && target.evaluate().isEmpty; attempt++) {
    await tester.drag(listView, const Offset(0, -240));
    await tester.pumpAndSettle();
  }
  expect(target, findsOneWidget);
}

class _FakeIdentificationRepository extends IdentificationRepository {
  int identifyCalls = 0;
  int? lastObservationMonth;
  String? lastSeasonRegionCode;

  @override
  Future<List<TraitChoice>> choices(String languageCode) async => const [];

  @override
  Future<List<IdentificationCandidate>> identify(
    String languageCode,
    Map<int, int> selected, {
    int? observationMonth,
    String? seasonRegionCode,
    double? capDiameterCm,
    double? stemHeightCm,
    double? stemDiameterCm,
  }) async {
    identifyCalls++;
    lastObservationMonth = observationMonth;
    lastSeasonRegionCode = seasonRegionCode;
    return const [];
  }
}

class _FakeFieldDataRepository extends FieldDataRepository {
  @override
  Future<List<SeasonRegionOption>> seasonRegions(String languageCode) async =>
      const [];
}

class _RegionFieldDataRepository extends FieldDataRepository {
  @override
  Future<List<SeasonRegionOption>> seasonRegions(String languageCode) async =>
      const [
        SeasonRegionOption(
          code: 'GB-IE',
          label: 'Britain & Ireland',
          note: 'Reference calendar for Britain and Ireland.',
        ),
      ];
}
