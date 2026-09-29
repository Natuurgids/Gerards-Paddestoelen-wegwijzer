import 'package:flutter_test/flutter_test.dart';
import 'package:mushroom_determination_wheel/detail_keys.dart';

void main(){
  test('single supported candidates receive a source-backed detail key',(){
    expect(detailKeyFor(candidateNames:['Parasolzwammen (+)'])?.id,'parasol');
    expect(detailKeyFor(candidateNames:['Fopzwammen · Laccaria'])?.id,'laccaria');
    expect(detailKeyFor(candidateNames:['Hertenzwammen · Pluteus'])?.id,'pluteus');
    expect(detailKeyFor(candidateNames:['Wasplaten / Slijmkoppen'])?.id,'waxcaps');
    expect(detailKeyFor(candidateNames:['Trechtertjes · Omphalina/Rickenella'])?.id,'funnel');
    expect(detailKeyFor(candidateNames:['Taailingen (+)'])?.id,'toughshanks');
    expect(detailKeyFor(candidateNames:['Bundelzwammen (+) · Pholiota/Kuehneromyces'])?.id,'pholiota');
    expect(detailKeyFor(candidateNames:['Kaalkopjes / Stropharia (+)'])?.id,'stropharia');
  });
  test('ambiguous candidate sets do not pretend to have a detail key',(){
    expect(detailKeyFor(candidateNames:['Hertenzwammen · Pluteus','Mosklokjes · Galerina']),isNull);
  });
  test('Russulaceae genus hint takes precedence',(){
    expect(detailKeyFor(genusHint:'Lactarius',candidateNames:['Russulaceae · Russula/Lactarius'])?.id,'russulaceae');
  });
}