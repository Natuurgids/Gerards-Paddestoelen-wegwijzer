import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gerards_paddestoelen_wegwijzer/l10n/app_localizations.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/models.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/repositories.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/features/identify/determination_key.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/features/identify/determination_key_view.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/features/identify/identify_screen.dart';

final book = DeterminationKeyBook(
 jsonDecode(File('assets/data/determination_keys.json').readAsStringSync()) as Map<String, dynamic>,
 jsonDecode(File('assets/data/species_catalog.json').readAsStringSync()) as Map<String, dynamic>);
Widget app() => MaterialApp(locale: const Locale('nl'),
 localizationsDelegates: AppLocalizations.localizationsDelegates,
 supportedLocales: AppLocalizations.supportedLocales,
 home: IdentifyScreen(locale: const Locale('nl'), keyBook: book,
  repository: _EmptyRepository(), fieldDataRepository: _EmptyFields()));
void main() {
 setUpAll(() async {
  await (FontLoader('Roboto')..addFont(rootBundle.load(
    'determination_wheel/assets/fonts/Roboto-Regular.ttf'))).load();
  await (FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
 });
 for (final spec in <(String,Size,double)>[
  ('key-phone',const Size(390,844),1),('key-small-phone',const Size(320,568),1),
  ('key-large-text',const Size(390,844),2),('key-landscape',const Size(844,390),1),
  ('key-tablet',const Size(1200,900),1)]) {
  testWidgets('source key is the main app default and fits ${spec.$1}', (tester) async {
   tester.view.physicalSize=spec.$2;tester.view.devicePixelRatio=1;
   addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
   tester.platformDispatcher.textScaleFactorTestValue=spec.$3;
   addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
   final boundary=GlobalKey();
   await tester.pumpWidget(RepaintBoundary(key:boundary,child:app()));
   await tester.pumpAndSettle();
   await tester.runAsync(() async {
    await precacheImage(const AssetImage('determination_wheel/assets/interface/woodland-background.png'),boundary.currentContext!);
    for(final image in tester.widgetList<Image>(find.byType(Image))) {
     await precacheImage(image.image,boundary.currentContext!);
    }
   });
   await tester.pumpAndSettle();
   expect(find.byType(DeterminationKeyView),findsOneWidget);
   expect(find.byKey(const ValueKey('confirm-key-choice')),findsOneWidget);
   expect(find.byKey(const ValueKey('key-route-dial')),findsOneWidget);
   expect(tester.takeException(),isNull);
   await tester.runAsync(() async {
    final render=boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image=await render.toImage();final bytes=await image.toByteData(format:ui.ImageByteFormat.png);
    Directory('build/main-interface-verification').createSync(recursive:true);
    File('build/main-interface-verification/${spec.$1}.png').writeAsBytesSync(bytes!.buffer.asUint8List());image.dispose();
   });
  });
 }
 testWidgets('preview never advances, confirmation follows a source jump, mode switching retains route', (tester) async {
  await tester.pumpWidget(app());await tester.pumpAndSettle();
  final view=tester.widget<DeterminationKeyView>(find.byType(DeterminationKeyView));
  expect(view.session.current,'entry');
  await tester.tap(find.byTooltip('Volgende keuze'));await tester.pumpAndSettle();
  expect(view.session.current,'entry');
  await tester.tap(find.byKey(const ValueKey('confirm-key-choice')));await tester.pumpAndSettle();
  expect(view.session.current,'veldguide-ii/0/1');
  await tester.tap(find.byKey(const ValueKey('toggle-key-mode')));await tester.pumpAndSettle();
  expect(find.byType(DeterminationKeyView),findsNothing);
  await tester.tap(find.byKey(const ValueKey('toggle-key-mode')));await tester.pumpAndSettle();
  expect(tester.widget<DeterminationKeyView>(find.byType(DeterminationKeyView)).session.current,'veldguide-ii/0/1');
  await tester.tap(find.byTooltip('Wis observaties'));await tester.pumpAndSettle();
  expect(tester.widget<DeterminationKeyView>(find.byType(DeterminationKeyView)).session.current,'entry');
  expect(tester.takeException(),isNull);
 });
}
class _EmptyRepository extends IdentificationRepository {
 @override Future<List<TraitChoice>> choices(String languageCode)=>SynchronousFuture([]);
}
class _EmptyFields extends FieldDataRepository {
 @override Future<List<SeasonRegionOption>> seasonRegions(String languageCode)=>SynchronousFuture([]);
}
