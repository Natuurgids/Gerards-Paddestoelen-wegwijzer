import 'package:flutter_test/flutter_test.dart';

import 'package:gerards_paddestoelen_wegwijzer/src/data/core_dataset_update.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled dataset version contract matches packaged metadata', () async {
    final metadata = await CoreDatasetMetadata.loadBundled();

    expect(metadata.datasetVersion, bundledCoreDatasetVersion);
  });
}
