import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/features/identify/determination_option_visual.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/features/identify/observation_image_data.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/features/identify/observation_context_visual.dart';

void main() {
  test('all 341 choices have a current image mapping, with distinct tree and form states', () {
    expect(observationImages.length, 341);
    for (final ids in [[252,253,254,255,256,257], [259,260,261,262,263,264,265,266,267,268,269], [313,314,315,316,317,318,319,320,321,322,323,324,325,326,327,328,329,330,331]]) {
      expect(ids.map((id) => observationImages[id]!.asset).toSet().length, ids.length);
    }
    expect(observationImages[252]!.asset, contains('habitat_tree_group_alder.jpg'));
    expect(observationImages[262]!.asset, contains('fruitbody_form_truffle.jpg'));
    expect(observationImages[183]!.asset, contains('hymenium_maze_pores.jpg'));
  });
  testWidgets('current mapping overrides a cached incorrect tree photo', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: DeterminationOptionVisual(
      traitCode: 'habitat_tree_group', optionId: 252, optionLabel: 'Els',
      imagePath: 'determination_wheel/assets/traits/habitat_tree_group/birch_conifers.png')));
    final provider = tester.widget<Image>(find.byType(Image)).image as ResizeImage;
    expect(provider.image, AssetImage(observationImages[252]!.asset));
    expect(tester.takeException(), isNull);
  });
  testWidgets('unknown trees and inapplicable caps show states without a misleading photo', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Column(children: [
      DeterminationOptionVisual(traitCode: 'habitat_tree_group', optionId: 258, optionLabel: 'Onbekend'),
      DeterminationOptionVisual(traitCode: 'cap_shape', optionId: 168, optionLabel: 'Geen hoed'),
    ])));
    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.help_outline), findsOneWidget);
    expect(find.byIcon(Icons.not_interested), findsOneWidget);
  });
  testWidgets('microscopic spore shapes are marked diagrams rather than a reused microscope photo', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: DeterminationOptionVisual(
      traitCode: 'spore_shape', optionId: 339, optionLabel: 'Bolvormig')));
    expect(find.byType(ObservationContextVisual), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
