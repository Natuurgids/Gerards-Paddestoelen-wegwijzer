class Candidate {
  const Candidate(this.name,{this.spore,this.gill,this.velum,this.hygro,this.surface,this.substrate});
  final String name;
  final Set<String>? spore,gill,velum,hygro,surface,substrate;

  String? conflict(Map<int,String> answers){
    String? check(int step,String label,Set<String>? allowed){
      final value=answers[step];
      if(allowed==null||value==null||isUnknown(value)||allowed.contains(value)) return null;
      return '$label: waargenomen “$value”, bronprofiel verwacht ${allowed.join(' / ')}';
    }
    return check(5,'hoedoppervlak',surface)??
      check(6,'lamelaanhechting',gill)??
      check(7,'velum',velum)??
      check(8,'hygrofaan',hygro)??
      check(9,'sporenkleur',spore)??
      check(17,'substraat',substrate);
  }

  bool matches(Map<int,String> answers)=>conflict(answers)==null;
}

bool isUnknown(String value){
  final v=value.toLowerCase();
  return v=='onzeker'||v.contains('onzeker')||v.startsWith('niet ')||v=='niet beoordeeld';
}

const candidates=<Candidate>[
  Candidate('Parasolzwammen (+)',spore:{'Wit / crème'},gill:{'Vrij'},velum:{'Ring','Beide'},surface:{'Glad','Schubbig / wrattig'},substrate:{'Bodem / strooisel'}),
  Candidate('Fopzwammen · Laccaria',spore:{'Wit / crème'},velum:{'Geen zichtbaar'},hygro:{'Ja'},substrate:{'Bodem / strooisel','Gras / mos'}),
  Candidate('Wasplaten / Slijmkoppen',spore:{'Wit / crème'}),
  Candidate('Trechtertjes · Omphalina/Rickenella',spore:{'Wit / crème'},gill:{'Aflopend'},velum:{'Geen zichtbaar'}),
  Candidate('Taailingen (+)',spore:{'Wit / crème'},velum:{'Geen zichtbaar'}),
  Candidate('Hertenzwammen · Pluteus',spore:{'Roze'},gill:{'Vrij'},velum:{'Geen zichtbaar'},substrate:{'Dood hout','Levend hout'}),
  Candidate('Bundelzwammen (+) · Pholiota/Kuehneromyces',spore:{'Bruin / roest'},gill:{'Aangehecht'},velum:{'Ring','Geen zichtbaar'},substrate:{'Dood hout','Levend hout'}),
  Candidate('Kaalkopjes / Stropharia (+)',spore:{'Purperbruin / donker'}),
  Candidate('Mosklokjes · Galerina',spore:{'Bruin / roest'},substrate:{'Gras / mos','Dood hout'}),
  Candidate('Vaalhoeden · Hebeloma',spore:{'Bruin / roest'},velum:{'Geen zichtbaar'},substrate:{'Bodem / strooisel'}),
  Candidate('Leemhoeden · Agrocybe',spore:{'Bruin / roest'},substrate:{'Bodem / strooisel'}),
  Candidate('Russulaceae · Russula/Lactarius',spore:{'Wit / crème','Bruin / roest'},substrate:{'Bodem / strooisel'}),
];

class DeterminationResult {
  const DeterminationResult({required this.remaining,required this.excluded,this.genusHint});
  final List<Candidate> remaining;
  final Map<Candidate,String> excluded;
  final String? genusHint;
}

DeterminationResult determine(Map<int,String> answers){
  final remaining=<Candidate>[];
  final excluded=<Candidate,String>{};
  for(final candidate in candidates){
    final reason=candidate.conflict(answers);
    if(reason==null){remaining.add(candidate);}else{excluded[candidate]=reason;}
  }
  String? genusHint;
  final russulaceae=remaining.any((x)=>x.name.startsWith('Russulaceae'));
  if(russulaceae){
    if(answers[22]=='Melksap aanwezig') genusHint='Lactarius';
    if(answers[22]=='Geen melksap') genusHint='Russula';
  }
  return DeterminationResult(remaining:remaining,excluded:excluded,genusHint:genusHint);
}
