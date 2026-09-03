import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

class ImageManifestImporter {
  static const _assetPath = 'assets/data/species_images.json';
  static const _requiredAngles = {
    'top',
    'underside',
    'side',
    'base',
    'habitat',
  };
  static const _requiredOrders = {0, 1, 2, 3, 4};

  static Future<void> sync(Database db) async {
    final raw = await rootBundle.loadString(_assetPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    await syncDecoded(db, decoded);
  }

  static Future<void> syncDecoded(
    Database db,
    Map<String, dynamic> decoded,
  ) async {
    final species = decoded['species'] as List<dynamic>? ?? const [];
    final speciesIds = <int>{};
    final allPaths = <String>{};

    for (final rawSpecies in species) {
      final item = rawSpecies as Map<String, dynamic>;
      final speciesId = item['speciesId'];
      if (speciesId is! int || !speciesIds.add(speciesId)) {
        throw FormatException('Duplicate or invalid gallery species id: $speciesId');
      }

      final images = item['images'] as List<dynamic>? ?? const [];
      if (images.length != 5) {
        throw FormatException(
          'Species $speciesId must define exactly five gallery images',
        );
      }

      final orders = <int>{};
      final angles = <String>{};
      var primaryCount = 0;
      for (final rawImage in images) {
        final image = rawImage as Map<String, dynamic>;
        final path = image['path'];
        if (path is! String || path.trim() != path ||
            !path.startsWith('assets/images/species/') ||
            !allPaths.add(path)) {
          throw FormatException(
            'Invalid or duplicate gallery path for species $speciesId: $path',
          );
        }

        final order = image['order'];
        if (order is! int || !_requiredOrders.contains(order) ||
            !orders.add(order)) {
          throw FormatException(
            'Invalid or duplicate gallery order for species $speciesId: $order',
          );
        }

        final angle = image['angle'];
        if (angle is! String || !_requiredAngles.contains(angle) ||
            !angles.add(angle)) {
          throw FormatException(
            'Invalid or duplicate gallery angle for species $speciesId: $angle',
          );
        }

        final placeholder = image['placeholder'];
        if (placeholder is! bool) {
          throw FormatException(
            'Gallery placeholder status is required for species $speciesId: '
            '$placeholder',
          );
        }

        final thumbnailPath = image['thumbnailPath'];
        if (thumbnailPath != null &&
            (thumbnailPath is! String ||
                thumbnailPath.trim() != thumbnailPath ||
                !thumbnailPath.startsWith('assets/images/'))) {
          throw FormatException(
            'Invalid thumbnail path for species $speciesId: $thumbnailPath',
          );
        }

        for (final field in const ['photographer', 'license']) {
          final value = image[field];
          if (placeholder) {
            if (value != null) {
              throw FormatException(
                'Placeholder gallery $field must be omitted for species '
                '$speciesId: $value',
              );
            }
          } else if (value is! String ||
              value.trim() != value ||
              value.isEmpty) {
            throw FormatException(
              'Real gallery $field is required for species $speciesId: $value',
            );
          }
        }

        if (image['primary'] == true) primaryCount++;
      }

      if (orders.length != _requiredOrders.length ||
          !orders.containsAll(_requiredOrders)) {
        throw FormatException(
          'Species $speciesId must use gallery orders 0 through 4',
        );
      }
      if (angles.length != _requiredAngles.length ||
          !angles.containsAll(_requiredAngles)) {
        throw FormatException(
          'Species $speciesId must cover all five gallery angles',
        );
      }
      if (primaryCount != 1) {
        throw FormatException(
          'Species $speciesId must define exactly one primary image',
        );
      }
    }

    await db.transaction((txn) async {
      await txn.delete('species_image');
      for (final rawSpecies in species) {
        final item = rawSpecies as Map<String, dynamic>;
        final speciesId = item['speciesId'] as int;
        for (final rawImage in item['images'] as List<dynamic>) {
          final image = rawImage as Map<String, dynamic>;
          await txn.insert('species_image', {
            'species_id': speciesId,
            'asset_path': image['path'] as String,
            'thumbnail_path': image['thumbnailPath'] as String?,
            'angle_code': image['angle'] as String,
            'photographer': image['photographer'] as String?,
            'license': image['license'] as String?,
            'sort_order': image['order'] as int,
            'is_primary': image['primary'] == true ? 1 : 0,
            'is_placeholder': image['placeholder'] == true ? 1 : 0,
          });
        }
      }
    });
  }
}
