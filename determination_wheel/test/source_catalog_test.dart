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
    expect(c.possibilityCaveat,contains('geen gesloten soortenlijst'));
  });
  test('Agrocybe catalog includes document-listed species without selecting one',(){
    final c=sourceCatalogs['agrocybe']!;
    expect(c.profile,contains('Sporee vaalbruin'));
    expect(c.taxa,contains('Gaderde leemhoed (Agrocybe rivulosa)'));
    expect(c.note,contains('geen volledige soortensleutel'));
    expect(c.hasNamedPossibilities,isTrue);
    expect(c.nextEvidence.any((x)=>x.contains('microscopische')),isTrue);
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
  test('Schelpzwammen catalog preserves open source morphology',(){
    final c=sourceCatalogs['shell']!;
    expect(c.profile.any((x)=>x.contains('zijdelings')),isTrue);
    expect(c.profile.any((x)=>x.contains('lamellen')&&x.contains('rimpels')&&x.contains('glad')),isTrue);
    expect(c.taxa,isEmpty);
    expect(c.nextEvidence.any((x)=>x.contains('steel')),isTrue);
    expect(c.possibilityCaveat,contains('geen gesloten'));
  });

  test('all source catalogs contain usable reviewed guidance',(){
    for(final entry in sourceCatalogs.entries){
      final catalog=entry.value;
      expect(catalog.group.trim(),isNotEmpty,reason:'${entry.key} group');
      expect(catalog.profile,isNotEmpty,reason:'${entry.key} profile');
      expect(catalog.profile.every((item)=>item.trim().isNotEmpty),isTrue,reason:'${entry.key} profile items');
      expect(catalog.note.trim(),isNotEmpty,reason:'${entry.key} note');
      expect(catalog.nextEvidence,isNotEmpty,reason:'${entry.key} next evidence');
      expect(catalog.nextEvidence.every((item)=>item.trim().isNotEmpty),isTrue,reason:'${entry.key} evidence items');
      expect(catalog.taxa.every((item)=>item.trim().isNotEmpty),isTrue,reason:'${entry.key} taxa');
    }
  });

}
