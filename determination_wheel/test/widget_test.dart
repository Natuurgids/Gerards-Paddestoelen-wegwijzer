import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mushroom_determination_wheel/main.dart';

void main(){
  Future<void> openWheel(WidgetTester tester) async {
    await tester.pumpWidget(const App(skipSplash: true));
    await tester.pump();
  }

  testWidgets('standalone wheel shows supplied in-app mascot', (tester) async {
    await openWheel(tester);

    final mascot = tester.widget<Image>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName == 'assets/app_icon.png',
      ),
    );

    expect((mascot.image as AssetImage).assetName, 'assets/app_icon.png');
  });

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
    expect(find.textContaining('Sporenvormende onderzijde'),findsWidgets);

    await tester.tap(find.byTooltip('Vorige observatie'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Vorm vruchtlichaam'),findsWidgets);
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

  testWidgets('phone layout is compact and branded without overflow',(tester)async{
    tester.view.physicalSize=const Size(360,640);
    tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await openWheel(tester);
    expect(find.text('Wiel'),findsOneWidget);
    expect(find.text('Observatie 1'),findsOneWidget);
    expect(find.textContaining('Vorm vruchtlichaam'),findsOneWidget);
    expect(find.text('Paddenstoelen Determinatiewiel'),findsNothing);
    expect(tester.takeException(),isNull);
  });

  testWidgets('mushroom wheel stack opens a swipeable selector',(tester)async{
    tester.view.physicalSize=const Size(390,844);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    await openWheel(tester);
    expect(find.textContaining('Bouw'),findsOneWidget);
    await tester.tap(find.textContaining('Bouw'));
    await tester.pumpAndSettle();
    expect(find.text('Veeg links/rechts · centreer de observatie'),findsOneWidget);
    expect(find.text('Selecteer deze observatie'),findsOneWidget);
    expect(find.text('Vorm vruchtlichaam'),findsWidgets);
    expect(find.text('Veeg links/rechts · centreer de observatie'),findsOneWidget);
    expect(find.text('Selecteer deze observatie'),findsOneWidget);
    expect(tester.takeException(),isNull);
  });

  testWidgets('unreached observations stay out of popped wheels',(tester)async{
    tester.view.physicalSize=const Size(390,844);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    await openWheel(tester);
    await tester.tap(find.textContaining('Bouw'));
    await tester.pumpAndSettle();
    expect(find.text('Vorm vruchtlichaam'),findsWidgets);
    expect(find.text('Sporenvormende onderzijde'),findsNothing);
  });

  testWidgets('possibilities are a fifth live wheel',(tester)async{
    tester.view.physicalSize=const Size(390,844);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    await openWheel(tester);
    expect(find.text('Mogelijkheden'),findsOneWidget);
    await tester.tap(find.text('Mogelijkheden'));
    await tester.pumpAndSettle();
    expect(find.textContaining('mogelijkheden'),findsWidgets);
    expect(find.textContaining('Geen waarschijnlijkheden.'),findsOneWidget);
    expect(tester.takeException(),isNull);
  });

  testWidgets('five cap spots represent the determination wheels',(tester)async{
    tester.view.physicalSize=const Size(390,844);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    await openWheel(tester);
    for(var i=0;i<5;i++){expect(find.byKey(ValueKey('cap-dot-'+i.toString())),findsOneWidget);}
    await tester.tap(find.byKey(const ValueKey('cap-dot-4')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Geen waarschijnlijkheden.'),findsOneWidget);
  });

  testWidgets('swiping a wheel does not select until explicitly confirmed',(tester)async{
    tester.view.physicalSize=const Size(390,844);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    await openWheel(tester);
    await tester.tap(find.text('Hoed + steel'));await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Bouw'));await tester.pumpAndSettle();
    await tester.drag(find.byKey(const ValueKey('observation-wheel')),const Offset(260,0));await tester.pumpAndSettle();
    expect(find.text('Selecteer deze observatie'),findsOneWidget);
    expect(find.byKey(const ValueKey('select-centered-observation')),findsOneWidget);
    expect(find.text('Sporenvormende onderzijde'),findsWidgets);
    await tester.tap(find.byKey(const ValueKey('select-centered-observation')));await tester.pumpAndSettle();
    expect(find.text('Hoed + steel'),findsWidgets);
  });

  testWidgets('changing an earlier observation discards downstream answers',(tester)async{
    tester.view.physicalSize=const Size(390,844);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    await openWheel(tester);
    await tester.tap(find.text('Hoed + steel'));await tester.pumpAndSettle();
    await tester.tap(find.text('Plaatjes'));await tester.pumpAndSettle();
    expect(find.textContaining('Hoedoppervlak'),findsWidgets);
    await tester.tap(find.textContaining('Bouw'));await tester.pumpAndSettle();
    await tester.drag(find.byKey(const ValueKey('observation-wheel')),const Offset(260,0));await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('select-centered-observation')));await tester.pumpAndSettle();
    await tester.tap(find.text('Bol-/buikvormig'));await tester.pumpAndSettle();
    expect(find.textContaining('Vindplaats'),findsWidgets);
    expect(find.text('Hoedoppervlak'),findsNothing);
  });

  testWidgets('mushroom cap shows and opens the live outcome',(tester)async{
    tester.view.physicalSize=const Size(390,844);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    await openWheel(tester);
    expect(find.textContaining('mogelijkheden · Vorm vruchtlichaam'),findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mushroom-cap')));await tester.pumpAndSettle();
    expect(find.textContaining('Op basis van de observaties tot nu toe.'),findsOneWidget);
    expect(find.textContaining('Geen waarschijnlijkheden.'),findsOneWidget);
  });

  testWidgets('cap spots reopen reached wheels but not unreached observations',(tester)async{
    tester.view.physicalSize=const Size(390,844);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    await openWheel(tester);
    await tester.tap(find.byKey(const ValueKey('cap-dot-0')));await tester.pumpAndSettle();
    expect(find.text('Bouw'),findsWidgets);
    expect(find.text('Selecteer deze observatie'),findsOneWidget);
    Navigator.of(tester.element(find.byType(_WheelSelectorSheet))).pop();await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cap-dot-2')));await tester.pumpAndSettle();
    expect(find.text('Selecteer deze observatie'),findsNothing);
  });

}
