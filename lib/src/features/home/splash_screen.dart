import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_brand_mark.dart';

class SplashGate extends StatefulWidget {
  const SplashGate({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1800),
  });

  final Widget child;
  final Duration duration;

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  Timer? _timer;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.duration, _finish);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _finish() {
    if (_finished || !mounted) return;
    setState(() => _finished = true);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: _finished
          ? KeyedSubtree(key: const ValueKey('app-home'), child: widget.child)
          : BrandSplashScreen(
              key: const ValueKey('brand-splash'),
              onContinue: _finish,
            ),
    );
  }
}

class BrandSplashScreen extends StatelessWidget {
  const BrandSplashScreen({super.key, this.onContinue});

  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppTheme.forestDark,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onContinue,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _SplashBackdrop(wide: wide),
                SafeArea(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: wide ? 72 : 28,
                      vertical: wide ? 44 : 28,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 980),
                        child: Column(
                          children: [
                            const Spacer(flex: 2),
                            _SplashIdentity(
                              appTitle: l10n.appTitle,
                              wide: wide,
                            ),
                            const Spacer(flex: 3),
                            const _NatureRespectMessage(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SplashIdentity extends StatelessWidget {
  const _SplashIdentity({required this.appTitle, required this.wide});

  final String appTitle;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final markSize = wide ? 176.0 : 138.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppBrandMark(
          size: markSize,
          borderRadius: wide ? 38 : 30,
        ),
        SizedBox(height: wide ? 30 : 24),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: wide ? 620 : 360),
          child: Text(
            appTitle,
            textAlign: TextAlign.center,
            style: (wide ? textTheme.displayMedium : textTheme.displaySmall)
                ?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              height: 1.02,
              shadows: const [
                Shadow(
                  blurRadius: 12,
                  color: Color(0x99000000),
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: wide ? 18 : 14),
        Text(
          'Ontdek. Leer. Bescherm.',
          textAlign: TextAlign.center,
          style: textTheme.titleLarge?.copyWith(
            color: const Color(0xFFF3EEDC),
            fontWeight: FontWeight.w500,
            letterSpacing: 0.35,
            shadows: const [
              Shadow(
                blurRadius: 8,
                color: Color(0x99000000),
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NatureRespectMessage extends StatelessWidget {
  const _NatureRespectMessage();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      decoration: BoxDecoration(
        color: AppTheme.forestDark.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.eco_outlined,
            size: 18,
            color: Color(0xFFE8E3C9),
          ),
          const SizedBox(width: 8),
          Text(
            'Met respect voor natuur en soorten',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFFF3EEDC),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SplashBackdrop extends StatelessWidget {
  const _SplashBackdrop({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/species/species_1/5.jpg',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.forest, AppTheme.forestDark],
              ),
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: wide ? Alignment.centerLeft : Alignment.topCenter,
              end: wide ? Alignment.centerRight : Alignment.bottomCenter,
              colors: [
                AppTheme.forestDark.withValues(alpha: 0.38),
                AppTheme.forest.withValues(alpha: 0.18),
                AppTheme.forestDark.withValues(alpha: 0.68),
              ],
              stops: const [0, 0.48, 1],
            ),
          ),
        ),
      ],
    );
  }
}
