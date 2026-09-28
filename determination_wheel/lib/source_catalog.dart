class SourceTaxonCatalog {
  const SourceTaxonCatalog({required this.group,required this.profile,required this.taxa,required this.note});
  final String group;
  final List<String> profile;
  final List<String> taxa;
  final String note;
}

// Transcribed only from the supplied Likonadag presentation. These names are
// reference targets, not automatic determinations: the presentation lists them
// but does not provide the complete branch criteria needed to distinguish each.
const sourceCatalogs=<String,SourceTaxonCatalog>{
  'pluteus':SourceTaxonCatalog(
    group:'Hertenzwammen (Pluteus)',
    profile:['Klein tot groot en breekbaar','Zonder velum / zonder beurs','Lamellen buikig en vrij; bij rijpheid rozig','Sporee roze','Saprotroof; vaak op hout'],
    taxa:['Knolvoethertenzwam','Pluishoedhertenzwam','Roetkleurige hertenzwam','Gewone hertenzwam','Bruinsnedehertenzwam','Geaderde hertenzwam','Geelsteelhertenzwam','Grauwgroene hertenzwam'],
    note:'De bron noemt deze hertenzwammen, maar geeft op deze dia’s geen volledige kenmerkenmatrix om ze onderling betrouwbaar uit te sleutelen.',
  ),
  'agrocybe':SourceTaxonCatalog(
    group:'Leemhoeden (Agrocybe)',
    profile:['Klein tot groot en vlezig','Bij de meeste soorten velum','Hoed glad, vaak vettig, zonder radiale structuur','Sporee vaalbruin','Saprotroof; meestal op de bodem'],
    taxa:['Knolletjesleemhoed','Grasleemhoed','Populierleemhoed','Vroege leemhoed','Leverkleurige leemhoed','Fluweelleemhoed','Moerasleemhoed','Gaderde leemhoed (Agrocybe rivulosa)'],
    note:'De bron toont deze soortnamen en noemt Agrocybe rivulosa bij een koffie-met-melk-kleurige sporee, maar levert hier geen volledige soortensleutel.',
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
};
