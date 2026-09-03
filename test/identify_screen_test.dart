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
}

class _FakeIdentificationRepository extends IdentificationRepository {
  int identifyCalls = 0;

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
    return const [];
  }
}

class _FakeFieldDataRepository extends FieldDataRepository {
  @override
  Future<List<SeasonRegionOption>> seasonRegions(String languageCode) async =>
      const [];
}
