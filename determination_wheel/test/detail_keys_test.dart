import 'package:flutter_test/flutter_test.dart';
import 'package:mushroom_determination_wheel/detail_keys.dart';
import 'package:mushroom_determination_wheel/source_catalog.dart';

void main(){
  test('single supported candidates receive a source-backed detail key',(){
    expect(detailKeyFor(candidateNames:['Schelpzwammen'])?.id,'shell');
    expect(detailKeyFor(candidateNames:['Parasolzwammen (+)'])?.id,'parasol');
    expect(detailKeyFor(candidateNames:['Fopzwammen · Laccaria'])?.id,'laccaria');
    expect(detailKeyFor(candidateNames:['Hertenzwammen · Pluteus'])?.id,'pluteus');
    expect(detailKeyFor(candidateNames:['Oesterzwammen · Pleurotus'])?.id,'pleurotus');
    expect(detailKeyFor(candidateNames:['Wasplaten / Slijmkoppen'])?.id,'waxcaps');
    expect(detailKeyFor(candidateNames:['Trechtertjes · Omphalina/Rickenella'])?.id,'funnel');
    expect(detailKeyFor(candidateNames:['Taailingen (+)'])?.id,'toughshanks');
    expect(detailKeyFor(candidateNames:['Bundelzwammen (+) · Pholiota/Kuehneromyces'])?.id,'pholiota');
    expect(detailKeyFor(candidateNames:['Kaalkopjes / Stropharia (+)'])?.id,'stropharia');
    expect(detailKeyFor(candidateNames:['Krulzomen · Paxillus/Tapinella'])?.id,'paxillus');
    expect(detailKeyFor(candidateNames:['Cantharellen · Cantharellus'])?.id,'cantharellus');
  });
  test('every supported single candidate maps to its intended detail key',(){
    const expected=<String,String>{
      'Schelpzwammen':'shell',
      'Oesterzwammen · Pleurotus':'pleurotus',
      'Krulzomen · Paxillus/Tapinella':'paxillus',
      'Cantharellen · Cantharellus':'cantharellus',
      'Parasolzwammen (+)':'parasol',
      'Fopzwammen · Laccaria':'laccaria',
      'Wasplaten / Slijmkoppen':'waxcaps',
      'Trechtertjes · Omphalina/Rickenella':'funnel',
      'Taailingen (+)':'toughshanks',
      'Hertenzwammen · Pluteus':'pluteus',
      'Bundelzwammen (+) · Pholiota/Kuehneromyces':'pholiota',
      'Kaalkopjes / Stropharia (+)':'stropharia',
      'Mosklokjes · Galerina':'galerina',
      'Vaalhoeden · Hebeloma':'hebeloma',
      'Leemhoeden · Agrocybe':'agrocybe',
    };
    for(final entry in expected.entries){
      expect(detailKeyFor(candidateNames:[entry.key])?.id,entry.value,reason:entry.key);
    }
  });
  test('unsupported single candidates do not receive a detail key',(){
    const unsupported=[
      'Boleten',
      'Amanieten · Amanita',
      'Honingzwammen · Armillaria',
    ];
    for(final name in unsupported){
      expect(detailKeyFor(candidateNames:[name]),isNull,reason:name);
    }
  });
  test('detail keys require an exact supported candidate identity',(){
    expect(detailKeyFor(candidateNames:['Andere groep · Galerina-achtig']),isNull);
    expect(detailKeyFor(candidateNames:['Pleurotus look-alike']),isNull);
  });
  test('Galerina detail key does not exclude another substrate',(){
    final step=galerinaDetailKey.steps['substrate']!;
    final option=step.options.firstWhere((o)=>o.label=='Andere groeiplaats');
    expect(option.result,'Galerina-kandidaat; ecologie niet doorslaggevend');
  });
  test('ambiguous candidate sets do not pretend to have a detail key',(){
    expect(detailKeyFor(candidateNames:['Hertenzwammen · Pluteus','Mosklokjes · Galerina']),isNull);
  });
  test('Russulaceae genus hint takes precedence',(){
    expect(detailKeyFor(genusHint:'Lactarius',candidateNames:['Russulaceae · Russula/Lactarius'])?.id,'russulaceae');
  });
  test('Russulaceae detail key requires an explicit supported genus hint',(){
    expect(detailKeyFor(candidateNames:['Russulaceae · Russula/Lactarius']),isNull);
    expect(detailKeyFor(genusHint:'Onzeker',candidateNames:['Russulaceae · Russula/Lactarius']),isNull);
  });
  test('Schelpzwammen follow-up uses stem attachment, not underside exclusion',(){
    final step=shellDetailKey.steps['stem']!;
    expect(step.options.firstWhere((o)=>o.label=='Steel vrijwel afwezig').result,'Schelpzwammen — kandidaatgroep');
    expect(step.options.firstWhere((o)=>o.label=='Steel zijdelings aangehecht').result,'Schelpzwammen — kandidaatgroep');
    expect(step.options.firstWhere((o)=>o.label=='Onzeker').result,contains('blijven mogelijk'));
    expect(shellDetailKey.sourceNote,contains('geen harde groepsfilter'));
  });

  test('all detail-key options terminate or point to an existing step',(){
    final keys=[russulaceaeDetailKey,shellDetailKey,pleurotusDetailKey,pluteusDetailKey,galerinaDetailKey,hebelomaDetailKey,agrocybeDetailKey,parasolDetailKey,laccariaDetailKey,waxcapDetailKey,funnelDetailKey,toughshankDetailKey,pholiotaDetailKey,strophariaDetailKey,paxillusDetailKey,cantharellusDetailKey];
    expect(keys.map((key)=>key.id).toSet().length,keys.length,reason:'detail key ids must be unique');
    final keyIds=keys.map((key)=>key.id).toSet();
    expect(sourceCatalogs.keys.toSet().difference(keyIds),isEmpty,reason:'source catalogs must belong to a detail key');
    expect(keyIds.difference(sourceCatalogs.keys.toSet()),{'russulaceae'},reason:'only Russulaceae intentionally lacks a species-reference catalog');
    for(final key in keys){
      expect(key.steps.containsKey(key.start),isTrue,reason:'${key.id} start step');
      for(final step in key.steps.values){
        expect(step.options,isNotEmpty,reason:'${key.id}/${step.id} options');
        for(final option in step.options){
          final hasResult=option.result!=null;
          final hasNext=option.next!=null;
          expect(hasResult ^ hasNext,isTrue,reason:'${key.id}/${step.id}/${option.label} path');
          if(hasNext){
            expect(key.steps.containsKey(option.next),isTrue,reason:'${key.id}/${step.id}/${option.label} next');
          }
        }
      }
    }
  });

}