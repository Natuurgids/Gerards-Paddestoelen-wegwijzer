import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mushroom_determination_wheel/main.dart';

void main(){
  testWidgets('non-plate underside routes show live possibilities',(tester)async{
    await tester.pumpWidget(const App());
    await tester.tap(find.text('Hoed + steel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buisjes / poriën'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Mogelijke groepen:'),findsOneWidget);
    expect(find.textContaining('Boleten'),findsWidgets);
  });

  testWidgets('back removes the latest observation',(tester)async{
    await tester.pumpWidget(const App());
    await tester.tap(find.text('Hoed + steel'));
    await tester.pumpAndSettle();
    expect(find.text('Sporenvormende onderzijde'),findsWidgets);

    await tester.tap(find.byTooltip('Vorige observatie'));
    await tester.pumpAndSettle();
    expect(find.text('Vorm vruchtlichaam'),findsWidgets);
  });

  testWidgets('live possibilities expose match and evidence coverage',(tester)async{
    await tester.pumpWidget(const App());
    await tester.tap(find.text('Hoed + steel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plaatjes'));
    await tester.pumpAndSettle();

    expect(find.textContaining('% dekking'),findsWidgets);
    expect(find.textContaining('Mogelijke groepen:'),findsOneWidget);
  });

}
