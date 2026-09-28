class DetailOption {
  const DetailOption(this.label,{this.next,this.result});
  final String label;
  final String? next;
  final String? result;
}
class DetailStep {
  const DetailStep({required this.id,required this.title,required this.help,required this.options});
  final String id,title,help; final List<DetailOption> options;
}
class DetailKey {
  const DetailKey({required this.id,required this.title,required this.start,required this.steps,required this.sourceNote});
  final String id,title,start,sourceNote; final Map<String,DetailStep> steps;
}
// Only distinctions already encoded from the supplied source material belong here.
// These keys deliberately stop at group/genus level when no complete species key is present.
const russulaceaeDetailKey=DetailKey(id:'russulaceae',title:'Russulaceae-detailsleutel',start:'milk',sourceNote:'Bronondersteunde splitsing op melk/sap; de aangeleverde bron bevat nog geen volledige soortensleutel.',steps:{'milk':DetailStep(id:'milk',title:'Komt er melksap vrij bij beschadiging?',help:'Beschadig voorzichtig een plaatje of het vlees en observeer of er melk/sap verschijnt.',options:[DetailOption('Melksap aanwezig',result:'Lactarius'),DetailOption('Geen melksap',result:'Russula'),DetailOption('Niet beoordeeld',result:'Russula/Lactarius')])});
const pluteusDetailKey=DetailKey(id:'pluteus',title:'Hertenzwammen-detailsleutel',start:'confirm',sourceNote:'Deze controle gebruikt uitsluitend de reeds brongecodeerde combinatie van roze sporen, vrije plaatjes, geen zichtbaar velum en houtsubstraat.',steps:{'confirm':DetailStep(id:'confirm',title:'Controleer de combinatie',help:'Bevestig de combinatie van vrije plaatjes, roze sporen en groei op hout. De huidige bronset ondersteunt daarna alleen het geslacht/groepniveau.',options:[DetailOption('Combinatie bevestigd',result:'Pluteus (Hertenzwammen)'),DetailOption('Niet zeker',result:'Pluteus-kandidaat; verdere detailsleutel nodig')])});
const galerinaDetailKey=DetailKey(id:'galerina',title:'Mosklokjes-detailsleutel',start:'substrate',sourceNote:'De huidige broncodering ondersteunt bruine/roestkleurige sporen en mos of dood hout als relevante combinatie, maar nog geen soortonderscheid.',steps:{'substrate':DetailStep(id:'substrate',title:'Waar groeit het exemplaar?',help:'Controleer het substraat dat in de hoofdsleutel is waargenomen.',options:[DetailOption('Gras / mos',result:'Galerina (Mosklokjes) — kandidaatgroep'),DetailOption('Dood hout',result:'Galerina (Mosklokjes) — kandidaatgroep'),DetailOption('Onzeker',result:'Galerina-kandidaat; substraat opnieuw beoordelen')])});
const hebelomaDetailKey=DetailKey(id:'hebeloma',title:'Vaalhoeden-detailsleutel',start:'confirm',sourceNote:'Deze controle gebruikt alleen de reeds gecodeerde bronkenmerken: bruine/roestkleurige sporen, geen zichtbaar velum en bodem/strooisel.',steps:{'confirm':DetailStep(id:'confirm',title:'Controleer het bronprofiel',help:'Bevestig dat sporenkleur, velum en substraat overeenkomen. Voor soortniveau ontbreken nog gecodeerde detailcriteria.',options:[DetailOption('Profiel bevestigd',result:'Hebeloma (Vaalhoeden)'),DetailOption('Niet zeker',result:'Hebeloma-kandidaat; verdere detailsleutel nodig')])});
const agrocybeDetailKey=DetailKey(id:'agrocybe',title:'Leemhoeden-detailsleutel',start:'confirm',sourceNote:'De huidige broncodering ondersteunt bruine/roestkleurige sporen en bodem/strooisel; zij ondersteunt nog geen betrouwbare soortnaam.',steps:{'confirm':DetailStep(id:'confirm',title:'Controleer sporenkleur en substraat',help:'Gebruik deze stap als controle, niet als soortdeterminatie.',options:[DetailOption('Combinatie bevestigd',result:'Agrocybe (Leemhoeden)'),DetailOption('Niet zeker',result:'Agrocybe-kandidaat; verdere detailsleutel nodig')])});

DetailKey? detailKeyFor({String? genusHint,Iterable<String> candidateNames=const []}){
  if(genusHint=='Lactarius'||genusHint=='Russula') return russulaceaeDetailKey;
  if(candidateNames.length!=1) return null;
  final name=candidateNames.first;
  if(name.contains('Pluteus')) return pluteusDetailKey;
  if(name.contains('Galerina')) return galerinaDetailKey;
  if(name.contains('Hebeloma')) return hebelomaDetailKey;
  if(name.contains('Agrocybe')) return agrocybeDetailKey;
  return null;
}
