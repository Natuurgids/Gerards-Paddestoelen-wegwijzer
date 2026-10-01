import 'dart:async';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

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

class BrandSplashScreen extends StatefulWidget {
  const BrandSplashScreen({super.key, this.onContinue});

  final VoidCallback? onContinue;

  @override
  State<BrandSplashScreen> createState() => _BrandSplashScreenState();
}

class _BrandSplashScreenState extends State<BrandSplashScreen> {
  String? _version;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _version = 'v${info.version}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.forestDark,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onContinue,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            return Semantics(
              label: "Gerard's Paddestoelen Wegwijzer. Wiel. ${_version ?? ''}. Ontdek. Leer. Beleef de natuur.",
              image: true,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
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
                  Align(
                    alignment: const Alignment(0, 0.88),
                    child: SafeArea(
                      minimum: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppTheme.forestDark.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Wiel',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (_version != null)
                                Text(
                                  _version!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
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
      ),
    );
  }
}
