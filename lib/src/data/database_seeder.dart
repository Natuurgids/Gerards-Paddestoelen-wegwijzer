import 'package:sqflite/sqflite.dart';

class DatabaseSeeder {
  static Future<void> seed(Transaction txn) async {
    await txn.insert('taxon', {'id':1,'rank':'kingdom','scientific_name':'Fungi'});
    await txn.insert('taxon', {'id':10,'parent_id':1,'rank':'genus','scientific_name':'Amanita'});
    await txn.insert('taxon', {'id':11,'parent_id':10,'rank':'species','scientific_name':'Amanita muscaria'});
    await txn.insert('taxon', {'id':12,'parent_id':10,'rank':'species','scientific_name':'Amanita phalloides'});
    await txn.insert('taxon', {'id':20,'parent_id':1,'rank':'genus','scientific_name':'Boletus'});
    await txn.insert('taxon', {'id':21,'parent_id':20,'rank':'species','scientific_name':'Boletus edulis'});
    await txn.insert('species', {'id':1,'taxon_id':11,'edible_status':'not_recommended','toxicity_level':'poisonous'});
    await txn.insert('species', {'id':2,'taxon_id':12,'edible_status':'deadly','toxicity_level':'deadly'});
    await txn.insert('species', {'id':3,'taxon_id':21,'edible_status':'edible_with_expert_confirmation','toxicity_level':'low'});

    const texts = <List<Object>>[
      [1,'nl','Vliegenzwam','Rode hoed met vaak witte wratten.','Bekende amaniet met witte plaatjes, ring en meestal een knolvormige voet met resten van de beurs.','Bossen, vaak bij berk, spar en den.','Kan worden verward met andere Amanita-soorten.'],
      [1,'en','Fly agaric','Red cap, often with white warts.','Distinctive Amanita with white gills, a ring and typically a bulbous base with veil remnants.','Woodland, often associated with birch, spruce and pine.','Can be confused with other Amanita species.'],
      [1,'de','Fliegenpilz','Roter Hut, häufig mit weißen Flocken.','Markanter Wulstling mit weißen Lamellen, Ring und meist knolliger Basis mit Hüllresten.','Wälder, häufig bei Birke, Fichte und Kiefer.','Verwechslungen mit anderen Amanita-Arten sind möglich.'],
      [2,'nl','Groene knolamaniet','Zeer giftige amaniet, vaak groenig met witte plaatjes.','Heeft vrije witte plaatjes, ring en een duidelijke zakvormige beurs rond de steelbasis.','Loofbossen, vaak bij eik en beuk.','Verwarring met eetbare soorten kan dodelijk zijn.'],
      [2,'en','Death cap','Deadly Amanita, often greenish with white gills.','Has free white gills, a ring and a distinct sack-like volva around the stem base.','Deciduous woodland, often with oak and beech.','Confusion with edible mushrooms can be fatal.'],
      [2,'de','Grüner Knollenblätterpilz','Tödlich giftiger Wulstling, oft grünlich mit weißen Lamellen.','Weiße freie Lamellen, Ring und deutliche sackartige Volva an der Stielbasis.','Laubwald, häufig bei Eiche und Buche.','Verwechslungen mit Speisepilzen können tödlich enden.'],
      [3,'nl','Gewoon eekhoorntjesbrood','Bruine boleet met buisjes in plaats van plaatjes.','Stevige steel, bruine hoed en witte tot olijfkleurige poriën naarmate het vruchtlichaam ouder wordt.','Bossen bij onder andere beuk, eik, spar en den.','Diverse boleten lijken erop; controleer alle kenmerken.'],
      [3,'en','Penny bun','Brown bolete with pores rather than gills.','Stout stem, brown cap and pores changing from white toward olive as the fruit body ages.','Woodland with beech, oak, spruce and pine among other trees.','Several boletes look similar; check all characters.'],
      [3,'de','Steinpilz','Brauner Röhrling mit Poren statt Lamellen.','Kräftiger Stiel, brauner Hut und Poren, die von weiß zu oliv wechseln können.','Wälder unter anderem bei Buche, Eiche, Fichte und Kiefer.','Mehrere Röhrlinge sind ähnlich; alle Merkmale prüfen.'],
    ];
    for (final x in texts) {
      await txn.insert('species_text', {'species_id':x[0],'language_code':x[1],'common_name':x[2],'summary':x[3],'description':x[4],'habitat_text':x[5],'lookalikes_text':x[6]});
    }

    const traits = [[1,'cap_color','cap','choice'],[2,'hymenium','underside','choice'],[3,'ring','stem','choice'],[4,'volva','stem_base','choice']];
    for(final t in traits){await txn.insert('trait',{'id':t[0],'code':t[1],'category':t[2],'value_type':t[3]});}
    const options = [[1,1,'red',1],[2,1,'green',2],[3,1,'brown',3],[4,2,'gills',1],[5,2,'pores',2],[6,3,'present',1],[7,3,'absent',2],[8,4,'present',1],[9,4,'absent',2]];
    for(final o in options){await txn.insert('trait_option',{'id':o[0],'trait_id':o[1],'code':o[2],'sort_order':o[3]});}
    const optionTexts = <List<Object>>[
      [1,'nl','Rood'],[1,'en','Red'],[1,'de','Rot'],[2,'nl','Groen'],[2,'en','Green'],[2,'de','Grün'],[3,'nl','Bruin'],[3,'en','Brown'],[3,'de','Braun'],
      [4,'nl','Plaatjes'],[4,'en','Gills'],[4,'de','Lamellen'],[5,'nl','Buisjes/poriën'],[5,'en','Pores'],[5,'de','Röhren/Poren'],
      [6,'nl','Ring aanwezig'],[6,'en','Ring present'],[6,'de','Ring vorhanden'],[7,'nl','Geen ring'],[7,'en','No ring'],[7,'de','Kein Ring'],
      [8,'nl','Beurs/volva aanwezig'],[8,'en','Volva present'],[8,'de','Volva vorhanden'],[9,'nl','Geen beurs/volva'],[9,'en','No volva'],[9,'de','Keine Volva']
    ];
    for(final o in optionTexts){await txn.insert('trait_option_text',{'option_id':o[0],'language_code':o[1],'label':o[2]});}
    const speciesTraits=[[1,1,1,1.3],[1,2,4,1.4],[1,3,6,1.2],[1,4,8,1.5],[2,1,2,1.3],[2,2,4,1.4],[2,3,6,1.2],[2,4,8,1.7],[3,1,3,1.2],[3,2,5,1.8],[3,3,7,1.1],[3,4,9,1.4]];
    for(final x in speciesTraits){await txn.insert('species_trait',{'species_id':x[0],'trait_id':x[1],'option_id':x[2],'weight':x[3]});}

    for(final speciesId in [1,2,3]){
      for(var i=1;i<=5;i++){
        const angles=['top','underside','side','base','habitat'];
        await txn.insert('species_image',{'species_id':speciesId,'asset_path':'assets/images/species/species_$speciesId/$i.jpg','sort_order':i-1,'angle_code':angles[i-1],'is_primary':i==1?1:0});
      }
    }

    await txn.insert('lesson',{'id':1,'slug':'safe-identification-basics','difficulty':1,'sort_order':1});
    const lessons=[
      ['nl','Veilig determineren','Leer systematisch kijken naar hoed, onderzijde, steel en steelbasis. Gebruik een app nooit als bewijs dat een paddenstoel eetbaar is.'],
      ['en','Safe identification basics','Learn to examine cap, underside, stem and stem base systematically. Never use an app as proof that a mushroom is edible.'],
      ['de','Grundlagen der sicheren Bestimmung','Lerne Hut, Unterseite, Stiel und Stielbasis systematisch zu prüfen. Eine App ist niemals ein Beweis für Essbarkeit.']
    ];
    for(final l in lessons){await txn.insert('lesson_text',{'lesson_id':1,'language_code':l[0],'title':l[1],'body':l[2]});}
    await txn.insert('question',{'id':1,'lesson_id':1,'question_type':'single_choice','sort_order':1});
    const qs=[['nl','Wat moet je doen voordat je een wilde paddenstoel eet?','App-identificatie is onvoldoende voor consumptieveiligheid.'],['en','What should you do before eating a wild mushroom?','App identification is insufficient for consumption safety.'],['de','Was solltest du tun, bevor du einen Wildpilz isst?','Eine App-Bestimmung reicht für die Verzehrsicherheit nicht aus.']];
    for(final q in qs){await txn.insert('question_text',{'question_id':1,'language_code':q[0],'prompt':q[1],'explanation':q[2]});}
    await txn.insert('answer_option',{'id':1,'question_id':1,'is_correct':1,'sort_order':1});
    await txn.insert('answer_option',{'id':2,'question_id':1,'is_correct':0,'sort_order':2});
    const ans=[[1,'nl','Laat hem controleren door een gekwalificeerde lokale deskundige'],[1,'en','Have it verified by a qualified local expert'],[1,'de','Von einer qualifizierten örtlichen Fachperson prüfen lassen'],[2,'nl','Vertrouw alleen op de hoogste app-score'],[2,'en','Trust only the highest app score'],[2,'de','Nur dem höchsten App-Ergebnis vertrauen']];
    for(final a in ans){await txn.insert('answer_option_text',{'answer_id':a[0],'language_code':a[1],'label':a[2]});}
  }
}
