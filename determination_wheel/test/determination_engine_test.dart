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
    test('source-backed size observations participate in filtering',(){
      final result=determine({9:'Wit / crème',19:'Groot'});
      expect(result.remaining.map((c)=>c.name),isNot(contains('Fopzwammen · Laccaria')));
      expect(result.remaining.map((c)=>c.name),isNot(contains('Trechtertjes · Omphalina/Rickenella')));
      expect(result.remaining.map((c)=>c.name),isNot(contains('Taailingen (+)')));
    });
    test('source-backed trama observation supports Russulaceae',(){
      final result=determine({9:'Wit / crème',17:'Bodem / strooisel',23:'Broos / breekt krijtachtig'});
      final candidate=result.remaining.firstWhere((c)=>c.name.startsWith('Russulaceae'));
      expect(candidate.supporting({9:'Wit / crème',17:'Bodem / strooisel',23:'Broos / breekt krijtachtig'}),contains('trama / vlees: Broos / breekt krijtachtig'));
    });
    test('supporting evidence only reports matching observed criteria',(){
      final pluteus=candidates.firstWhere((c)=>c.name.contains('Pluteus'));
      expect(pluteus.supporting({6:'Vrij',9:'Roze',17:'Dood hout'}),containsAll(['lamellen: Vrij','sporenkleur: Roze']));
      expect(pluteus.supporting({6:'Onzeker',9:'Roze'}),isNot(contains('lamellen: Onzeker')));
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
  test('match score uses assessed evidence and ignores unknown answers',(){
    final pluteus=candidates.firstWhere((c)=>c.name.contains('Pluteus'));
    final score=pluteus.score({4:'Plaatjes',6:'Vrij',7:'Onzeker',9:'Roze'});
    expect(score.percent,100);
    expect(score.matched,3);
    expect(score.observed,3);
    expect(score.unknown,1);
  });
  test('match score is descriptive rather than a probability',(){
    final bolete=candidates.firstWhere((c)=>c.name=='Boleten');
    final score=bolete.score({1:'Hoed + steel'});
    expect(score.percent,100);
    expect(score.unknown,1);
    expect(score.label,contains('1 onbekend'));
  });

  test('remaining possibilities are ranked by matching evidence',(){
    final result=determine({1:'Hoed + steel',4:'Plaatjes',6:'Vrij',7:'Geen zichtbaar',9:'Roze'});
    expect(result.remaining.first.name,'Hertenzwammen · Pluteus');
    expect(result.remaining.first.score({1:'Hoed + steel',4:'Plaatjes',6:'Vrij',7:'Geen zichtbaar',9:'Roze'}).percent,100);
  });

}
