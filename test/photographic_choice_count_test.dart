import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/features/identify/photographic_trait_wheel.dart';

void main() {
  for (final count in [3, 9, 5, 30]) {
    testWidgets('$count choices produce $count visible selectable photo segments', (tester) async {
      int? chosen;
      await tester.pumpWidget(MaterialApp(home: Center(child: SizedBox.square(
        dimension: 390, child: PhotographicChoiceDial(count: count, selected: 0,
          labels: List.generate(count, (index) => 'Choice $index'), inner: .48,
          showLabel: false, label: 'Choice dial',
          imageBuilder: (_) => const ColoredBox(color: Colors.white),
          onChanged: (index) => chosen = index)))));
      expect(find.byWidgetPredicate((widget) => widget is Positioned &&
        widget.key is ValueKey<String> &&
        (widget.key! as ValueKey<String>).value.startsWith('dial-photo-')),
        findsNWidgets(count));
      await tester.tap(find.byKey(ValueKey('dial-photo-${count - 1}')));
      await tester.pump();
      expect(chosen, count - 1);
      expect(tester.takeException(), isNull);
    });
  }
}
