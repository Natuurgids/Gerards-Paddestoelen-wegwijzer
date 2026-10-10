import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mushroom_determination_wheel/main.dart';

void main() {
  for(final spec in <(String,Size,double)>[
    ('phone',const Size(390,844),1),
    ('small-phone',const Size(320,568),1),
    ('large-text',const Size(390,844),2),
    ('tablet',const Size(1200,900),1),
    ('landscape',const Size(844,390),1),
  ]) {
    testWidgets('Render ${spec.$1} with no layout or asset exceptions',(tester) async {
      tester.view.physicalSize=spec.$2;tester.view.devicePixelRatio=1;
      addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.textScaleFactorTestValue=spec.$3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final boundary=GlobalKey();
      await tester.pumpWidget(RepaintBoundary(key:boundary,child:const App(skipSplash:true)));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        // Wait for all real asset decodes before capturing the rendered UI.
        for(final image in tester.widgetList<Image>(find.byType(Image))) {
          await precacheImage(image.image,boundary.currentContext!);
        }
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(),isNull);
      for(var i=0;i<5;i++) {
        expect(find.byKey(ValueKey('cap-dot-$i')),findsOneWidget);
        expect(find.byKey(ValueKey('stem-wheel-$i')),findsOneWidget);
      }
      await tester.runAsync(() async {
        final render=boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image=await render.toImage();
        final data=await image.toByteData(format:ui.ImageByteFormat.png);
        final dir=Directory('build/interface-verification')..createSync(recursive:true);
        File('${dir.path}/${spec.$1}.png').writeAsBytesSync(data!.buffer.asUint8List());
        image.dispose();
      });
    });
  }
}
