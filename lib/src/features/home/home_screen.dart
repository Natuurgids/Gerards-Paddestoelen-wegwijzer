import 'package:flutter/material.dart';
import '../../widgets/safety_notice.dart';
import '../identify/identify_screen.dart';
import '../species/species_browser_screen.dart';
import '../training/training_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.locale, required this.onLocaleChanged});
  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;

  static const _copy = {
    'nl': {'title':'Gerards Paddestoelen Wegwijzer','identify':'Determineren','learn':'Leren','browse':'Soorten bekijken','intro':'Offline paddenstoelen determineren en mycologie leren.'},
    'en': {'title':'Gerard’s Mushroom Guide','identify':'Identify','learn':'Learn','browse':'Browse species','intro':'Identify mushrooms and learn mycology fully offline.'},
    'de': {'title':'Gerards Pilz-Wegweiser','identify':'Bestimmen','learn':'Lernen','browse':'Arten ansehen','intro':'Pilze offline bestimmen und Mykologie lernen.'},
  };

  @override
  Widget build(BuildContext context) {
    final c=_copy[locale.languageCode] ?? _copy['en']!;
    return Scaffold(
      appBar:AppBar(title:Text(c['title']!),actions:[DropdownButtonHideUnderline(child:DropdownButton<String>(value:locale.languageCode,items:const [DropdownMenuItem(value:'nl',child:Text('NL')),DropdownMenuItem(value:'en',child:Text('EN')),DropdownMenuItem(value:'de',child:Text('DE'))],onChanged:(v){if(v!=null)onLocaleChanged(Locale(v));})),const SizedBox(width:12)]),
      body:SafeArea(child:Column(children:[
        Expanded(child:ListView(padding:const EdgeInsets.all(20),children:[
          Text(c['intro']!,style:Theme.of(context).textTheme.titleMedium),
          const SizedBox(height:24),
          FilledButton.icon(onPressed:()=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>IdentifyScreen(locale:locale))),icon:const Icon(Icons.search),label:Text(c['identify']!)),
          const SizedBox(height:12),
          FilledButton.tonalIcon(onPressed:()=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>TrainingScreen(locale:locale))),icon:const Icon(Icons.school_outlined),label:Text(c['learn']!)),
          const SizedBox(height:12),
          OutlinedButton.icon(onPressed:()=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>SpeciesBrowserScreen(locale:locale))),icon:const Icon(Icons.eco_outlined),label:Text(c['browse']!)),
        ])),
        SafetyNotice(locale:locale),
      ])),
    );
  }
}
