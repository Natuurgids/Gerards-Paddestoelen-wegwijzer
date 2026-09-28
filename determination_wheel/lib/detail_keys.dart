class DetailOption {
  const DetailOption(this.label,{this.next,this.result});
  final String label;
  final String? next;
  final String? result;
}

class DetailStep {
  const DetailStep({required this.id,required this.title,required this.help,required this.options});
  final String id;
  final String title;
  final String help;
  final List<DetailOption> options;
}

class DetailKey {
  const DetailKey({required this.id,required this.title,required this.start,required this.steps,required this.sourceNote});
  final String id;
  final String title;
  final String start;
  final Map<String,DetailStep> steps;
  final String sourceNote;
}

// Only distinctions explicitly represented in the supplied source material belong
// here. Do not infer missing species-level branches from general mycology knowledge.
const russulaceaeDetailKey=DetailKey(
  id:'russulaceae',
  title:'Russulaceae-detailsleutel',
  start:'milk',
  sourceNote:'Bronondersteunde splitsing op melk/sap; de aangeleverde bron bevat nog geen volledige soortensleutel.',
  steps:{
    'milk':DetailStep(
      id:'milk',
      title:'Komt er melksap vrij bij beschadiging?',
      help:'Beschadig voorzichtig een plaatje of het vlees en observeer of er melk/sap verschijnt.',
      options:[
        DetailOption('Melksap aanwezig',result:'Lactarius'),
        DetailOption('Geen melksap',result:'Russula'),
        DetailOption('Niet beoordeeld',result:'Russula/Lactarius'),
      ],
    ),
  },
);

DetailKey? detailKeyForGenusHint(String? hint){
  if(hint=='Lactarius'||hint=='Russula') return russulaceaeDetailKey;
  return null;
}
