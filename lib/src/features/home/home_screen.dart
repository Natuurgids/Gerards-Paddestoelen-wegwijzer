import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../data/learning_materials_service.dart';
import '../../widgets/safety_notice.dart';
import '../identify/identify_screen.dart';
import '../species/species_browser_screen.dart';
import '../training/learning_materials_screen.dart';
import '../training/training_screen.dart';
import 'sources_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.locale,
    required this.onLocaleChanged,
    this.learningMaterialsService,
  });

  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;
  final LearningMaterialsService? learningMaterialsService;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: locale.languageCode,
              items: const [
                DropdownMenuItem(value: 'nl', child: Text('NL')),
                DropdownMenuItem(value: 'en', child: Text('EN')),
                DropdownMenuItem(value: 'de', child: Text('DE')),
              ],
              onChanged: (value) {
                if (value != null) onLocaleChanged(Locale(value));
              },
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    l10n.homeIntro,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => IdentifyScreen(locale: locale),
                      ),
                    ),
                    icon: const Icon(Icons.search),
                    label: Text(l10n.homeIdentify),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TrainingScreen(locale: locale),
                      ),
                    ),
                    icon: const Icon(Icons.school_outlined),
                    label: Text(l10n.homeLearn),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => LearningMaterialsScreen(
                          locale: locale,
                          service: learningMaterialsService,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.download_for_offline_outlined),
                    label: Text(l10n.homeLearningMaterials),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SpeciesBrowserScreen(locale: locale),
                      ),
                    ),
                    icon: const Icon(Icons.eco_outlined),
                    label: Text(l10n.homeBrowseSpecies),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SourcesScreen()),
                    ),
                    icon: const Icon(Icons.info_outline),
                    label: Text(l10n.homeSourcesLicenses),
                  ),
                ],
              ),
            ),
            const SafetyNotice(),
          ],
        ),
      ),
    );
  }
}
