import 'dart:convert';

import 'package:flutter/services.dart';

class ImageAttributionStore {
  ImageAttributionStore._();

  static final instance = ImageAttributionStore._();

  Future<Map<String, String>>? _sourcesByPath;

  Future<Map<String, String>> sourcesByPath() =>
      _sourcesByPath ??= _loadSourcesByPath();

  Future<Map<String, String>> _loadSourcesByPath() async {
    final raw = await rootBundle.loadString('assets/data/species_images.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final result = <String, String>{};

    for (final rawSpecies in decoded['species'] as List<dynamic>? ?? const []) {
      final species = rawSpecies as Map<String, dynamic>;
      for (final rawImage in species['images'] as List<dynamic>? ?? const []) {
        final image = rawImage as Map<String, dynamic>;
        final path = image['path'];
        final source = image['source'];
        if (path is String &&
            path.isNotEmpty &&
            source is String &&
            source.trim().isNotEmpty) {
          result[path] = source.trim();
        }
      }
    }

    return Map.unmodifiable(result);
  }
}
