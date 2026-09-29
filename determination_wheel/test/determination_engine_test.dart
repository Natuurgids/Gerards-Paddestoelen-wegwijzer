import 'package:flutter_test/flutter_test.dart';
import 'package:mushroom_determination_wheel/determination_engine.dart';

void main(){
  group('source-grounded candidate filtering',(){
    test('underside routes keep bolete and plate groups separated',(){
      final pores=determine({1:'Hoed + steel',4:'Buisjes / poriën'});
      expect(pores.remaining.map((c)=>c.name),contains('Boleten'));
      expect(pores.remaining.where((c)=>c.underside?.contains('Plaatjes')??false),isEmpty);
      final plates=determine({1:'Hoed + steel',4:'Plaatjes'});
      expect(plates.remaining.map((c)=>c.name),isNot(contains('Boleten')));
    });
    test('Amanita profile accepts its currently encoded velum observations',(){
      final result=determine({1:'Hoed + steel',4:'Plaatjes',6:'Vrij',7:'Beide',9:'Wit / crème'});
      expect(result.remaining.map((c)=>c.name),contains('Amanieten · Amanita'));
    });
    test('pink spores + free gills + no visible velum retains Pluteus',(){
      final result=determine({5:'Glad',6:'Vrij',7:'Geen zichtbaar',9:'Roze',17:'Dood hout'});
      expect(result.remaining.map((c)=>c.name),contains('Hertenzwammen · Pluteus'));
    });
    test('white spores exclude Pluteus with an explicit reason',(){
      final result=determine({9:'Wit / crème'});
      final entry=result.excluded.entries.firstWhere((e)=>e.key.name.contains('Pluteus'));
      expect(entry.value,contains('sporenkleur'));
      expect(entry.value,contains('Roze'));
    });
    test('unknown observations never exclude candidates',(){
      final result=determine({6:'Onzeker',7:'Onzeker',9:'Onzeker',17:'Onzeker'});
      expect(result.remaining.length,candidates.length);
      expect(result.excluded,isEmpty);
    });
    test('typical ecology is not treated as a hard exclusion',(){
      for(final fragment in ['Pluteus','Galerina','Hebeloma','Agrocybe','Laccaria','Pholiota','Armillaria']){
        final result=determine({17:'Mest / rijk organisch materiaal'});
        expect(result.remaining.map((c)=>c.name).where((name)=>name.contains(fragment)),isNotEmpty,
          reason:'$fragment must not be excluded solely by a non-typical substrate');
      }
    });
    test('milk supports Lactarius only when Russulaceae remains',(){
      final result=determine({9:'Wit / crème',17:'Bodem / strooisel',22:'Melksap aanwezig'});
      expect(result.genusHint,'Lactarius');
    });
    test('no milk supports Russula only when Russulaceae remains',(){
      final result=determine({9:'Wit / crème',17:'Bodem / strooisel',22:'Geen melksap'});
      expect(result.genusHint,'Russula');
    });
    test('milk does not produce genus hint when Russulaceae was excluded',(){
      final result=determine({9:'Roze',17:'Dood hout',22:'Melksap aanwezig'});
      expect(result.genusHint,isNull);
    });
  });
}
