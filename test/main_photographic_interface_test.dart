import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gerards_paddestoelen_wegwijzer/l10n/app_localizations.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/models.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/reference_asset_store.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/repositories.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/features/identify/identify_screen.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/features/identify/photographic_trait_wheel.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/features/identify/trait_visual.dart';

late List<TraitChoice> _realChoices;
Widget app() => MaterialApp(
  locale: const Locale('nl'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: IdentifyScreen(initialKey: false, locale: const Locale('nl'),
    repository: _PreloadedRepository(),
    fieldDataRepository: _EmptyFieldRepository()),
);
void main() {
  setUpAll(() async {
    _realChoices = await ReferenceAssetStore.instance.traitChoices('nl');
    await (FontLoader('Roboto')..addFont(rootBundle.load(
      'determination_wheel/assets/fonts/Roboto-Regular.ttf'))).load();
    await (FontLoader('MaterialIcons')..addFont(rootBundle.load(
      'fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final spec in <(String, Size, double)>[
    ('phone', const Size(390, 844), 1),
    ('small-phone', const Size(320, 568), 1),
    ('large-text', const Size(390, 844), 2),
    ('tablet', const Size(1200, 900), 1),
    ('landscape', const Size(844, 390), 1),
  ]) {
    testWidgets('main photographic wheel fits ${spec.$1}', (tester) async {
      tester.view.physicalSize = spec.$2;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.textScaleFactorTestValue = spec.$3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final boundary = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(key: boundary, child: app()));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await precacheImage(const AssetImage(
          'determination_wheel/assets/interface/woodland-background.png'),
          boundary.currentContext!);
        for (final image in tester.widgetList<Image>(find.byType(Image))) {
          await precacheImage(image.image, boundary.currentContext!);
        }
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('trait-choice-dial')), findsOneWidget);
      expect(find.byKey(const ValueKey('trait-group-dial')), findsOneWidget);
      expect(find.byType(TraitVisual), findsNothing,
        reason: 'All visible choices must use their real photographs.');
      expect(find.textContaining('0/23 · 341'), findsOneWidget);
      await tester.runAsync(() async {
        final render = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await render.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final dir = Directory('build/main-interface-verification')..createSync(recursive: true);
        File('${dir.path}/${spec.$1}.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    });
  }
  testWidgets('rotating previews, confirming records, editing preserves other observations', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.textContaining('0/23 ·'), findsOneWidget);
    final semantics = tester.ensureSemantics();
    final choice = tester.getSemantics(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Keuzeschijf'));
    choice.owner!.performAction(choice.id, ui.SemanticsAction.increase);
    await tester.pump();
    expect(find.textContaining('0/23 ·'), findsOneWidget);
    expect(tester.widget<PhotographicChoiceDial>(find.byKey(const ValueKey('trait-choice-dial'))).selected, 1);
    await tester.tap(find.byKey(const ValueKey('confirm-trait')));
    await tester.pumpAndSettle();
    expect(find.textContaining('1/23 ·'), findsOneWidget);
    final group = tester.getSemantics(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Observatieschijf'));
    group.owner!.performAction(group.id, ui.SemanticsAction.decrease);
    await tester.pump();
    expect(find.textContaining('1/23 ·'), findsOneWidget);
    expect(tester.widget<PhotographicChoiceDial>(find.byKey(const ValueKey('trait-group-dial'))).selected, 0);
    await tester.tap(find.byKey(const ValueKey('open-trait-group')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-trait')));
    await tester.pumpAndSettle();
    expect(find.textContaining('1/23 ·'), findsOneWidget);
    semantics.dispose();
    await tester.tap(find.byKey(const ValueKey('toggle-trait-view')));
    await tester.pumpAndSettle();
    expect(find.byType(PhotographicTraitWheel), findsNothing);
    expect(find.byKey(const ValueKey('trait-grid-20')), findsOneWidget);
  });
  testWidgets('outer dial actually responds to angular dragging without recording', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final rect = tester.getRect(find.byKey(const ValueKey('trait-choice-dial')));
    final start = rect.center + Offset(rect.width * .4, 0);
    final gesture = await tester.startGesture(start);
    await gesture.moveTo(rect.center + Offset(rect.width * .35, -rect.height * .2));
    await gesture.moveTo(rect.center + Offset(0, -rect.height * .4));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.textContaining('0/23 ·'), findsOneWidget);
    expect(tester.widget<PhotographicChoiceDial>(find.byKey(const ValueKey('trait-choice-dial'))).selected, isNot(0));
    expect(tester.takeException(), isNull);
  });
}
class _EmptyFieldRepository extends FieldDataRepository {
  @override
  Future<List<SeasonRegionOption>> seasonRegions(String languageCode) async => [];
}

// Real bundled catalogue with synchronous delivery inside the widget-test clock.
class _PreloadedRepository extends IdentificationRepository {
  @override
  Future<List<TraitChoice>> choices(String languageCode) => SynchronousFuture(_realChoices);
}
