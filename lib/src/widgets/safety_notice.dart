import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

class SafetyNotice extends StatelessWidget {
  const SafetyNotice({super.key, required this.locale});

  final Locale locale;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        color: Theme.of(context).colorScheme.errorContainer,
        child: Text(
          AppLocalizations.of(context).safetyNotice,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onErrorContainer,
            fontSize: 12,
          ),
        ),
      );
}
