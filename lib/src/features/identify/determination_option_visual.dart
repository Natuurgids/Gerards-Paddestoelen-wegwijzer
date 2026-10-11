import 'package:flutter/material.dart';

import 'trait_visual.dart';
import 'colour_observation_visual.dart';
import 'observation_image_data.dart';
import 'observation_context_visual.dart';

/// Displays the generated field-guide image for a determination option.
///
/// The mapping is compiled from the bundled catalogue and takes precedence
/// over outdated paths in installed databases. If a mapping or image is missing,
/// the existing schematic [TraitVisual] is used as a safe fallback.
class DeterminationOptionVisual extends StatelessWidget {
  const DeterminationOptionVisual({
    super.key,
    required this.traitCode,
    required this.optionId,
    required this.optionLabel,
    this.size = 72,
    this.imagePath,
    this.fit = BoxFit.cover,
    this.framed = true,
  });

  final String traitCode;
  final int optionId;
  final String optionLabel;
  final double size;
  final String? imagePath;
  final BoxFit fit;
  final bool framed;

  Widget _fallback() => TraitVisual(
        traitCode: traitCode,
        optionId: optionId,
        optionLabel: optionLabel,
        size: size,
      );

  Widget _photograph(BuildContext context, String assetPath) {
    if (!framed) {
      return Semantics(label: optionLabel, image: true, child: SizedBox.square(
        dimension: size, child: Image.asset(assetPath, fit: fit, cacheWidth: 512,
          filterQuality: FilterQuality.medium,
          errorBuilder: (context, error, stackTrace) => _fallback())));
    }
    final scheme = Theme.of(context).colorScheme;
    return Semantics(label: optionLabel, image: true,
      child: SizedBox.square(dimension: size,
        child: ClipRRect(borderRadius: BorderRadius.circular(10),
          child: DecoratedBox(decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(10)),
            child: Image.asset(assetPath, width: size, height: size,
              fit: fit, cacheWidth: 512,
              filterQuality: FilterQuality.medium,
              errorBuilder: (context, error, stackTrace) => _fallback())))));
  }

  @override
  Widget build(BuildContext context) {
    if (ColourObservationVisual.supports(traitCode, optionId)) {
      return ColourObservationVisual(traitCode: traitCode, optionId: optionId,
        optionLabel: optionLabel, size: size);
    }
    final current = observationImages[optionId];
    if (current != null && current.trait == traitCode) {
      if (ObservationContextVisual.supports(traitCode, current.code)) {
        return ObservationContextVisual(trait: traitCode, code: current.code,
          label: optionLabel, size: size, asset: current.asset);
      }
      return _photograph(context, current.asset);
    }
    return imagePath == null ? _fallback() : _photograph(context, imagePath!);
  }
}
