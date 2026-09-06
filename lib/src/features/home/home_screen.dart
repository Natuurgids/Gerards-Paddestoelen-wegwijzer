import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../data/learning_materials_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_brand_mark.dart';
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
    final destinations = _destinations(context, l10n);

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 1050;
        if (desktop) {
          return Scaffold(
            body: Row(
              children: [
                SizedBox(
                  width: 264,
                  child: _DesktopSidebar(
                    title: l10n.appTitle,
                    destinations: destinations,
                    locale: locale,
                    onLocaleChanged: onLocaleChanged,
                  ),
                ),
                Expanded(
                  child: _HomeContent(
                    intro: l10n.homeIntro,
                    destinations: destinations,
                    desktop: true,
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 8,
            title: Row(
              children: [
                const AppBrandMark(size: 36, borderRadius: 9),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.appTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            actions: [
              _LanguageSelector(
                locale: locale,
                onLocaleChanged: onLocaleChanged,
              ),
              const SizedBox(width: 8),
            ],
          ),
          drawer: Drawer(
            child: _MobileDrawer(
              title: l10n.appTitle,
              destinations: destinations,
            ),
          ),
          body: _HomeContent(
            intro: l10n.homeIntro,
            destinations: destinations,
            desktop: false,
          ),
        );
      },
    );
  }

  List<_HomeDestination> _destinations(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    void push(Widget screen) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    }

    return [
      _HomeDestination(
        label: l10n.homeIdentify,
        subtitle: _localized(
          locale,
          nl: 'Stap voor stap kenmerken vergelijken',
          en: 'Compare observable characters step by step',
          de: 'Merkmale Schritt für Schritt vergleichen',
        ),
        icon: Icons.travel_explore_outlined,
        imagePath: 'assets/images/species/species_1/1.jpg',
        onTap: () => push(IdentifyScreen(locale: locale)),
      ),
      _HomeDestination(
        label: l10n.homeBrowseSpecies,
        subtitle: _localized(
          locale,
          nl: 'Zoek in de offline soortencatalogus',
          en: 'Search the offline species catalogue',
          de: 'Im Offline-Artenkatalog suchen',
        ),
        icon: Icons.eco_outlined,
        imagePath: 'assets/images/species/species_2/1.jpg',
        onTap: () => push(SpeciesBrowserScreen(locale: locale)),
      ),
      _HomeDestination(
        label: l10n.homeLearn,
        subtitle: _localized(
          locale,
          nl: 'Lessen, vragen en lokale voortgang',
          en: 'Lessons, questions and local progress',
          de: 'Lektionen, Fragen und lokaler Fortschritt',
        ),
        icon: Icons.menu_book_outlined,
        imagePath: 'assets/images/species/species_3/1.jpg',
        onTap: () => push(TrainingScreen(locale: locale)),
      ),
      _HomeDestination(
        label: l10n.homeLearningMaterials,
        subtitle: _localized(
          locale,
          nl: 'Downloadbare specialistische uitbreidingen',
          en: 'Downloadable specialist learning packs',
          de: 'Herunterladbare Spezial-Lernpakete',
        ),
        icon: Icons.download_for_offline_outlined,
        imagePath: 'assets/images/species/species_4/1.jpg',
        onTap: () => push(
          LearningMaterialsScreen(
            locale: locale,
            service: learningMaterialsService,
          ),
        ),
      ),
      _HomeDestination(
        label: l10n.homeSourcesLicenses,
        subtitle: _localized(
          locale,
          nl: 'Herkomst, licenties en dataverantwoording',
          en: 'Sources, licences and data provenance',
          de: 'Quellen, Lizenzen und Datenherkunft',
        ),
        icon: Icons.info_outline,
        imagePath: 'assets/images/species/species_5/5.jpg',
        onTap: () => push(const SourcesScreen()),
      ),
    ];
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.intro,
    required this.destinations,
    required this.desktop,
  });

  final String intro;
  final List<_HomeDestination> destinations;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          desktop ? 28 : 16,
          desktop ? 28 : 16,
          desktop ? 28 : 16,
          20,
        ),
        children: [
          _HomeHero(intro: intro, desktop: desktop),
          const SizedBox(height: 18),
          const SafetyNotice(),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1100
                  ? 3
                  : constraints.maxWidth >= 620
                      ? 2
                      : 1;
              final aspectRatio = columns == 1 ? 2.35 : 1.55;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: destinations.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: aspectRatio,
                ),
                itemBuilder: (context, index) =>
                    _HomeDestinationCard(destination: destinations[index]),
              );
            },
          ),
          const SizedBox(height: 20),
          _DiscoveryPanel(desktop: desktop),
        ],
      ),
    );
  }
}

class _HomeHero extends StatelessWidget {
  const _HomeHero({required this.intro, required this.desktop});

  final String intro;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: desktop ? 280 : 210,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: AppTheme.forest,
      ),
      child: Stack(
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
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  AppTheme.forestDark.withValues(alpha: 0.94),
                  AppTheme.forest.withValues(alpha: 0.66),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(desktop ? 30 : 22),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gerards\nPaddestoelen Wegwijzer',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              height: 1.02,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Identify • Learn • Explore',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: const Color(0xFFF1EBDD),
                            ),
                      ),
                      const SizedBox(height: 12),
                      Flexible(
                        child: Text(
                          intro,
                          maxLines: desktop ? 3 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Colors.white.withValues(alpha: 0.92),
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (desktop) ...[
                  const SizedBox(width: 24),
                  const AppBrandMark(size: 170, borderRadius: 34),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeDestinationCard extends StatelessWidget {
  const _HomeDestinationCard({required this.destination});

  final _HomeDestination destination;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: AppTheme.creamStrong,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: destination.onTap,
        child: Row(
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Image.asset(
                destination.imagePath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFDCEAD9), Color(0xFFF1EBDD)],
                    ),
                  ),
                  child: Icon(
                    destination.icon,
                    size: 42,
                    color: AppTheme.forest,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      destination.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      destination.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.ink.withValues(alpha: 0.72),
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 10),
              child: Icon(Icons.chevron_right, color: AppTheme.forest),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscoveryPanel extends StatelessWidget {
  const _DiscoveryPanel({required this.desktop});

  final bool desktop;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(desktop ? 22 : 18),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F1E5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCFDDCE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline, color: AppTheme.forest, size: 30),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ontdek de fascinerende wereld van paddenstoelen',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Leer, vergelijk kenmerken en verken soorten met offline informatie, duidelijke stappen en interactieve lessen.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({
    required this.title,
    required this.destinations,
    required this.locale,
    required this.onLocaleChanged,
  });

  final String title;
  final List<_HomeDestination> destinations;
  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.forestDark,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
              child: Column(
                children: [
                  const AppBrandMark(size: 104, borderRadius: 24),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Identify • Learn • Explore',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                        ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFF2E6549)),
            const _SidebarHomeItem(),
            for (final destination in destinations)
              _SidebarDestinationItem(destination: destination),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: _LanguageSelector(
                locale: locale,
                onLocaleChanged: onLocaleChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarHomeItem extends StatelessWidget {
  const _SidebarHomeItem();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 4),
      child: Material(
        color: const Color(0xFF1F6A46),
        borderRadius: BorderRadius.circular(10),
        child: const ListTile(
          dense: true,
          leading: Icon(Icons.home_outlined, color: Colors.white),
          title: Text(
            'Home',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _SidebarDestinationItem extends StatelessWidget {
  const _SidebarDestinationItem({required this.destination});

  final _HomeDestination destination;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Icon(destination.icon, color: Colors.white),
      title: Text(
        destination.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white),
      ),
      onTap: destination.onTap,
    );
  }
}

class _MobileDrawer extends StatelessWidget {
  const _MobileDrawer({required this.title, required this.destinations});

  final String title;
  final List<_HomeDestination> destinations;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.forestDark,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Row(
                children: [
                  const AppBrandMark(size: 70, borderRadius: 16),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFF2E6549)),
            const ListTile(
              leading: Icon(Icons.home_outlined, color: Colors.white),
              title: Text('Home', style: TextStyle(color: Colors.white)),
            ),
            for (final destination in destinations)
              ListTile(
                leading: Icon(destination.icon, color: Colors.white),
                title: Text(
                  destination.label,
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  destination.onTap();
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector({
    required this.locale,
    required this.onLocaleChanged,
  });

  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: locale.languageCode,
        dropdownColor: AppTheme.creamStrong,
        iconEnabledColor: Colors.white,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        items: const [
          DropdownMenuItem(
            value: 'nl',
            child: Text('NL', style: TextStyle(color: AppTheme.ink)),
          ),
          DropdownMenuItem(
            value: 'en',
            child: Text('EN', style: TextStyle(color: AppTheme.ink)),
          ),
          DropdownMenuItem(
            value: 'de',
            child: Text('DE', style: TextStyle(color: AppTheme.ink)),
          ),
        ],
        selectedItemBuilder: (context) => const [
          Text('NL', style: TextStyle(color: Colors.white)),
          Text('EN', style: TextStyle(color: Colors.white)),
          Text('DE', style: TextStyle(color: Colors.white)),
        ],
        onChanged: (value) {
          if (value != null) onLocaleChanged(Locale(value));
        },
      ),
    );
  }
}

class _HomeDestination {
  const _HomeDestination({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.imagePath,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final String imagePath;
  final VoidCallback onTap;
}

String _localized(
  Locale locale, {
  required String nl,
  required String en,
  required String de,
}) {
  return switch (locale.languageCode) {
    'en' => en,
    'de' => de,
    _ => nl,
  };
}
