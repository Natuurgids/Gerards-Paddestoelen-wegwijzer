import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gerards_paddestoelen_wegwijzer/src/widgets/species_image.dart';

void main() {
  Future<void> pumpImage(
    WidgetTester tester, {
    required String path,
    required String missingLabel,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 240,
            child: SpeciesImage(path: path, missingLabel: missingLabel),
          ),
        ),
      ),
    );
  }

  testWidgets('empty gallery slot shows localized placeholder', (tester) async {
    await pumpImage(
      tester,
      path: '',
      missingLabel: 'Afbeelding nog niet beschikbaar',
    );

    expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
    expect(find.text('Afbeelding nog niet beschikbaar'), findsOneWidget);
  });

  testWidgets('missing packaged asset falls back without broken UI', (tester) async {
    await pumpImage(
      tester,
      path: 'assets/images/species/does-not-exist.webp',
      missingLabel: 'Image not available yet',
    );
    await tester.pump();

    expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
    expect(find.text('Image not available yet'), findsOneWidget);
  });
}
