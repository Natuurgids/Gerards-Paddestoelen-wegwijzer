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
    DatabaseExecutor db,
    Map<String, dynamic> decoded,
  ) async {
    final version = decoded['version'] as int? ?? 1;
    final flexibleGallery = version >= 4;
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
      if (images.isEmpty) {
        throw FormatException('Species $speciesId must define at least one image');
      }
      if (!flexibleGallery && images.length != 5) {
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
        if (path is! String ||
            path.trim() != path ||
            !path.startsWith('assets/images/species/') ||
            !allPaths.add(path)) {
          throw FormatException(
            'Invalid or duplicate gallery path for species $speciesId: $path',
          );
        }

        final order = image['order'];
        if (order is! int ||
            order < 0 ||
            (!flexibleGallery && !_requiredOrders.contains(order)) ||
            !orders.add(order)) {
          throw FormatException(
            'Invalid or duplicate gallery order for species $speciesId: $order',
          );
        }

        final angle = image['angle'];
        if (angle is! String ||
            angle.trim() != angle ||
            angle.isEmpty ||
            (!flexibleGallery && !_requiredAngles.contains(angle)) ||
            !angles.add(angle)) {
          throw FormatException(
            'Invalid or duplicate gallery angle for species $speciesId: $angle',
          );
        }

        final placeholderValue = image['placeholder'];
        final placeholder = placeholderValue == true;
        if (!flexibleGallery && placeholderValue is! bool) {
          throw FormatException(
            'Gallery placeholder status is required for species $speciesId: '
            '$placeholderValue',
          );
        }
        if (flexibleGallery &&
            placeholderValue != null &&
            placeholderValue is! bool) {
          throw FormatException(
            'Invalid gallery placeholder status for species $speciesId: '
            '$placeholderValue',
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

        if (placeholder) {
          for (final field in const ['photographer', 'license']) {
            final value = image[field];
            if (value != null) {
              throw FormatException(
                'Placeholder gallery $field must be omitted for species '
                '$speciesId: $value',
              );
            }
          }
        } else {
          final license = image['license'];
          if (license is! String ||
              license.trim() != license ||
              license.isEmpty) {
            throw FormatException(
              'Real gallery license is required for species $speciesId: $license',
            );
          }
          final photographer = image['photographer'];
          if (photographer != null &&
              (photographer is! String ||
                  photographer.trim() != photographer ||
                  photographer.isEmpty)) {
            throw FormatException(
              'Invalid gallery photographer for species $speciesId: '
              '$photographer',
            );
          }
        }

        if (image['primary'] == true) primaryCount++;
      }

      if (!flexibleGallery &&
          (orders.length != _requiredOrders.length ||
              !orders.containsAll(_requiredOrders))) {
        throw FormatException(
          'Species $speciesId must use gallery orders 0 through 4',
        );
      }
      if (flexibleGallery) {
        final expectedOrders = List<int>.generate(images.length, (index) => index);
        if (!expectedOrders.every(orders.contains)) {
          throw FormatException(
            'Species $speciesId must use contiguous gallery orders starting at 0',
          );
        }
      }
      if (!flexibleGallery &&
          (angles.length != _requiredAngles.length ||
              !angles.containsAll(_requiredAngles))) {
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

    if (db is Database) {
      await db.transaction((txn) => _writeDecoded(txn, species));
    } else {
      await _writeDecoded(db, species);
    }
  }

  static Future<void> _writeDecoded(
    DatabaseExecutor db,
    List<dynamic> species,
  ) async {
    final batch = db.batch();
    batch.delete('species_image');
    for (final rawSpecies in species) {
      final item = rawSpecies as Map<String, dynamic>;
      final speciesId = item['speciesId'] as int;
      for (final rawImage in item['images'] as List<dynamic>) {
        final image = rawImage as Map<String, dynamic>;
        batch.insert('species_image', {
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
    await batch.commit(noResult: true);
  }
}
