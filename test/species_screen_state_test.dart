import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gerards_paddestoelen_wegwijzer/l10n/app_localizations.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/models.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/repositories.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/features/species/species_screen.dart';

class _MissingSpeciesRepository extends SpeciesRepository {
  @override
  Future<SpeciesDetail?> detail(int id, String languageCode) async => null;
}

void main() {
  testWidgets('completed missing lookup renders not-found state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SpeciesScreen(
          locale: const Locale('en'),
          speciesId: 999999,
          repository: _MissingSpeciesRepository(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Species not found'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('Safety notice'), findsOneWidget);
  });
}
