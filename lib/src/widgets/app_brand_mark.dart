import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppBrandMark extends StatelessWidget {
  const AppBrandMark({
    super.key,
    this.size = 72,
    this.borderRadius = 18,
  });

  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox.square(
        dimension: size,
        child: Image.asset(
          'assets/app_icon.png',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.forest, AppTheme.forestDark],
              ),
            ),
            child: Icon(
              Icons.park_outlined,
              size: size * 0.5,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
