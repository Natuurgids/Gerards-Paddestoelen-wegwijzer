import 'dart:async';

import 'models.dart';
import 'reference_asset_store.dart';
import 'repositories.dart';

class ResilientSpeciesRepository extends SpeciesRepository {
  ResilientSpeciesRepository({super.databaseProvider})
      : _preferDatabase = databaseProvider != null;

  static const _databaseBudget = Duration(seconds: 2);

  final bool _preferDatabase;

  @override
  Future<SpeciesDetail?> detail(int id, String languageCode) async {
    if (!_preferDatabase) {
      final asset = await ReferenceAssetStore.instance.speciesDetail(
        id,
        languageCode,
      );
      if (asset != null) return asset;
    }

    try {
      return await super.detail(id, languageCode).timeout(_databaseBudget);
    } on Object {
      return ReferenceAssetStore.instance.speciesDetail(id, languageCode);
    }
  }
}
