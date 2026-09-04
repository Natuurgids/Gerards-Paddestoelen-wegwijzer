import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gerards_paddestoelen_wegwijzer/src/features/identify/determination_option_visual.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/features/identify/trait_visual.dart';

void main() {
  testWidgets('explicit determination schematics render without exceptions',
      (tester) async {
    const samples = <(String, int, String)>[
      ('gill_spacing', 93, 'Crowded'),
      ('gill_spacing', 95, 'Distant'),
      ('gill_spacing', 96, 'Not applicable'),
      ('stem_surface', 108, 'Smooth'),
      ('stem_surface', 111, 'Reticulate/netted'),
      ('stem_surface', 114, 'Glandular dots'),
      ('ring', 6, 'Ring present'),
      ('ring', 7, 'No ring'),
      ('ring', 42, 'Uncertain/ring traces'),
      ('volva', 8, 'Volva present'),
      ('volva', 9, 'No volva'),
      ('volva', 43, 'Uncertain/possible remnants'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Wrap(
            children: [
              for (final sample in samples)
                DeterminationOptionVisual(
                  traitCode: sample.$1,
                  optionId: sample.$2,
                  optionLabel: sample.$3,
                ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(DeterminationOptionVisual), findsNWidgets(samples.length));
    expect(tester.takeException(), isNull);
  });

  testWidgets('other traits keep using the established TraitVisual path',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DeterminationOptionVisual(
            traitCode: 'cap_shape',
            optionId: 45,
            optionLabel: 'Conical',
          ),
        ),
      ),
    );

    expect(find.byType(TraitVisual), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
