import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

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
    return Scaffold(
      backgroundColor: AppTheme.forestDark,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onContinue,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            return Semantics(
              label: "Gerard's Paddestoelen Wegwijzer. Ontdek. Leer. Beleef de natuur.",
              image: true,
              child: SizedBox.expand(
                child: Image.asset(
                  'assets/splash.png',
                  fit: wide ? BoxFit.contain : BoxFit.cover,
                  alignment: Alignment.center,
                  errorBuilder: (context, error, stackTrace) => const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppTheme.forest, AppTheme.forestDark],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
