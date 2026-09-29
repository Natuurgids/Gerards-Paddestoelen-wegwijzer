class SourceTaxonCatalog {
  const SourceTaxonCatalog({required this.group,required this.profile,required this.taxa,required this.note,this.nextEvidence=const []});
  final String group;
  final List<String> profile;
  final List<String> taxa;
  final String note;
  final List<String> nextEvidence;

  bool get hasNamedPossibilities=>taxa.isNotEmpty;
}

// Transcribed only from the supplied Likonadag presentation. These names are
// reference targets, not automatic determinations: the presentation lists them
// but does not provide the complete branch criteria needed to distinguish each.
const sourceCatalogs=<String,SourceTaxonCatalog>{
  'pleurotus':SourceTaxonCatalog(
    group:'Oesterzwammen (Pleurotus)',
    profile:['Klein tot groot zonder velum','Vaak relatief taai en uitdrogingsbestendig','Lamellen witachtig en aflopend','Steel meestal kort en zijdelings aangehecht','Sporee wit tot roomkleurig','Parasieten en saprofyten; veroorzaken witrot'],
    taxa:[],
    note:'De 2016-bron ondersteunt Pleurotus als eigen geslachtsgroep met vijf soorten in Vlaanderen, maar noemt in de geraadpleegde passage geen soortnamen om als afzonderlijke mogelijkheden te tonen.',
    nextEvidence:['Gebruik een volledige Pleurotus-detailsleutel','Microscopie of DNA kan nodig zijn wanneer soorten macroscopisch niet betrouwbaar te scheiden zijn'],
  ),
  'pluteus':SourceTaxonCatalog(
    group:'Hertenzwammen (Pluteus)',
    profile:['Klein tot groot en breekbaar','Zonder velum / zonder beurs','Lamellen buikig en vrij; bij rijpheid rozig','Sporee roze','Saprotroof; vaak op hout'],
    taxa:['Knolvoethertenzwam','Pluishoedhertenzwam','Roetkleurige hertenzwam','Gewone hertenzwam','Bruinsnedehertenzwam','Geaderde hertenzwam','Geelsteelhertenzwam','Grauwgroene hertenzwam'],
    note:'De bron noemt deze hertenzwammen, maar geeft op deze dia’s geen volledige kenmerkenmatrix om ze onderling betrouwbaar uit te sleutelen.',
    nextEvidence:['Vergelijk de volledige detailsleutel per soort','Microscopie kan nodig zijn wanneer macroscopische kenmerken overlappen'],
  ),
  'agrocybe':SourceTaxonCatalog(
    group:'Leemhoeden (Agrocybe)',
    profile:['Klein tot groot en vlezig','Bij de meeste soorten velum','Hoed glad, vaak vettig, zonder radiale structuur','Sporee vaalbruin','Saprotroof; meestal op de bodem'],
    taxa:['Knolletjesleemhoed','Grasleemhoed','Populierleemhoed','Vroege leemhoed','Leverkleurige leemhoed','Fluweelleemhoed','Moerasleemhoed','Gaderde leemhoed (Agrocybe rivulosa)'],
    note:'De bron toont deze soortnamen en noemt Agrocybe rivulosa bij een koffie-met-melk-kleurige sporee, maar levert hier geen volledige soortensleutel.',
    nextEvidence:['Vergelijk de volledige detailsleutel per soort','Controleer zo nodig microscopische kenmerken'],
  ),
  'galerina':SourceTaxonCatalog(
    group:'Mosklokjes (Galerina)',
    profile:['Kleine, tere soorten','Bruine lamellen; soms velum','Sporee oker tot rosbruin','Saprotroof; vaak tussen mossen, soms op dood hout'],
    taxa:[],
    note:'De geraadpleegde bronpassage noemt de groep en ecologie maar geen voldoende uitgewerkte soortonderscheidingen.',
  ),
  'hebeloma':SourceTaxonCatalog(
    group:'Vaalhoeden (Hebeloma)',
    profile:['Klein tot groot zonder velum','Hoed vaak met bruine tinten','Lamellen bleekbruin; bij sommige soorten tranend','Sporee vaalbruin','Alle soorten vormen ectomycorrhiza'],
    taxa:[],
    note:'De geraadpleegde bronpassage ondersteunt het geslachtsprofiel, niet een volledige soortensleutel.',
  ),
  'parasol':SourceTaxonCatalog(group:'Parasolzwammen (+) (Lepiota)',profile:['Klein tot groot, vaak fragiel met velum','Hoed glad of schubbig','Lamellen vrij','Sporee wit, crème tot bleekroze','Steel slank, vaak met ring','Saprotroof op de bodem'],taxa:[],note:'De bron groepeert Lepiota, Cystolepiota, Macrolepiota, Leucoagaricus en Leucocoprinus; deze kenmerken bepalen geen soort.'),
  'laccaria':SourceTaxonCatalog(group:'Fopzwammen (Laccaria)',profile:['Klein zonder velum','Overwegend paarse tot baksteenrode tinten','Lamellen dik en wijd uiteenstaand','Witte sporen','Hoed sterk hygrofaan','Ectomycorrhiza'],taxa:[],note:'De bron ondersteunt Laccaria als geslacht, maar hier geen volledige soortensleutel.'),
  'waxcaps':SourceTaxonCatalog(group:'Wasplaten / Slijmkoppen (Hygrocybe/Hygrophorus)',profile:['Klein tot middelgroot','Vettige, wijd uiteenstaande lamellen','Sporee wit','Hoed droog of slijmerig, glad of schubbig','Saprotroof op de bodem; wasplaten meestal in graslanden'],taxa:[],note:'De bron geeft een groepsprofiel en aantallen, maar hier geen volledige soortensleutel.'),
  'funnel':SourceTaxonCatalog(group:'Trechtertjes (Omphalina/Rickenella)',profile:['Klein, trechtervormig','Wijd uiteenstaande aflopende lamellen','Zonder velum','Sporee wit tot roomkleurig','Saprotroof; vaak op nauwelijks begroeide bodem'],taxa:[],note:'De bron ondersteunt de geslachtsgroep, niet een betrouwbare soortuitkomst.'),
  'toughshanks':SourceTaxonCatalog(group:'Taailingen en verwanten',profile:['Klein tot middelgroot','Zonder velum','Vaak taai en uitdrogingsbestendig','Sporee wit tot roomkleurig','Saprotroof'],taxa:[],note:'De bron groepeert meerdere geslachten; verdere soortonderscheiding vraagt een detailsleutel.'),
  'pholiota':SourceTaxonCatalog(group:'Bundelzwammen (+) (Pholiota/Kuehneromyces)',profile:['Klein tot groot en vlezig','Vaak met velum','Hoed droog of slijmerig, glad of schubbig','Lamellen aangehecht','Sporee bruin','Vaak op hout'],taxa:[],note:'De bron ondersteunt deze groepskenmerken; niet elke soort kan hiermee worden onderscheiden.'),
  'stropharia':SourceTaxonCatalog(group:'Kaalkopjes / Stropharia (+)',profile:['Klein tot groot','Purpertint in sporee en vaak rijpe lamellen','Velum kan aanwezig of afwezig zijn','Saprotroof'],taxa:['Harig kaalkopje','Slijmrandkaalkopje','Oranjerode stropharia','Zandkaalkopje','Echte kopergroenzwam','Kleefsteelstropharia','Halmkaalkopje','Meststropharia','Blauwplaatstropharia'],note:'De bron noemt deze voorbeelden, maar de getoonde groepsdia levert geen volledige soortensleutel.'),
  'paxillus':SourceTaxonCatalog(group:'Krulzomen (Paxillus/Tapinella)',profile:['(Middel)grote soorten met centrale of excentrische steel','Hoed en steel bruin','Vlees verkleurt donkerbruin bij kwetsen','Plaatjes sterk aflopend, vaak aderig vertakt','Sporee bruin','Saprofyten en mycorrhizazwammen'],taxa:[],note:'De bron noemt Paxillus en Tapinella en vier soorten in Vlaanderen, maar deze passage levert geen volledige soortensleutel.'),
  'cantharellus':SourceTaxonCatalog(group:'Cantharellen (Cantharellus)',profile:['Hoed met centrale steel, vaak dunvlezig','Lamelachtige of aderachtige lijsten','Sporee crème-geelachtig','Mycorrhizazwammen'],taxa:[],note:'De bron ondersteunt het geslachtsprofiel; voor een soortnaam zijn aanvullende onderscheidende criteria nodig.'),
};
