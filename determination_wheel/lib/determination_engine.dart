class Candidate {
  const Candidate(this.name,{this.form,this.underside,this.spore,this.gill,this.velum,this.hygro,this.surface,this.substrate});
  final String name;
  final Set<String>? form,underside,spore,gill,velum,hygro,surface,substrate;

  String? conflict(Map<int,String> answers){
    String? check(int step,String label,Set<String>? allowed){
      final value=answers[step];
      if(allowed==null||value==null||isUnknown(value)||allowed.contains(value)) return null;
      return '$label: waargenomen “$value”, bronprofiel verwacht ${allowed.join(' / ')}';
    }
    return check(1,'vruchtlichaam',form)??
      check(4,'sporenvormende onderzijde',underside)??
      check(5,'hoedoppervlak',surface)??
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

// Candidate constraints below are hard exclusion criteria only. Source traits
// described as "vaak", "meestal" or otherwise typical belong in the detail
// text, not here: absence of a typical trait must not exclude a candidate.
const candidates=<Candidate>[
  Candidate('Boleten',form:{'Hoed + steel'},underside:{'Buisjes / poriën'}),
  Candidate('Schelpzwammen',underside:{'Plaatjes'}),
  Candidate('Amanieten · Amanita',form:{'Hoed + steel'},underside:{'Plaatjes'},spore:{'Wit / crème'},gill:{'Vrij'},velum:{'Ring','Beurs / volva','Beide'}),
  Candidate('Honingzwammen · Armillaria',form:{'Hoed + steel'},underside:{'Plaatjes'},spore:{'Wit / crème'}),
  Candidate('Krulzomen · Paxillus/Tapinella',form:{'Hoed + steel'},underside:{'Plaatjes'},spore:{'Bruin / roest'},gill:{'Aflopend'}),
  Candidate('Cantharellen · Cantharellus',form:{'Hoed + steel'},underside:{'Plooien / ribben'}),
  Candidate('Parasolzwammen (+)',spore:{'Wit / crème'},gill:{'Vrij'},velum:{'Ring','Beide'},surface:{'Glad','Schubbig / wrattig'},substrate:{'Bodem / strooisel'}),
  Candidate('Fopzwammen · Laccaria',spore:{'Wit / crème'},velum:{'Geen zichtbaar'},hygro:{'Ja'}),
  Candidate('Wasplaten / Slijmkoppen',spore:{'Wit / crème'}),
  Candidate('Trechtertjes · Omphalina/Rickenella',spore:{'Wit / crème'},gill:{'Aflopend'},velum:{'Geen zichtbaar'}),
  Candidate('Taailingen (+)',spore:{'Wit / crème'},velum:{'Geen zichtbaar'}),
  Candidate('Hertenzwammen · Pluteus',spore:{'Roze'},gill:{'Vrij'},velum:{'Geen zichtbaar'}),
  Candidate('Bundelzwammen (+) · Pholiota/Kuehneromyces',spore:{'Bruin / roest'},gill:{'Aangehecht'},velum:{'Ring','Geen zichtbaar'}),
  Candidate('Kaalkopjes / Stropharia (+)',spore:{'Purperbruin / donker'}),
  Candidate('Mosklokjes · Galerina',spore:{'Bruin / roest'}),
  Candidate('Vaalhoeden · Hebeloma',spore:{'Bruin / roest'},velum:{'Geen zichtbaar'}),
  Candidate('Leemhoeden · Agrocybe',spore:{'Bruin / roest'}),
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
