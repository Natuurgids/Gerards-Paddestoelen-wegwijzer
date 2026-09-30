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
    test('unsupported Amanita details do not hard-exclude the possibility',(){
      final result=determine({1:'Hoed + steel',4:'Plaatjes',6:'Aangehecht',7:'Geen zichtbaar',9:'Roze'});
      expect(result.remaining.map((c)=>c.name),contains('Amanieten · Amanita'));
    });
    test('unsupported Armillaria spore colour does not hard-exclude the possibility',(){
      final result=determine({1:'Hoed + steel',4:'Plaatjes',9:'Roze'});
      expect(result.remaining.map((c)=>c.name),contains('Honingzwammen · Armillaria'));
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
    test('parasol group keeps categorical traits without requiring a ring',(){
      final ringless=determine({5:'Schubbig / wrattig',6:'Vrij',9:'Roze',17:'Bodem / strooisel'});
      expect(ringless.remaining.map((c)=>c.name),contains('Parasolzwammen (+)'));
      final attached=determine({5:'Glad',6:'Aangehecht',9:'Wit / crème',17:'Bodem / strooisel'});
      expect(attached.remaining.map((c)=>c.name),isNot(contains('Parasolzwammen (+)')));
      final wood=determine({5:'Glad',6:'Vrij',9:'Wit / crème',17:'Dood hout'});
      expect(wood.remaining.map((c)=>c.name),isNot(contains('Parasolzwammen (+)')));
    });
    test('bolete profile stays source-bounded to cap/stem and pores',(){
      final possible=determine({1:'Hoed + steel',4:'Buisjes / poriën',9:'Purperbruin / donker'});
      expect(possible.remaining.map((c)=>c.name),contains('Boleten'));
      final gills=determine({1:'Hoed + steel',4:'Plaatjes'});
      expect(gills.remaining.map((c)=>c.name),isNot(contains('Boleten')));
      final otherForm=determine({1:'Andere vorm',4:'Buisjes / poriën'});
      expect(otherForm.remaining.map((c)=>c.name),isNot(contains('Boleten')));
    });
    test('Cantharellus uses the source-backed pale spore criterion',(){
      final possible=determine({1:'Hoed + steel',4:'Plooien / ribben',9:'Wit / crème'});
      expect(possible.remaining.map((c)=>c.name),contains('Cantharellen · Cantharellus'));
      final darkSpores=determine({1:'Hoed + steel',4:'Plooien / ribben',9:'Bruin / roest'});
      expect(darkSpores.remaining.map((c)=>c.name),isNot(contains('Cantharellen · Cantharellus')));
      final unknown=determine({1:'Hoed + steel',4:'Plooien / ribben',9:'Onzeker'});
      expect(unknown.remaining.map((c)=>c.name),contains('Cantharellen · Cantharellus'));
    });
    test('Krulzomen use the source-backed medium-to-large size criterion',(){
      final medium=determine({6:'Aflopend',9:'Bruin / roest',19:'Middelgroot',23:'Verkleurt bij druk/wrijven'});
      expect(medium.remaining.map((c)=>c.name),contains('Krulzomen · Paxillus/Tapinella'));
      final large=determine({6:'Aflopend',9:'Bruin / roest',19:'Groot',23:'Verkleurt bij druk/wrijven'});
      expect(large.remaining.map((c)=>c.name),contains('Krulzomen · Paxillus/Tapinella'));
      final small=determine({6:'Aflopend',9:'Bruin / roest',19:'Klein',23:'Verkleurt bij druk/wrijven'});
      expect(small.remaining.map((c)=>c.name),isNot(contains('Krulzomen · Paxillus/Tapinella')));
    });
    test('Pluteus keeps categorical free-gill, no-velum and pink-spore criteria',(){
      final possible=determine({4:'Plaatjes',6:'Vrij',7:'Geen zichtbaar',9:'Roze',17:'Bodem / strooisel'});
      expect(possible.remaining.map((c)=>c.name),contains('Hertenzwammen · Pluteus'));
      final pores=determine({4:'Buisjes / poriën',6:'Vrij',7:'Geen zichtbaar',9:'Roze'});
      expect(pores.remaining.map((c)=>c.name),isNot(contains('Hertenzwammen · Pluteus')));
      final ringed=determine({6:'Vrij',7:'Ring',9:'Roze'});
      expect(ringed.remaining.map((c)=>c.name),isNot(contains('Hertenzwammen · Pluteus')));
      final attached=determine({6:'Aangehecht',7:'Geen zichtbaar',9:'Roze'});
      expect(attached.remaining.map((c)=>c.name),isNot(contains('Hertenzwammen · Pluteus')));
    });
    test('Omphalina/Rickenella keeps categorical funnel-group criteria',(){
      final possible=determine({4:'Plaatjes',6:'Aflopend',7:'Geen zichtbaar',9:'Wit / crème',17:'Dood hout',19:'Klein'});
      expect(possible.remaining.map((c)=>c.name),contains('Trechtertjes · Omphalina/Rickenella'));
      final pores=determine({4:'Buisjes / poriën',6:'Aflopend',7:'Geen zichtbaar',9:'Wit / crème',19:'Klein'});
      expect(pores.remaining.map((c)=>c.name),isNot(contains('Trechtertjes · Omphalina/Rickenella')));
      final ringed=determine({6:'Aflopend',7:'Ring',9:'Wit / crème',19:'Klein'});
      expect(ringed.remaining.map((c)=>c.name),isNot(contains('Trechtertjes · Omphalina/Rickenella')));
      final attached=determine({6:'Aangehecht',7:'Geen zichtbaar',9:'Wit / crème',19:'Klein'});
      expect(attached.remaining.map((c)=>c.name),isNot(contains('Trechtertjes · Omphalina/Rickenella')));
    });
    test('waxcap/slimy-cap group uses only categorical size and white-spore criteria',(){
      final possible=determine({7:'Ring',9:'Wit / crème',19:'Middelgroot'});
      expect(possible.remaining.map((c)=>c.name),contains('Wasplaten / Slijmkoppen'));
      final darkSpores=determine({9:'Purperbruin / donker',19:'Middelgroot'});
      expect(darkSpores.remaining.map((c)=>c.name),isNot(contains('Wasplaten / Slijmkoppen')));
      final tooLarge=determine({9:'Wit / crème',19:'Groot'});
      expect(tooLarge.remaining.map((c)=>c.name),isNot(contains('Wasplaten / Slijmkoppen')));
    });
    test('Pleurotus keeps its categorical no-velum, decurrent-gill and pale-spore criteria',(){
      final possible=determine({4:'Plaatjes',6:'Aflopend',7:'Geen zichtbaar',9:'Wit / crème'});
      expect(possible.remaining.map((c)=>c.name),contains('Oesterzwammen · Pleurotus'));
      final ringed=determine({4:'Plaatjes',6:'Aflopend',7:'Ring',9:'Wit / crème'});
      expect(ringed.remaining.map((c)=>c.name),isNot(contains('Oesterzwammen · Pleurotus')));
      final attached=determine({4:'Plaatjes',6:'Aangehecht',7:'Geen zichtbaar',9:'Wit / crème'});
      expect(attached.remaining.map((c)=>c.name),isNot(contains('Oesterzwammen · Pleurotus')));
    });
    test('Stropharia keeps variable velum while filtering on purple spore print',(){
      final withVelum=determine({7:'Ring',9:'Purperbruin / donker'});
      expect(withVelum.remaining.map((c)=>c.name),contains('Kaalkopjes / Stropharia (+)'));
      final withoutVelum=determine({7:'Geen zichtbaar',9:'Purperbruin / donker'});
      expect(withoutVelum.remaining.map((c)=>c.name),contains('Kaalkopjes / Stropharia (+)'));
      final conflict=determine({9:'Wit / crème'});
      expect(conflict.remaining.map((c)=>c.name),isNot(contains('Kaalkopjes / Stropharia (+)')));
    });
    test('Taailingen hard criteria match the categorical source profile',(){
      final possible=determine({7:'Geen zichtbaar',9:'Wit / crème',19:'Middelgroot'});
      expect(possible.remaining.map((c)=>c.name),contains('Taailingen (+)'));
      final withVelum=determine({7:'Ring',9:'Wit / crème',19:'Middelgroot'});
      expect(withVelum.remaining.map((c)=>c.name),isNot(contains('Taailingen (+)')));
      final tooLarge=determine({7:'Geen zichtbaar',9:'Wit / crème',19:'Groot'});
      expect(tooLarge.remaining.map((c)=>c.name),isNot(contains('Taailingen (+)')));
    });
    test('Galerina keeps categorical size and spore criteria but not variable ecology',(){
      final possible=determine({4:'Plaatjes',7:'Ring',9:'Bruin / roest',17:'Dood hout',19:'Klein'});
      expect(possible.remaining.map((c)=>c.name),contains('Mosklokjes · Galerina'));
      final pores=determine({4:'Buisjes / poriën',9:'Bruin / roest',19:'Klein'});
      expect(pores.remaining.map((c)=>c.name),isNot(contains('Mosklokjes · Galerina')));
      final conflict=determine({9:'Bruin / roest',19:'Groot'});
      expect(conflict.remaining.map((c)=>c.name),isNot(contains('Mosklokjes · Galerina')));
    });
    test('Agrocybe is filtered by spore colour, not its usual velum or substrate',(){
      final possible=determine({7:'Beurs / volva',9:'Bruin / roest',17:'Dood hout'});
      expect(possible.remaining.map((c)=>c.name),contains('Leemhoeden · Agrocybe'));
      final conflict=determine({9:'Wit / crème'});
      expect(conflict.remaining.map((c)=>c.name),isNot(contains('Leemhoeden · Agrocybe')));
    });
    test('Hebeloma keeps its categorical no-velum and brown-spore source criteria',(){
      final matching=determine({4:'Plaatjes',7:'Geen zichtbaar',9:'Bruin / roest'});
      expect(matching.remaining.map((c)=>c.name),contains('Vaalhoeden · Hebeloma'));
      final pores=determine({4:'Buisjes / poriën',7:'Geen zichtbaar',9:'Bruin / roest'});
      expect(pores.remaining.map((c)=>c.name),isNot(contains('Vaalhoeden · Hebeloma')));
      final conflicting=determine({7:'Ring',9:'Bruin / roest'});
      expect(conflicting.remaining.map((c)=>c.name),isNot(contains('Vaalhoeden · Hebeloma')));
    });
    test('Pholiota is not excluded by a velum observation because the source says often',(){
      final result=determine({6:'Aangehecht',7:'Beurs / volva',9:'Bruin / roest'});
      expect(result.remaining.map((c)=>c.name),contains('Bundelzwammen (+) · Pholiota/Kuehneromyces'));
    });
    test('Parasol profile keeps source-listed pale pink spores and does not require its typical ring',(){
      final result=determine({5:'Glad',6:'Vrij',9:'Roze',17:'Bodem / strooisel'});
      expect(result.remaining.map((c)=>c.name),contains('Parasolzwammen (+)'));
    });
    test('Laccaria hard criteria are all explicit in the supplied source profile',(){
      final matching=determine({4:'Plaatjes',7:'Geen zichtbaar',8:'Ja',9:'Wit / crème',19:'Klein'});
      expect(matching.remaining.map((c)=>c.name),contains('Fopzwammen · Laccaria'));
      final nonGilled=determine({4:'Buisjes / poriën',7:'Geen zichtbaar',8:'Ja',9:'Wit / crème',19:'Klein'});
      expect(nonGilled.remaining.map((c)=>c.name),isNot(contains('Fopzwammen · Laccaria')));
      final conflicting=determine({8:'Nee'});
      expect(conflicting.remaining.map((c)=>c.name),isNot(contains('Fopzwammen · Laccaria')));
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
    test('unsupported Russulaceae spore and substrate details do not hard-exclude it',(){
      final result=determine({9:'Roze',17:'Dood hout',23:'Broos / breekt krijtachtig'});
      expect(result.remaining.map((c)=>c.name),contains('Russulaceae · Russula/Lactarius'));
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
      final result=determine({23:'Vlezig / vezelig',22:'Melksap aanwezig'});
      expect(result.remaining.map((c)=>c.name),isNot(contains('Russulaceae · Russula/Lactarius')));
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
    expect(score.unanswered,1);
  });
  test('match score is descriptive rather than a probability',(){
    final bolete=candidates.firstWhere((c)=>c.name=='Boleten');
    final score=bolete.score({1:'Hoed + steel'});
    expect(score.percent,100);
    expect(score.unknown,0);
    expect(score.unanswered,1);
    expect(score.label,contains('1 nog niet gevraagd'));
  });

  test('remaining possibilities are ranked by matching evidence',(){
    final result=determine({1:'Hoed + steel',4:'Plaatjes',6:'Vrij',7:'Geen zichtbaar',9:'Roze'});
    expect(result.remaining.first.name,'Hertenzwammen · Pluteus');
    expect(result.remaining.first.score({1:'Hoed + steel',4:'Plaatjes',6:'Vrij',7:'Geen zichtbaar',9:'Roze'}).percent,100);
  });

  test('explicit uncertainty is distinct from an unanswered criterion',(){
    final pluteus=candidates.firstWhere((c)=>c.name.contains('Pluteus'));
    final score=pluteus.score({4:'Plaatjes',6:'Onzeker'});
    expect(score.unknown,1);
    expect(score.unanswered,3);
    expect(score.label,contains('1 onzeker'));
    expect(score.label,contains('3 nog niet gevraagd'));
  });

  test('coverage exposes how much relevant evidence has been assessed',(){
    final pluteus=candidates.firstWhere((c)=>c.name.contains('Pluteus'));
    final score=pluteus.score({4:'Plaatjes',6:'Vrij'});
    expect(score.percent,100);
    expect(score.assessed,2);
    expect(score.relevant,5);
    expect(score.coverage,closeTo(2/5,.0001));
    expect(score.label,contains('40% dekking'));
  });
  test('equal matches rank by positive evidence, not merely coverage',(){
    const sparse=Candidate('Sparse',spore:{'Roze'});
    const supported=Candidate('Supported',spore:{'Roze'},gill:{'Vrij'},velum:{'Geen zichtbaar'});
    final answers={6:'Vrij',7:'Geen zichtbaar',9:'Roze'};
    final ranked=<Candidate>[sparse,supported];
    rankCandidates(ranked,answers);
    expect(sparse.score(answers).percent,100);
    expect(sparse.score(answers).coverage,1);
    expect(supported.score(answers).percent,100);
    expect(ranked.first.name,'Supported');
  });

  test('complete only means every coded criterion was assessed',(){
    final pluteus=candidates.firstWhere((c)=>c.name.contains('Pluteus'));
    expect(pluteus.score({4:'Plaatjes',6:'Vrij',7:'Geen zichtbaar',9:'Roze',19:'Middelgroot'}).complete,isTrue);
    expect(pluteus.score({4:'Plaatjes',6:'Vrij',7:'Onzeker',9:'Roze',19:'Middelgroot'}).complete,isTrue);
    expect(pluteus.score({4:'Plaatjes',6:'Vrij',9:'Roze'}).complete,isFalse);
  });

  test('Agrocybe keeps categorical smooth cap and gilled underside',(){
    final possible=determine({4:'Plaatjes',5:'Glad',9:'Bruin / roest'});
    expect(possible.remaining.map((c)=>c.name),contains('Leemhoeden · Agrocybe'));
    final scaly=determine({4:'Plaatjes',5:'Schubbig / wrattig',9:'Bruin / roest'});
    expect(scaly.remaining.map((c)=>c.name),isNot(contains('Leemhoeden · Agrocybe')));
    final pores=determine({4:'Buisjes / poriën',5:'Glad',9:'Bruin / roest'});
    expect(pores.remaining.map((c)=>c.name),isNot(contains('Leemhoeden · Agrocybe')));
  });

  test('Pholiota profile keeps categorical gill and cap-surface traits',(){
    final possible=determine({4:'Plaatjes',5:'Schubbig / wrattig',6:'Aangehecht',9:'Bruin / roest'});
    expect(possible.remaining.map((c)=>c.name),contains('Bundelzwammen (+) · Pholiota/Kuehneromyces'));
    final fibrous=determine({4:'Plaatjes',5:'Vezelig',6:'Aangehecht',9:'Bruin / roest'});
    expect(fibrous.remaining.map((c)=>c.name),isNot(contains('Bundelzwammen (+) · Pholiota/Kuehneromyces')));
    final pores=determine({4:'Buisjes / poriën',5:'Glad',6:'Aangehecht',9:'Bruin / roest'});
    expect(pores.remaining.map((c)=>c.name),isNot(contains('Bundelzwammen (+) · Pholiota/Kuehneromyces')));
  });

  test('Stropharia group requires gilled underside but not velum',(){
    final ringless=determine({4:'Plaatjes',7:'Geen zichtbaar',9:'Purperbruin / donker'});
    expect(ringless.remaining.map((c)=>c.name),contains('Kaalkopjes / Stropharia (+)'));
    final pores=determine({4:'Buisjes / poriën',9:'Purperbruin / donker'});
    expect(pores.remaining.map((c)=>c.name),isNot(contains('Kaalkopjes / Stropharia (+)')));
  });

  test('waxcap/slimy-cap profile requires gills and source-listed cap surfaces',(){
    final possible=determine({4:'Plaatjes',5:'Kleverig / slijmerig',9:'Wit / crème',19:'Middelgroot'});
    expect(possible.remaining.map((c)=>c.name),contains('Wasplaten / Slijmkoppen'));
    final fibrous=determine({4:'Plaatjes',5:'Vezelig',9:'Wit / crème',19:'Middelgroot'});
    expect(fibrous.remaining.map((c)=>c.name),isNot(contains('Wasplaten / Slijmkoppen')));
    final pores=determine({4:'Buisjes / poriën',5:'Glad',9:'Wit / crème',19:'Middelgroot'});
    expect(pores.remaining.map((c)=>c.name),isNot(contains('Wasplaten / Slijmkoppen')));
  });

  test('toughshank group is gilled without making toughness mandatory',(){
    final possible=determine({4:'Plaatjes',7:'Geen zichtbaar',9:'Wit / crème',19:'Klein',23:'Vlezig / vezelig'});
    expect(possible.remaining.map((c)=>c.name),contains('Taailingen (+)'));
    final pores=determine({4:'Buisjes / poriën',7:'Geen zichtbaar',9:'Wit / crème',19:'Klein'});
    expect(pores.remaining.map((c)=>c.name),isNot(contains('Taailingen (+)')));
  });

  test('Pleurotus source allows the full small-to-large size range',(){
    for(final size in ['Klein','Middelgroot','Groot']){
      final result=determine({4:'Plaatjes',6:'Aflopend',7:'Geen zichtbaar',9:'Wit / crème',19:size});
      expect(result.remaining.map((c)=>c.name),contains('Oesterzwammen · Pleurotus'),reason:'source explicitly allows $size');
    }
  });

  test('Pluteus source allows the full small-to-large size range',(){
    for(final size in ['Klein','Middelgroot','Groot']){
      final result=determine({4:'Plaatjes',6:'Vrij',7:'Geen zichtbaar',9:'Roze',19:size});
      expect(result.remaining.map((c)=>c.name),contains('Hertenzwammen · Pluteus'),reason:'source explicitly allows $size');
    }
  });

}
