import 'package:flutter/material.dart';

import 'colour_observation_data.dart';

/// Photographic observation illustrations, with explicit colours on a neutral
/// texture. These are examples of a feature, not photographs of named species.
class ColourObservationVisual extends StatelessWidget {
  const ColourObservationVisual({super.key, required this.traitCode,
    required this.optionId, required this.optionLabel, required this.size});
  final String traitCode, optionLabel;
  final int optionId;
  final double size;

  static bool supports(String trait, int option) =>
    colourObservationStyles[option]?.trait == trait;

  Widget photograph(String asset, {Color? tint}) {
    final image = Image.asset(asset, fit: BoxFit.contain, cacheWidth: 512,
      filterQuality: FilterQuality.medium);
    return tint == null ? image : ColorFiltered(
      colorFilter: ColorFilter.mode(tint, BlendMode.modulate), child: image);
  }

  @override
  Widget build(BuildContext context) {
    final style = colourObservationStyles[optionId]!;
    return Semantics(label: optionLabel, image: true,
      child: SizedBox.square(dimension: size,
        child: DecoratedBox(decoration: BoxDecoration(
          color: const Color(0xfff3eee1),
          borderRadius: BorderRadius.circular(6)),
        child: LayoutBuilder(builder: (context, bounds) {
          if (style.kind == 'uncertain' || style.kind == 'not_applicable') {
            return Center(child: Icon(style.kind == 'uncertain'
              ? Icons.help_outline : Icons.not_interested,
              color: const Color(0xff385342), size: bounds.maxWidth * .55));
          }
          final tint = style.tint == null ? null : Color(style.tint!);
          if (style.trait == 'bruising') {
            return Stack(fit: StackFit.expand, children: [
              photograph(style.asset),
              if (tint != null) Positioned(
                left: bounds.maxWidth * .46, top: bounds.maxHeight * .35,
                width: bounds.maxWidth * .32, height: bounds.maxHeight * .30,
                child: photograph(bruisePatchAsset, tint: tint)),
              if (style.kind == 'red_then_black') Positioned(
                left: bounds.maxWidth * .53, top: bounds.maxHeight * .40,
                width: bounds.maxWidth * .20, height: bounds.maxHeight * .19,
                child: photograph(bruisePatchAsset,
                  tint: const Color(0xff292627))),
            ]);
          }
          if (style.kind == 'multicoloured') {
            return ShaderMask(blendMode: BlendMode.modulate,
              shaderCallback: (rect) => const LinearGradient(colors: [
                Color(0xffad6550), Color(0xff9c8546), Color(0xff628653),
              ]).createShader(rect), child: photograph(style.asset));
          }
          return photograph(style.asset, tint: tint);
        }))));
  }
}
