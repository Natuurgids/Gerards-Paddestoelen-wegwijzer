import 'package:flutter/material.dart';

class SpeciesImageView extends StatelessWidget {
  const SpeciesImageView({
    super.key,
    required this.path,
    required this.missingLabel,
  });

  final String path;
  final String missingLabel;

  @override
  Widget build(BuildContext context) {
    Widget fallback() => Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.image_not_supported_outlined, size: 56),
              const SizedBox(height: 8),
              Text(missingLabel),
            ],
          ),
        );

    if (path.isEmpty) return fallback();

    return Image.asset(
      path,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => fallback(),
    );
  }
}
