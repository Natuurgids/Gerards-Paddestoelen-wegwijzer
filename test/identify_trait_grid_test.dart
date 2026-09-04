import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gerards_paddestoelen_wegwijzer/l10n/app_localizations.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/models.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/repositories.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/features/identify/identify_screen.dart';

void main() {
  testWidgets('determination choices use responsive field-guide cards',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: IdentifyScreen(
          locale: const Locale('en'),
          repository: _TraitRepository(),
          fieldDataRepository: _EmptyFieldDataRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final grid = tester.widget<GridView>(find.byKey(const ValueKey('trait-grid-5')));
    final delegate = grid.gridDelegate as SliverGridDelegateWithMaxCrossAxisExtent;

    expect(delegate.maxCrossAxisExtent, 156);
    expect(delegate.mainAxisExtent, 140);

    final label = tester.widget<Text>(find.text('Bracket/fan-shaped'));
    expect(label.maxLines, 3);
    expect(label.overflow, TextOverflow.ellipsis);
  });
}

class _TraitRepository extends IdentificationRepository {
  @override
  Future<List<TraitChoice>> choices(String languageCode) async => const [
        TraitChoice(
          traitId: 5,
          traitCode: 'cap_shape',
          traitLabel: 'Cap shape',
          optionId: 10,
          optionLabel: 'Convex to flat',
        ),
        TraitChoice(
          traitId: 5,
          traitCode: 'cap_shape',
          traitLabel: 'Cap shape',
          optionId: 11,
          optionLabel: 'Broadly convex',
        ),
        TraitChoice(
          traitId: 5,
          traitCode: 'cap_shape',
          traitLabel: 'Cap shape',
          optionId: 45,
          optionLabel: 'Conical',
        ),
        TraitChoice(
          traitId: 5,
          traitCode: 'cap_shape',
          traitLabel: 'Cap shape',
          optionId: 51,
          optionLabel: 'Bracket/fan-shaped',
        ),
      ];

  @override
  Future<List<IdentificationCandidate>> identify(
    String languageCode,
    Map<int, int> selected, {
    int? observationMonth,
    String? seasonRegionCode,
    double? capDiameterCm,
    double? stemHeightCm,
    double? stemDiameterCm,
  }) async =>
      const [];
}

class _EmptyFieldDataRepository extends FieldDataRepository {
  @override
  Future<List<SeasonRegionOption>> seasonRegions(String languageCode) async =>
      const [];
}
