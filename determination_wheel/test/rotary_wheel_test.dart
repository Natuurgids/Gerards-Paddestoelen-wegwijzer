import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mushroom_determination_wheel/main.dart';
import 'package:mushroom_determination_wheel/photographic_rotary_wheel.dart';
import 'package:mushroom_determination_wheel/wheel_steps.dart';

void main() {
  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize=const Size(390,844);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const App(skipSplash:true));await tester.pumpAndSettle();
  }
  PhotographicRotaryWheel wheel(WidgetTester tester)=>tester.widget(find.byType(PhotographicRotaryWheel));
  Future<void> pick(WidgetTester tester, String label) async {
    final index=wheel(tester).current.options.indexWhere((o)=>o.label==label);
    expect(index,greaterThanOrEqualTo(0));
    await tester.tap(find.byKey(ValueKey('choice-sector-$index')));await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-top-choice')));await tester.pumpAndSettle();
  }
  testWidgets('choice tap brings it to the pointer without recording an answer', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('choice-sector-1')));await tester.pumpAndSettle();
    expect(wheel(tester).reached,[1]);
    expect(find.descendant(of:find.byKey(const ValueKey('confirm-top-choice')),matching:find.text('Bol-/buikvormig')),findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirm-top-choice')));await tester.pumpAndSettle();
    expect(wheel(tester).reached,[1,15]);
  });
  testWidgets('clockwise quarter turn snaps the outer ring and confirmation follows the top choice', (tester) async {
    await open(tester);
    final rect=tester.getRect(find.byKey(const ValueKey('choice-dial')));
    final center=rect.center,r=rect.width*.44;
    final gesture=await tester.startGesture(center+Offset(0,-r));
    for(var i=1;i<=12;i++) {
      final a=-math.pi/2+i*math.pi/24;
      await gesture.moveTo(center+Offset(math.cos(a)*r,math.sin(a)*r));await tester.pump();
    }
    await gesture.up();await tester.pumpAndSettle();
    expect(wheel(tester).reached,[1]);
    expect(find.descendant(of:find.byKey(const ValueKey('confirm-top-choice')),matching:find.text('Andere vorm')),findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirm-top-choice')));await tester.pumpAndSettle();
    expect(wheel(tester).reached,[1,15]);
  });
  testWidgets('revisiting an inner-ring observation requires confirmation and removes downstream answers', (tester) async {
    await open(tester);await pick(tester,'Hoed + steel');await pick(tester,'Plaatjes');
    expect(wheel(tester).reached,[1,4,5]);
    // Accessible decrement rotates the inner ring independently.
    final dial=find.descendant(of:find.byKey(const ValueKey('observation-dial')),matching:find.byType(Semantics)).first;
    expect(tester.widget<Semantics>(dial).properties.value,'Hoedoppervlak');
    expect(tester.widget<Semantics>(dial).properties.decreasedValue,'Sporenvormende onderzijde');
    tester.widget<Semantics>(dial).properties.onDecrease!();await tester.pumpAndSettle();
    tester.widget<Semantics>(dial).properties.onDecrease!();await tester.pumpAndSettle();
    expect(wheel(tester).reached,[1,4,5]);
    await tester.tap(find.byKey(const ValueKey('confirm-top-observation')));await tester.pumpAndSettle();
    expect(wheel(tester).reached,[1]);
    await pick(tester,'Bol-/buikvormig');
    expect(wheel(tester).reached,[1,15]);
    await tester.tap(find.byTooltip('Vorige observatie'));await tester.pumpAndSettle();
    expect(wheel(tester).reached,[1]);
  });
  testWidgets('arrow controls rotate choices and reset restores the initial dial', (tester) async {
    await open(tester);
    await tester.tap(find.byTooltip('Volgende keuze'));await tester.pumpAndSettle();
    expect(wheel(tester).reached,[1]);
    await tester.tap(find.byKey(const ValueKey('confirm-top-choice')));await tester.pumpAndSettle();
    expect(wheel(tester).reached,[1,15]);
    await tester.tap(find.byTooltip('Nieuwe determinatie'));await tester.pumpAndSettle();
    expect(wheel(tester).reached,[1]);
  });
  testWidgets('circular selection preserves the complete lamella determination route', (tester) async {
    await open(tester);
    for(final label in ['Hoed + steel','Plaatjes','Glad','Onzeker','Geen zichtbaar','Onzeker','Wit / crème','Ga verder met veldkenmerken','Bos','Loofboom','Bodem / strooisel','Groepjes','Niet gemeten / onzeker','Bruin','Niet beoordeeld','Niet beoordeeld','Onzeker']) {
      await pick(tester,label);
    }
    expect(wheel(tester).current,wheelSteps[24]);
    await pick(tester,'Toon eindresultaat');
    expect(find.byType(PhotographicRotaryWheel),findsNothing);
    expect(find.text('Nieuwe determinatie'),findsOneWidget);
  });
}
