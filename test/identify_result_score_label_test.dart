import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gerards_paddestoelen_wegwijzer/src/data/models.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/repositories.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/features/identify/identify_screen.dart';

void main() {
  testWidgets('identification result labels percentage as match score',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: IdentifyScreen(
          locale: const Locale('en'),
          repository: _ResultIdentificationRepository(),
          fieldDataRepository: _EmptyFieldDataRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _showResults(tester, 'Show candidates');
    await _scrollResultIntoView(tester, find.text('Porcini'));

    expect(find.text('Porcini'), findsOneWidget);
    expect(
      find.textContaining('Boletus edulis · match score 90%'),
      findsOneWidget,
    );
    expect(find.textContaining('2/3 traits'), findsOneWidget);
    expect(find.textContaining('1/2 field'), findsOneWidget);
  });

  testWidgets('Dutch result uses localized match score wording',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: IdentifyScreen(
          locale: const Locale('nl'),
          repository: _ResultIdentificationRepository(),
          fieldDataRepository: _EmptyFieldDataRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _showResults(tester, 'Toon kandidaten');
    final score = find.textContaining('matchscore 90%');
    await _scrollResultIntoView(tester, score);

    expect(score, findsOneWidget);
  });

  testWidgets('German result uses localized match score wording',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: IdentifyScreen(
          locale: const Locale('de'),
          repository: _ResultIdentificationRepository(),
          fieldDataRepository: _EmptyFieldDataRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _showResults(tester, 'Kandidaten anzeigen');
    final score = find.textContaining('Übereinstimmungswert 90%');
    await _scrollResultIntoView(tester, score);

    expect(score, findsOneWidget);
  });
}

Future<void> _showResults(WidgetTester tester, String buttonLabel) async {
  final button = find.widgetWithText(FilledButton, buttonLabel);
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> _scrollResultIntoView(
  WidgetTester tester,
  Finder target,
) async {
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: find.byType(ListView),
  );
  await tester.pumpAndSettle();
}

class _ResultIdentificationRepository extends IdentificationRepository {
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
  }) async => const [
        IdentificationCandidate(
          species: SpeciesSummary(
            id: 3,
            scientificName: 'Boletus edulis',
            commonName: 'Porcini',
            summary: null,
            imagePath: null,
          ),
          score: 0.9,
          matched: 2,
          requested: 3,
          fieldScore: 0.5,
          fieldMatched: 1,
          fieldRequested: 2,
        ),
      ];
}

class _EmptyFieldDataRepository extends FieldDataRepository {
  @override
  Future<List<SeasonRegionOption>> seasonRegions(String languageCode) async =>
      const [];
}
