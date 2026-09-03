import 'package:flutter_test/flutter_test.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/repositories.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('season region options are localized from field-data manifest', () async {
    final repository = FieldDataRepository();

    final nl = await repository.seasonRegions('nl');
    final en = await repository.seasonRegions('en');
    final de = await repository.seasonRegions('de');

    expect(nl, isNotEmpty);
    expect(en, hasLength(nl.length));
    expect(de, hasLength(nl.length));

    final gbNl = nl.singleWhere((region) => region.code == 'GB-IE');
    final gbEn = en.singleWhere((region) => region.code == 'GB-IE');
    final gbDe = de.singleWhere((region) => region.code == 'GB-IE');

    expect(gbNl.label, 'Groot-Brittannië/Ierland');
    expect(gbEn.label, 'Britain/Ireland');
    expect(gbDe.label, 'Großbritannien/Irland');
    expect(gbNl.note, isNotEmpty);
    expect(gbEn.note, isNotEmpty);
    expect(gbDe.note, isNotEmpty);
  });

  test('unknown locale falls back to English region metadata', () async {
    final regions = await FieldDataRepository().seasonRegions('fr');
    final gb = regions.singleWhere((region) => region.code == 'GB-IE');
    expect(gb.label, 'Britain/Ireland');
    expect(gb.note, isNotEmpty);
  });
}
