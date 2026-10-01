import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mushroom_determination_wheel/main.dart';

void main(){
  Future<void> openWheel(WidgetTester tester) async {
    await tester.pumpWidget(const App());
    await tester.pump();
    if (find.byKey(const ValueKey('splash')).evaluate().isNotEmpty) {
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump(const Duration(milliseconds: 350));
    }
  }

  testWidgets('non-plate underside routes show live possibilities',(tester)async{
    await openWheel(tester);
    await tester.tap(find.text('Hoed + steel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buisjes / poriën'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Mogelijke groepen:'),findsOneWidget);
    expect(find.textContaining('Boleten'),findsWidgets);
  });

  testWidgets('back removes the latest observation',(tester)async{
    await openWheel(tester);
    await tester.tap(find.text('Hoed + steel'));
    await tester.pumpAndSettle();
    expect(find.text('Sporenvormende onderzijde'),findsWidgets);

    await tester.tap(find.byTooltip('Vorige observatie'));
    await tester.pumpAndSettle();
    expect(find.text('Vorm vruchtlichaam'),findsWidgets);
  });

  testWidgets('live possibilities expose match and evidence coverage',(tester)async{
    await openWheel(tester);
    await tester.tap(find.text('Hoed + steel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plaatjes'));
    await tester.pumpAndSettle();

    expect(find.textContaining('% dekking'),findsWidgets);
    expect(find.textContaining('Mogelijke groepen:'),findsOneWidget);
  });

  testWidgets('result explains ranking is not probability and typical evidence is non-exclusive',(tester)async{
    tester.view.physicalSize=const Size(1200,1600);
    tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await openWheel(tester);
    Future<void> pick(String label)async{
      final target=find.text(label);
      await tester.ensureVisible(target.first);
      await tester.tap(target.first);
      await tester.pumpAndSettle();
    }
    await pick('Hoed + steel');
    await pick('Plaatjes');
    await pick('Glad');
    await pick('Vrij');
    await pick('Geen zichtbaar');
    await pick('Nee');
    await pick('Roze');
    await pick('Ga verder met veldkenmerken');
    await pick('Bos');
    await pick('Geen duidelijke waardplant');
    await pick('Dood hout');
    await pick('Afzonderlijk');
    await pick('Middelgroot');
    await pick('Bruin');
    await pick('Geen opvallende geur');
    await pick('Geen melksap');
    await pick('Vlezig / vezelig');
    await pick('Toon eindresultaat');

    expect(find.textContaining('geen waarschijnlijkheidsrangschikking'),findsOneWidget);
    expect(find.textContaining('Aanvullend bronkenmerk (niet uitsluitend): substraat: Dood hout'),findsOneWidget);
    expect(find.textContaining('géén kans dat de determinatie juist is'),findsOneWidget);
  });

  testWidgets('live candidate tooltip distinguishes hard and non-exclusive evidence',(tester)async{
    tester.view.physicalSize=const Size(1200,1600);
    tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await openWheel(tester);
    Future<void> pick(String label)async{
      final target=find.text(label);
      await tester.ensureVisible(target.first);
      await tester.tap(target.first);
      await tester.pumpAndSettle();
    }
    await pick('Hoed + steel');
    await pick('Plaatjes');
    await pick('Glad');
    await pick('Vrij');
    await pick('Geen zichtbaar');
    await pick('Nee');
    await pick('Roze');
    await pick('Ga verder met veldkenmerken');
    await pick('Bos');
    await pick('Geen duidelijke waardplant');
    await pick('Dood hout');

    final pluteus=find.byWidgetPredicate((w)=>w is Chip&&w.label is Text&&(w.label as Text).data?.contains('Hertenzwammen · Pluteus')==true);
    expect(pluteus,findsOneWidget);
    await tester.longPress(pluteus);
    await tester.pumpAndSettle();
    expect(find.textContaining('Hard: onderzijde: Plaatjes'),findsOneWidget);
    expect(find.textContaining('Aanvullend, niet uitsluitend: substraat: Dood hout'),findsOneWidget);
  });

  testWidgets('tough trama observation is reachable and remains supporting only',(tester)async{
    tester.view.physicalSize=const Size(1200,1600);
    tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await openWheel(tester);
    Future<void> pick(String label)async{
      final target=find.text(label);
      await tester.ensureVisible(target.first);
      await tester.tap(target.first);
      await tester.pumpAndSettle();
    }
    await pick('Hoed + steel');
    await pick('Plaatjes');
    await pick('Glad');
    await pick('Aflopend');
    await pick('Geen zichtbaar');
    await pick('Nee');
    await pick('Wit / crème');
    await pick('Ga verder met veldkenmerken');
    await pick('Bos');
    await pick('Geen duidelijke waardplant');
    await pick('Dood hout');
    await pick('Afzonderlijk');
    await pick('Middelgroot');
    await pick('Bruin');
    await pick('Geen opvallende geur');
    await pick('Geen melksap');

    expect(find.text('Taai / leerachtig'),findsOneWidget);
    await pick('Taai / leerachtig');

    final pleurotus=find.byWidgetPredicate((w)=>w is Chip&&w.label is Text&&(w.label as Text).data?.contains('Oesterzwammen · Pleurotus')==true);
    expect(pleurotus,findsOneWidget);
    await tester.longPress(pleurotus);
    await tester.pumpAndSettle();
    expect(find.textContaining('Aanvullend, niet uitsluitend: trama / vlees: Taai / leerachtig'),findsOneWidget);
  });

}
