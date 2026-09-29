class Candidate {
  const Candidate(this.name,{this.form,this.underside,this.spore,this.gill,this.velum,this.hygro,this.surface,this.substrate,this.size,this.trama});
  final String name;
  final Set<String>? form,underside,spore,gill,velum,hygro,surface,substrate,size,trama;

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
      check(17,'substraat',substrate)??
      check(19,'afmetingen',size)??
      check(23,'trama / vlees',trama);
  }

  List<String> supporting(Map<int,String> answers){
    final out=<String>[];
    void check(int step,String label,Set<String>? allowed){
      final value=answers[step];
      if(allowed!=null&&value!=null&&!isUnknown(value)&&allowed.contains(value)) out.add('$label: $value');
    }
    check(1,'vruchtlichaam',form);check(4,'onderzijde',underside);check(5,'hoedoppervlak',surface);check(6,'lamellen',gill);check(7,'velum',velum);check(8,'hygrofaan',hygro);check(9,'sporenkleur',spore);check(17,'substraat',substrate);check(19,'afmetingen',size);check(23,'trama / vlees',trama);
    return out;
  }

  bool matches(Map<int,String> answers)=>conflict(answers)==null;

  MatchScore score(Map<int,String> answers){
    var matched=0,observed=0,unknown=0,unanswered=0;
    void check(int step,Set<String>? allowed){
      if(allowed==null)return;
      final value=answers[step];
      if(value==null){unanswered++;return;}
      if(isUnknown(value)){unknown++;return;}
      observed++;
      if(allowed.contains(value))matched++;
    }
    check(1,form);check(4,underside);check(5,surface);check(6,gill);check(7,velum);check(8,hygro);check(9,spore);check(17,substrate);check(19,size);check(23,trama);
    final percent=observed==0?null:(100*matched/observed).round();
    return MatchScore(percent:percent,matched:matched,observed:observed,unknown:unknown,unanswered:unanswered);
  }
}

class MatchScore {
  const MatchScore({required this.percent,required this.matched,required this.observed,required this.unknown,required this.unanswered});
  final int? percent;
  final int matched,observed,unknown,unanswered;
  int get assessed=>observed+unknown;
  int get relevant=>assessed+unanswered;
  double get coverage=>relevant==0?0:assessed/relevant;
  bool get complete=>relevant>0&&unanswered==0;
  String get label{
    final details='${unknown>0?' · $unknown onzeker':''}${unanswered>0?' · $unanswered nog niet gevraagd':''} · ${(coverage*100).round()}% dekking';
    return percent==null?'Nog geen passende beoordeelde bronkenmerken$details':'Match $percent% · $matched/$observed passende kenmerken$details';
  }
}

bool isUnknown(String value){
  final v=value.toLowerCase();
  return v=='onzeker'||v.contains('onzeker')||v.startsWith('niet ')||v=='niet beoordeeld';
}

// Candidate constraints below are hard exclusion criteria only. Source traits
// described as "vaak", "meestal" or otherwise typical belong in the detail
// text, not here: absence of a typical trait must not exclude a candidate.
const candidates=<Candidate>[
  // The supplied dictionary describes Boletales as fleshy fungi with a distinct cap/stem and, ordinarily, a tubular hymenophore; no source-backed spore-colour exclusion is added.
  Candidate('Boleten',form:{'Hoed + steel'},underside:{'Buisjes / poriën'}),
  Candidate('Schelpzwammen',underside:{'Plaatjes'}),
  // Pleurotus source profile explicitly gives no velum, decurrent whitish gills, and a white-to-cream spore print; short lateral stems and toughness are only typical.
  Candidate('Oesterzwammen · Pleurotus',underside:{'Plaatjes'},spore:{'Wit / crème'},gill:{'Aflopend'},velum:{'Geen zichtbaar'}),
  Candidate('Amanieten · Amanita',form:{'Hoed + steel'},underside:{'Plaatjes'}),
  Candidate('Honingzwammen · Armillaria',form:{'Hoed + steel'},underside:{'Plaatjes'}),
  // Paxillus/Tapinella source profile explicitly gives (medium-)large stature, strongly decurrent gills, dark-brown bruising flesh and a brown spore print.
  Candidate('Krulzomen · Paxillus/Tapinella',form:{'Hoed + steel'},underside:{'Plaatjes'},spore:{'Bruin / roest'},gill:{'Aflopend'},size:{'Middelgroot','Groot'},trama:{'Verkleurt bij druk/wrijven'}),
  // Cantharellus source profile explicitly gives a centrally stalked cap with lamella-like/vein-like ridges and a cream-yellowish spore print.
  Candidate('Cantharellen · Cantharellus',form:{'Hoed + steel'},underside:{'Plooien / ribben'},spore:{'Wit / crème'}),
  // The supplied Lepiota-group profile gives free gills, a smooth-or-scaly cap, white/cream-to-pale-pink spores and saprotrophic growth on soil; velum/ring are only typical.\n  Candidate('Parasolzwammen (+)',spore:{'Wit / crème','Roze'},gill:{'Vrij'},surface:{'Glad','Schubbig / wrattig'},substrate:{'Bodem / strooisel'}),
  // Source profile explicitly states: small, no velum, white spores, strongly hygrophanous.
  Candidate('Fopzwammen · Laccaria',spore:{'Wit / crème'},velum:{'Geen zichtbaar'},hygro:{'Ja'},size:{'Klein'}),
  // The 2015 combined Hygrocybe/Hygrophorus profile explicitly gives small-to-medium fruitbodies and a white spore print; gill/cap colour and velum are variable.
  Candidate('Wasplaten / Slijmkoppen',spore:{'Wit / crème'},size:{'Klein','Middelgroot'}),
  // Omphalina/Rickenella are explicitly small, without velum, with decurrent gills and a white-to-cream spore print; colour and substrate are only typical.
  Candidate('Trechtertjes · Omphalina/Rickenella',spore:{'Wit / crème'},gill:{'Aflopend'},velum:{'Geen zichtbaar'},size:{'Klein'}),
  // Taailingen are explicitly small-to-medium, without velum, with a white-to-cream spore print; toughness is only typical.
  Candidate('Taailingen (+)',spore:{'Wit / crème'},velum:{'Geen zichtbaar'},size:{'Klein','Middelgroot'}),
  // Pluteus source profile explicitly gives no velum, free gills and a pink spore print; wood substrate is only typical.
  Candidate('Hertenzwammen · Pluteus',spore:{'Roze'},gill:{'Vrij'},velum:{'Geen zichtbaar'}),
  Candidate('Bundelzwammen (+) · Pholiota/Kuehneromyces',spore:{'Bruin / roest'},gill:{'Aangehecht'}),
  // Stropharia/kaalkopjes source profile makes a purple-tinted spore print categorical; velum is explicitly variable.
  Candidate('Kaalkopjes / Stropharia (+)',spore:{'Purperbruin / donker'}),
  // Galerina source profile explicitly states small species and an ochre-to-reddish-brown spore print; velum/substrate are variable.
  Candidate('Mosklokjes · Galerina',spore:{'Bruin / roest'},size:{'Klein'}),
  // Source profile is categorical here: without velum, with a pale-brown spore print.
  Candidate('Vaalhoeden · Hebeloma',spore:{'Bruin / roest'},velum:{'Geen zichtbaar'}),
  // Agrocybe source profile makes the pale-brown spore print categorical; velum and soil are only most/usually traits.
  Candidate('Leemhoeden · Agrocybe',spore:{'Bruin / roest'}),
  Candidate('Russulaceae · Russula/Lactarius',trama:{'Broos / breekt krijtachtig'}),
];

class DeterminationResult {
  const DeterminationResult({required this.remaining,required this.excluded,this.genusHint});
  final List<Candidate> remaining;
  final Map<Candidate,String> excluded;
  final String? genusHint;
}

void rankCandidates(List<Candidate> items,Map<int,String> answers){
  items.sort((a,b){
    final sa=a.score(answers),sb=b.score(answers);
    final byPercent=(sb.percent??-1).compareTo(sa.percent??-1);
    if(byPercent!=0)return byPercent;
    final byEvidence=sb.matched.compareTo(sa.matched);
    if(byEvidence!=0)return byEvidence;
    return a.name.compareTo(b.name);
  });
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
    // The supplied dictionary explicitly separates the two genera by milk on damage.
    if(answers[22]=='Melksap aanwezig') genusHint='Lactarius';
    if(answers[22]=='Geen melksap') genusHint='Russula';
  }
  rankCandidates(remaining,answers);
  return DeterminationResult(remaining:remaining,excluded:excluded,genusHint:genusHint);
}
