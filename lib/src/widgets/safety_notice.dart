import 'package:flutter/material.dart';

class SafetyNotice extends StatelessWidget {
  const SafetyNotice({super.key, required this.locale});
  final Locale locale;

  String get text {
    switch (locale.languageCode) {
      case 'nl':
        return 'Veiligheidswaarschuwing: eet nooit een paddenstoel uitsluitend op basis van identificatie door deze app. Vergissingen kunnen ernstige vergiftiging of overlijden veroorzaken. Laat eetbare paddenstoelen altijd controleren door een gekwalificeerde lokale deskundige.';
      case 'de':
        return 'Sicherheitshinweis: Verzehren Sie niemals einen Pilz ausschließlich aufgrund einer Bestimmung durch diese App. Fehler können schwere Vergiftungen oder den Tod verursachen. Lassen Sie essbare Pilze immer von einer qualifizierten örtlichen Fachperson überprüfen.';
      default:
        return 'Safety notice: Never consume a mushroom based solely on identification by this app. Mistakes may cause serious poisoning or death. Always have edible mushrooms verified by a qualified local expert.';
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        color: Theme.of(context).colorScheme.errorContainer,
        child: Text(text, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer, fontSize: 12)),
      );
}
