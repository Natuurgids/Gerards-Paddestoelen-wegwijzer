import 'package:flutter/material.dart';
import '../species/species_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.locale, required this.onLocaleChanged});

  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;

  static const _copy = {
    'nl': {
      'title': 'Gerards Paddestoelen Wegwijzer',
      'identify': 'Determineren',
      'learn': 'Leren',
      'browse': 'Soorten bekijken',
      'safety': 'Veiligheidswaarschuwing: Eet nooit een paddenstoel uitsluitend op basis van identificatie door deze app. Vergissingen kunnen ernstige vergiftiging of overlijden veroorzaken. Laat eetbare paddenstoelen altijd controleren door een gekwalificeerde lokale deskundige.'
    },
    'en': {
      'title': 'Gerard’s Mushroom Guide',
      'identify': 'Identify',
      'learn': 'Learn',
      'browse': 'Browse species',
      'safety': 'Safety notice: Never consume a mushroom based solely on identification by this app. Mistakes may cause serious poisoning or death. Always have edible mushrooms verified by a qualified local expert.'
    },
    'de': {
      'title': 'Gerards Pilz-Wegweiser',
      'identify': 'Bestimmen',
      'learn': 'Lernen',
      'browse': 'Arten ansehen',
      'safety': 'Sicherheitshinweis: Verzehren Sie niemals einen Pilz ausschließlich aufgrund einer Bestimmung durch diese App. Fehler können schwere Vergiftungen oder den Tod verursachen. Lassen Sie essbare Pilze immer von einer qualifizierten örtlichen Fachperson überprüfen.'
    },
  };

  @override
  Widget build(BuildContext context) {
    final c = _copy[locale.languageCode] ?? _copy['en']!;
    return Scaffold(
      appBar: AppBar(
        title: Text(c['title']!),
        actions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: locale.languageCode,
              items: const [
                DropdownMenuItem(value: 'nl', child: Text('NL')),
                DropdownMenuItem(value: 'en', child: Text('EN')),
                DropdownMenuItem(value: 'de', child: Text('DE')),
              ],
              onChanged: (v) {
                if (v != null) onLocaleChanged(Locale(v));
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
                  FilledButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.search),
                    label: Text(c['identify']!),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: () {},
                    icon: const Icon(Icons.school_outlined),
                    label: Text(c['learn']!),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SpeciesScreen(locale: locale),
                      ),
                    ),
                    icon: const Icon(Icons.eco_outlined),
                    label: Text(c['browse']!),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Theme.of(context).colorScheme.errorContainer,
              child: Text(
                c['safety']!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
