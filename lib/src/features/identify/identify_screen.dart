import 'package:flutter/material.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../widgets/safety_notice.dart';
import '../species/species_screen.dart';

class IdentifyScreen extends StatefulWidget {
  const IdentifyScreen({super.key, required this.locale});
  final Locale locale;

  @override
  State<IdentifyScreen> createState()=>_IdentifyScreenState();
}

class _IdentifyScreenState extends State<IdentifyScreen>{
  final _repo=IdentificationRepository();
  late Future<List<TraitChoice>> _choices;
  final Map<int,int> _selected={};
  List<IdentificationCandidate>? _results;

  @override
  void initState(){super.initState();_choices=_repo.choices(widget.locale.languageCode);}

  String t(String nl,String en,String de)=>widget.locale.languageCode=='nl'?nl:widget.locale.languageCode=='de'?de:en;

  Future<void> _identify() async {
    final r=await _repo.identify(widget.locale.languageCode,_selected);
    if(mounted)setState(()=>_results=r);
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:Text(t('Determineren','Identify','Bestimmen'))),
    body:SafeArea(child:Column(children:[
      Expanded(child:FutureBuilder<List<TraitChoice>>(future:_choices,builder:(context,snapshot){
        if(!snapshot.hasData)return const Center(child:CircularProgressIndicator());
        final groups=<int,List<TraitChoice>>{};
        for(final c in snapshot.data!){groups.putIfAbsent(c.traitId,()=>[]).add(c);}
        return ListView(padding:const EdgeInsets.all(16),children:[
          Text(t('Kies alleen kenmerken die je zeker ziet.','Select only characteristics you can observe confidently.','Wähle nur Merkmale, die du sicher beobachten kannst.')),
          const SizedBox(height:12),
          ...groups.values.map((items)=>Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(items.first.traitLabel,style:Theme.of(context).textTheme.titleMedium),
            ...items.map((c)=>RadioListTile<int>(title:Text(c.optionLabel),value:c.optionId,groupValue:_selected[c.traitId],onChanged:(v)=>setState((){if(v!=null)_selected[c.traitId]=v;}))),
            if(_selected.containsKey(items.first.traitId))TextButton(onPressed:()=>setState(()=>_selected.remove(items.first.traitId)),child:Text(t('Overslaan','Clear','Löschen'))),
          ])))),
          FilledButton.icon(onPressed:_identify,icon:const Icon(Icons.filter_alt),label:Text(t('Toon kandidaten','Show candidates','Kandidaten anzeigen'))),
          if(_results!=null)...[
            const SizedBox(height:20),
            Text(t('Resultaten','Results','Ergebnisse'),style:Theme.of(context).textTheme.titleLarge),
            if(_results!.isEmpty)Padding(padding:const EdgeInsets.all(16),child:Text(t('Geen overeenkomsten. Pas kenmerken aan.','No matches. Adjust the selected traits.','Keine Treffer. Passe die Merkmale an.'))),
            ..._results!.map((r)=>ListTile(
              title:Text(r.species.commonName),
              subtitle:Text('${r.species.scientificName} · ${(r.score*100).round()}% · ${r.matched}/${r.requested}'),
              trailing:const Icon(Icons.chevron_right),
              onTap:()=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>SpeciesScreen(locale:widget.locale,speciesId:r.species.id))),
            )),
          ]
        ]);
      })),
      SafetyNotice(locale:widget.locale),
    ])),
  );
}
