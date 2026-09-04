import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gerards_paddestoelen_wegwijzer/src/features/identify/trait_visual.dart';

void main() {
  testWidgets('key morphology illustrations render without exceptions',
      (tester) async {
    const samples = <(String, int, String)>[
      ('cap_shape', 45, 'Conical'),
      ('cap_shape', 48, 'Funnel-shaped'),
      ('gill_attachment', 14, 'Free'),
      ('gill_attachment', 62, 'Decurrent'),
      ('hymenium', 4, 'Gills'),
      ('hymenium', 5, 'Pores'),
      ('stem_base_shape', 16, 'Bulbous'),
      ('ring', 6, 'Ring present'),
      ('volva', 8, 'Volva present'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Wrap(
            children: [
              for (final sample in samples)
                TraitVisual(
                  traitCode: sample.$1,
                  optionId: sample.$2,
                  optionLabel: sample.$3,
                ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(TraitVisual), findsNWidgets(samples.length));
    expect(tester.takeException(), isNull);
  });
}
