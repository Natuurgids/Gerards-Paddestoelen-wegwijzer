import 'package:flutter_test/flutter_test.dart';
import 'package:mushroom_determination_wheel/source_catalog.dart';

void main(){
  test('Pluteus source catalog exposes document-backed profile and taxa',(){
    final c=sourceCatalogs['pluteus']!;
    expect(c.profile,contains('Sporee roze'));
    expect(c.profile.any((x)=>x.contains('vrij')),isTrue);
    expect(c.taxa,contains('Gewone hertenzwam'));
    expect(c.taxa,contains('Grauwgroene hertenzwam'));
    expect(c.hasNamedPossibilities,isTrue);
    expect(c.nextEvidence,isNotEmpty);
  });
  test('Agrocybe catalog includes document-listed species without selecting one',(){
    final c=sourceCatalogs['agrocybe']!;
    expect(c.profile,contains('Sporee vaalbruin'));
    expect(c.taxa,contains('Gaderde leemhoed (Agrocybe rivulosa)'));
    expect(c.note,contains('geen volledige soortensleutel'));
    expect(c.hasNamedPossibilities,isTrue);
  });
  test('Pleurotus does not invent species names absent from the retrieved passage',(){
    final c=sourceCatalogs['pleurotus']!;
    expect(c.hasNamedPossibilities,isFalse);
    expect(c.nextEvidence.any((x)=>x.contains('DNA')),isTrue);
  });
  test('Galerina and Hebeloma remain group profiles when species branches are unsupported',(){
    expect(sourceCatalogs['galerina']!.taxa,isEmpty);
    expect(sourceCatalogs['hebeloma']!.taxa,isEmpty);
  });
}
