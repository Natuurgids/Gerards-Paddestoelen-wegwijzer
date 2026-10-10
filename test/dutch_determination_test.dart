import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/dutch_identification_scope.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/reference_asset_store.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/resilient_identification_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('active catalogue exposes 23 groups and 341 choices in each language', () async {
    for (final language in ['nl', 'en', 'de']) {
      final choices = await ReferenceAssetStore.instance.traitChoices(language);
      expect(choices.length, 341);
      expect(choices.map((c) => c.traitId).toSet().length, 23);
      expect(choices.any((c) => c.traitId == 17 || c.traitId == 18), isFalse);
      expect(choices.every((c) => c.optionLabel.isNotEmpty), isTrue);
    }
  });
  test('old 139 identifiers remain stored and all photographic paths exist', () async {
    final manifest = jsonDecode(await rootBundle.loadString(
      'assets/data/identification_traits.json')) as Map<String, dynamic>;
    final ids = <int>{};
    for (final raw in manifest['traits'] as List<dynamic>) {
      final trait = raw as Map<String, dynamic>;
      for (final rawOption in trait['options'] as List<dynamic>) {
        final option = rawOption as Map<String, dynamic>;
        expect(ids.add(option['id'] as int), isTrue);
        expect(File(option['image'] as String).existsSync(), isTrue);
      }
    }
    expect(ids, containsAll(List.generate(139, (index) => index + 1)));
    expect(File('determination_wheel/assets/data/identification_traits.json').readAsStringSync(),
      File('assets/data/identification_traits.json').readAsStringSync());
  });
  test('national link uses exact species names and retains the source record', () async {
    final links = await DutchIdentificationScope.instance.links;
    expect(links[1]?.recordId, '486787300');
    expect(links.values.map((link) => link.speciesId).toSet().length, 12509);
    expect(DutchIdentificationScope.canonicalSpeciesName('Amanita muscaria (L.:Fr.) Hook.'),
      'Amanita muscaria');
    expect(DutchIdentificationScope.canonicalSpeciesName('Amanita muscaria var. alba'), isNull);
    expect(DutchIdentificationScope.canonicalSpeciesName('Amanita'), isNull);
  });
  test('unrecorded traits are unknown rather than disagreements', () async {
    final repo = ResilientIdentificationRepository();
    final traits = await ReferenceAssetStore.instance.traits;
    final shape = (traits['traits'] as List<dynamic>)
      .cast<Map<String, dynamic>>().singleWhere((t) => t['code'] == 'spore_shape');
    final globose = (shape['options'] as List<dynamic>)
      .cast<Map<String, dynamic>>().singleWhere((o) => o['code'] == 'globose')['id'] as int;
    final candidates = await repo.identify('nl', {1: 1, 25: globose});
    final flyAgaric = candidates.singleWhere((c) => c.species.id == 1);
    expect(flyAgaric.score, 1);
    expect(flyAgaric.evaluated, 1);
    expect(flyAgaric.unknown, 1);
    expect(flyAgaric.contradicted, 0);
    expect(flyAgaric.dutchRecordId, isNotNull);
  });
  test('new gill, stem, odour and microscopy mappings participate in ranking', () async {
    final manifest = await ReferenceAssetStore.instance.traits;
    final traits = (manifest['traits'] as List<dynamic>).cast<Map<String, dynamic>>();
    final selected = <int, int>{};
    for (final entry in {'gill_colour': 'orange', 'stem_colour': 'orange',
      'odour': 'fruity', 'spore_shape': 'ellipsoid'}.entries) {
      final trait = traits.singleWhere((t) => t['code'] == entry.key);
      final option = (trait['options'] as List<dynamic>).cast<Map<String, dynamic>>()
        .singleWhere((o) => o['code'] == entry.value);
      selected[trait['id'] as int] = option['id'] as int;
    }
    final result = await ResilientIdentificationRepository().identify('en', selected);
    expect(result.first.species.scientificName, 'Lactarius deliciosus');
    expect(result.first.matched, 4);
    expect(result.first.evaluated, 4);
    expect(result.every((c) => c.dutchRecordId != null), isTrue);
    expect(result.map((c) => c.dutchSpeciesId).toSet().length, result.length);
  });
  test('coverage does not present checklist-only taxa as assessed', () async {
    final coverage = await ResilientIdentificationRepository().coverage({1: 1});
    expect(coverage.total, 12509);
    expect(coverage.mapped, 16);
    expect(coverage.assessable, lessThanOrEqualTo(16));
    expect(coverage.unassessed, greaterThan(12000));
  });
}
