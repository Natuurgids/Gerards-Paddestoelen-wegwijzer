import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

class SafetyNotice extends StatefulWidget {
  const SafetyNotice({
    super.key,
    this.displayDuration = const Duration(seconds: 3),
  });

  final Duration displayDuration;

  @override
  State<SafetyNotice> createState() => _SafetyNoticeState();
}

class _SafetyNoticeState extends State<SafetyNotice> {
  Timer? _timer;
  var _visible = true;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.displayDuration, () {
      if (mounted) {
        setState(() => _visible = false);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ColoredBox(
      color: scheme.errorContainer,
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 14,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: scheme.onErrorContainer,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context).safetyNotice,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onErrorContainer,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
