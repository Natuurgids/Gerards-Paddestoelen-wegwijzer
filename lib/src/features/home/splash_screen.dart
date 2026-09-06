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
          return Stack(
            fit: StackFit.expand,
            children: [
              _SplashBackdrop(wide: wide),
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: wide ? 72 : 28,
                    vertical: wide ? 40 : 24,
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 900),
                            child: wide
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const AppBrandMark(
                                        size: 220,
                                        borderRadius: 44,
                                      ),
                                      const SizedBox(width: 52),
                                      Flexible(
                                        child: _SplashIdentity(
                                          appTitle: l10n.appTitle,
                                          alignment: CrossAxisAlignment.start,
                                        ),
                                      ),
                                    ],
                                  )
                                : _SplashIdentity(
                                    appTitle: l10n.appTitle,
                                    alignment: CrossAxisAlignment.center,
                                    showMark: true,
                                  ),
                          ),
                        ),
                      ),
                      _CreditsPanel(
                        wide: wide,
                        onContinue: onContinue,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SplashIdentity extends StatelessWidget {
  const _SplashIdentity({
    required this.appTitle,
    required this.alignment,
    this.showMark = false,
  });

  final String appTitle;
  final CrossAxisAlignment alignment;
  final bool showMark;

  @override
  Widget build(BuildContext context) {
    final centered = alignment == CrossAxisAlignment.center;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: alignment,
      children: [
        if (showMark) ...[
          const AppBrandMark(size: 150, borderRadius: 34),
          const SizedBox(height: 28),
        ],
        Text(
          appTitle,
          textAlign: centered ? TextAlign.center : TextAlign.left,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                height: 1.02,
              ),
        ),
        const SizedBox(height: 14),
        Text(
          'Identify • Learn • Explore',
          textAlign: centered ? TextAlign.center : TextAlign.left,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: const Color(0xFFE7E2D5),
                letterSpacing: 0.5,
              ),
        ),
        const SizedBox(height: 28),
        const SizedBox(
          width: 300,
          child: LinearProgressIndicator(minHeight: 7),
        ),
        const SizedBox(height: 14),
        Text(
          'De natuur dichterbij…',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: const Color(0xFFE7E2D5),
              ),
        ),
      ],
    );
  }
}

class _CreditsPanel extends StatelessWidget {
  const _CreditsPanel({required this.wide, required this.onContinue});

  final bool wide;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onContinue,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 980),
        padding: EdgeInsets.symmetric(
          horizontal: wide ? 28 : 20,
          vertical: wide ? 20 : 16,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F0E5).withValues(alpha: 0.97),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          runSpacing: 8,
          spacing: 24,
          children: [
            const Text(
              'Een app van Natuurgids.org',
              style: TextStyle(
                color: AppTheme.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Text(
              'Bronnen en beeldrechten: zie Bronnen & licenties',
              style: TextStyle(color: AppTheme.ink),
            ),
            Text(
              'Tik om door te gaan',
              style: TextStyle(
                color: AppTheme.forest.withValues(alpha: 0.78),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
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
                AppTheme.forestDark.withValues(alpha: 0.92),
                AppTheme.forest.withValues(alpha: 0.78),
                AppTheme.forestDark.withValues(alpha: 0.88),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
