import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'trait_visual.dart';

/// Displays the generated field-guide image for a determination option.
///
/// The mapping from numeric option id to asset filename is read from the
/// bundled identification trait manifest, so the UI stays in sync with
/// assets/data/identification_traits.json. If a mapping or image is missing,
/// the existing schematic [TraitVisual] is used as a safe fallback.
class DeterminationOptionVisual extends StatelessWidget {
  const DeterminationOptionVisual({
    super.key,
    required this.traitCode,
    required this.optionId,
    required this.optionLabel,
    this.size = 72,
    this.imagePath,
  });

  final String traitCode;
  final int optionId;
  final String optionLabel;
  final double size;
  final String? imagePath;

  static final Future<Map<String, String>> _optionCodes = _loadOptionCodes();

  static Future<Map<String, String>> _loadOptionCodes() async {
    final raw = await rootBundle.loadString(
      'assets/data/identification_traits.json',
    );
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final traits = decoded['traits'] as List<dynamic>? ?? const [];
    final result = <String, String>{};

    for (final rawTrait in traits) {
      final trait = rawTrait as Map<String, dynamic>;
      final traitCode = trait['code']?.toString();
      if (traitCode == null || traitCode.isEmpty) continue;
      final options = trait['options'] as List<dynamic>? ?? const [];
      for (final rawOption in options) {
        final option = rawOption as Map<String, dynamic>;
        final id = option['id'];
        final code = option['code']?.toString();
        if (id is int && code != null && code.isNotEmpty) {
          result['$traitCode:$id'] = option['image']?.toString() ??
              'assets/images/traits/$traitCode/$code.png';
        }
      }
    }

    return result;
  }

  Widget _fallback() => TraitVisual(
        traitCode: traitCode,
        optionId: optionId,
        optionLabel: optionLabel,
        size: size,
      );

  Widget _photograph(BuildContext context, String assetPath) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(label: optionLabel, image: true,
      child: SizedBox.square(dimension: size,
        child: ClipRRect(borderRadius: BorderRadius.circular(10),
          child: DecoratedBox(decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(10)),
            child: Image.asset(assetPath, width: size, height: size,
              fit: BoxFit.cover, cacheWidth: 512,
              filterQuality: FilterQuality.medium,
              errorBuilder: (context, error, stackTrace) => _fallback())))));
  }

  @override
  Widget build(BuildContext context) {
    if (imagePath != null) return _photograph(context, imagePath!);
    return FutureBuilder<Map<String, String>>(
      future: _optionCodes,
      builder: (context, snapshot) {
        final path = snapshot.data?['$traitCode:$optionId'];
        return path == null ? _fallback() : _photograph(context, path);
      });
  }
}
