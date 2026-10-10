import 'package:flutter/material.dart';

const mushroomInstrumentAsset='assets/interface/mushroom-instrument.png';
const woodlandBackgroundAsset='assets/interface/woodland-background.png';
const stemRingTextureAsset='assets/interface/stem-ring-texture.png';
const notebookAsset='assets/interface/field-notebook.png';

// Exhaustive labels from the observation wheel and source-backed detail keys.
// Images illustrate an observation, never provide evidence about a user's find.
const observationPhotographs=<String,String>{
  'Hoed + steel':mushroomInstrumentAsset,
  'Bol-/buikvormig':'assets/interface/form-puffball.png',
  'Hout-/korstvormig':'assets/interface/form-bracket.png',
  'Andere vorm':'assets/photographs/fruitbody_form_coral.png',
  'Plaatjes':'assets/photographs/gill_spacing_crowded.png',
  'Buisjes / poriën':'assets/interface/underside-pores.png',
  'Tanden / stekels':'assets/interface/underside-teeth.png',
  'Plooien / ribben':'assets/interface/underside-folds.png',
  'Glad':'assets/photographs/cap_surface_smooth.png',
  'Vezelig':'assets/photographs/cap_surface_fibrous.png',
  'Schubbig / wrattig':'assets/photographs/cap_surface_warts_or_patches.png',
  'Kleverig / slijmerig':'assets/photographs/cap_surface_viscid.png',
  'Vrij':'assets/photographs/gill_attachment_free.png',
  'Aangehecht':'assets/photographs/gill_attachment_adnate.png',
  'Aflopend':'assets/photographs/gill_attachment_decurrent.png',
  'Onzeker':notebookAsset,
  'Ring':'assets/photographs/ring_form_pendant.png',
  'Beurs / volva':'assets/photographs/volva_form_sack_like.png',
  'Beide':'assets/interface/velum-both.png',
  'Geen zichtbaar':'assets/photographs/ring_absent.png',
  'Ja':'assets/interface/hygrophanous.png',
  'Nee':'assets/interface/stable-cap.png',
  'Wit / crème':'assets/photographs/spore_print_cream.png',
  'Roze':'assets/photographs/spore_print_pink.png',
  'Bruin / roest':'assets/photographs/spore_print_rust_brown.png',
  'Purperbruin / donker':'assets/photographs/spore_print_purple_brown.png',
  'Ga verder met veldkenmerken':notebookAsset,
  'Centraal gesteeld / boleetachtig':'assets/interface/underside-pores.png',
  'Zijdelings / houtbewonend':'assets/interface/form-bracket.png',
  'Blauw verkleurend':'assets/photographs/bruising_blueing.png',
  'Andere verkleuring':'assets/photographs/bruising_browning.png',
  'Geen verkleuring':'assets/photographs/flesh_colour_white.png',
  'Netvormig':'assets/photographs/stem_surface_reticulate.png',
  'Schubbig / gestippeld':'assets/photographs/stem_surface_scaly.png',
  'Glad / anders':'assets/photographs/stem_surface_smooth.png',
  'Bos':'assets/interface/woodland-background.png',
  'Grasland / open terrein':'assets/photographs/habitat_tree_group_no_trees.png',
  'Tuin / park':'assets/photographs/habitat_tree_group_hardwoods.png',
  'Anders / onzeker':notebookAsset,
  'Loofboom':'assets/photographs/habitat_tree_group_hardwoods.png',
  'Naaldboom':'assets/photographs/habitat_tree_group_conifers.png',
  'Geen duidelijke waardplant':'assets/photographs/habitat_tree_group_no_trees.png',
  'Bodem / strooisel':'assets/photographs/substrate_leaf_litter.png',
  'Dood hout':'assets/photographs/substrate_wood.png',
  'Levend hout':'assets/photographs/growth_position_on_wood.png',
  'Gras / mos':'assets/photographs/substrate_moss.png',
  'Mest / rijk organisch materiaal':'assets/photographs/substrate_dung.png',
  'Afzonderlijk':mushroomInstrumentAsset,
  'Groepjes':'assets/interface/growth-group.png',
  'Bundels / vergroeid':'assets/interface/growth-cluster.png',
  'Heksenkring / rij':'assets/interface/growth-ring.png',
  'Klein':'assets/interface/size-observation.png',
  'Middelgroot':'assets/interface/size-observation.png',
  'Groot':'assets/interface/size-observation.png',
  'Niet gemeten / onzeker':notebookAsset,
  'Licht / witachtig':'assets/photographs/cap_color_white.png',
  'Geel / oker':'assets/photographs/cap_color_yellow.png',
  'Bruin':'assets/photographs/cap_color_brown.png',
  'Rood / oranje':'assets/photographs/cap_color_red.png',
  'Grijs / zwartachtig':'assets/photographs/cap_color_grey.png',
  'Anders / meerkleurig':'assets/photographs/cap_surface_warts_or_patches.png',
  'Opvallende geur':'assets/interface/smell-observation.png',
  'Geen opvallende geur':'assets/interface/smell-observation.png',
  'Niet beoordeeld':notebookAsset,
  'Melksap aanwezig':'assets/interface/milk-present.png',
  'Geen melksap':'assets/interface/milk-absent.png',
  'Broos / breekt krijtachtig':'assets/interface/milk-absent.png',
  'Vlezig / vezelig':'assets/photographs/stem_surface_fibrous.png',
  'Taai / leerachtig':'assets/interface/form-bracket.png',
  'Verkleurt bij druk/wrijven':'assets/photographs/bruising_blueing.png',
  'Geen duidelijke reactie':'assets/photographs/flesh_colour_white.png',
  'Toon eindresultaat':notebookAsset,
  'Steel vrijwel afwezig':'assets/interface/form-bracket.png',
  'Steel zijdelings aangehecht':'assets/interface/form-bracket.png',
  'Duidelijke centrale steel':'assets/photographs/fruitbody_form_cap_stem.png',
  'Profiel bevestigd':notebookAsset,
  'Combinatie bevestigd':notebookAsset,
  'Niet zeker':notebookAsset,
  'Andere groeiplaats':'assets/interface/woodland-background.png',
};

const unassessedLabels={'Onzeker','Anders / onzeker','Niet gemeten / onzeker','Niet beoordeeld','Niet zeker'};

class ChoicePhotograph extends StatelessWidget {
  const ChoicePhotograph({super.key,required this.label});
  final String label;
  @override
  Widget build(BuildContext context)=>ClipRRect(
    borderRadius:BorderRadius.circular(12),
    child:Stack(fit:StackFit.expand,children:[
      Image.asset(observationPhotographs[label]??notebookAsset,fit:BoxFit.cover,
        semanticLabel:unassessedLabels.contains(label)?'Veldnotities: kenmerk niet beoordeeld':'Illustratief voorbeeld voor $label'),
      if(unassessedLabels.contains(label)) Center(child:Container(
        width:40,height:40,decoration:const BoxDecoration(color:Color(0xeefaf4e5),shape:BoxShape.circle),
        child:const Icon(Icons.question_mark_rounded,color:Color(0xff4d5d38)),
      )),
    ]),
  );
}

class WoodlandBackground extends StatelessWidget {
  const WoodlandBackground({super.key});
  @override
  Widget build(BuildContext context)=>ExcludeSemantics(child:Stack(fit:StackFit.expand,children:[
    Image.asset(woodlandBackgroundAsset,fit:BoxFit.cover),
    const DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[Color(0x80102415),Color(0x35102415),Color(0x90102415)]))),
  ]));
}
