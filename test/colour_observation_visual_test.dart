import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/features/identify/colour_observation_data.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/features/identify/colour_observation_visual.dart';

void main() {
  test('all six observation structures have complete explicit colour coverage', () {
    expect(colourObservationStyles.length, 120);
    expect(colourObservationStyles.values.map((s) => s.trait).toSet(), {
      'cap_color', 'gill_colour', 'stem_colour', 'flesh_colour', 'spore_print', 'bruising',
    });
    expect(colourObservationStyles[226]!.tint, 0xff568b50);
    expect(colourObservationStyles[21]!.tint, 0xff5385ac);
    expect(colourObservationStyles[19]!.kind, 'none');
    expect(colourObservationStyles[19]!.tint, isNull);
    expect(colourObservationStyles[152]!.tint,
      isNot(colourObservationStyles[32]!.tint), reason: 'Blue must not reuse grey.');
    expect(colourObservationStyles[230]!.kind, 'red_then_black');
  });

  testWidgets('green bruising colours only a local patch, leaving white flesh visible', (tester) async {
    final boundary = GlobalKey();
    await tester.pumpWidget(MaterialApp(home: Center(child:
      RepaintBoundary(key: boundary, child: const ColourObservationVisual(
        traitCode: 'bruising', optionId: 226,
        optionLabel: 'Groen verkleurend', size: 180)))));
    await tester.runAsync(() async {
      for (final image in tester.widgetList<Image>(find.byType(Image))) {
        await precacheImage(image.image, boundary.currentContext!);
      }
    });
    await tester.pumpAndSettle();
    final filter = tester.widget<ColorFiltered>(find.byType(ColorFiltered));
    expect(filter.colorFilter,
      const ColorFilter.mode(Color(0xff568b50), BlendMode.modulate));
    expect(find.byType(Image), findsNWidgets(2));
    final base = tester.getRect(find.byType(Image).first);
    final patch = tester.getRect(find.byType(Image).last);
    expect(patch.width, lessThan(base.width / 2));
    expect(patch.height, lessThan(base.height / 2));
    expect(base.contains(patch.center), isTrue);
    await tester.runAsync(() async {
      final render = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage();
      final pixels = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      final green = (90 * image.width + 112) * 4;
      expect(pixels.getUint8(green + 1), greaterThan(pixels.getUint8(green) + 8));
      expect(pixels.getUint8(green + 1), greaterThan(pixels.getUint8(green + 2) + 8));
      final white = (90 * image.width + 54) * 4;
      expect((pixels.getUint8(white) - pixels.getUint8(white + 1)).abs(), lessThan(15));
      expect(pixels.getUint8(white), greaterThan(150));
      image.dispose();
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('no bruising and unknown cannot inherit a coloured reaction', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Column(children: [
      ColourObservationVisual(traitCode: 'bruising', optionId: 19,
        optionLabel: 'Geen verkleuring', size: 100),
      ColourObservationVisual(traitCode: 'bruising', optionId: 231,
        optionLabel: 'Onzeker', size: 100),
    ])));
    expect(find.byType(ColorFiltered), findsNothing);
    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(Icons.help_outline), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
