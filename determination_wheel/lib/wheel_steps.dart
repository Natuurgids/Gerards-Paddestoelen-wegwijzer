class WheelOption{const WheelOption(this.label,{this.next,this.end=false});final String label;final int? next;final bool end;}
class WheelStep{const WheelStep(this.title,this.help,this.options);final String title,help;final List<WheelOption> options;}
WheelStep q(String title,String help,List<String> values,int next)=>WheelStep(title,help,[for(final v in values)WheelOption(v,next:next)]);
final wheelSteps=<int,WheelStep>{
1:const WheelStep('Vorm vruchtlichaam','Kies de algemene bouw die je werkelijk ziet.',[WheelOption('Hoed + steel',next:4),WheelOption('Bol-/buikvormig',next:15),WheelOption('Hout-/korstvormig',next:15),WheelOption('Andere vorm',next:15)]),
4:const WheelStep('Sporenvormende onderzijde','Bekijk de onderkant van de hoed.',[WheelOption('Plaatjes',next:5),WheelOption('Buisjes / poriën',next:11),WheelOption('Tanden / stekels',next:15),WheelOption('Plooien / ribben',next:15)]),
5:q('Hoedoppervlak','Vergelijk vooral de oppervlaktestructuur.',['Glad','Vezelig','Schubbig / wrattig','Kleverig / slijmerig'],6),
6:q('Lamelaanhechting','Bekijk hoe de plaatjes de steel bereiken.',['Vrij','Aangehecht','Aflopend','Onzeker'],7),
7:q('Velum','Let op ring, beurs/volva en velumresten.',['Ring','Beurs / volva','Beide','Geen zichtbaar','Onzeker'],8),
8:q('Hygrofaan?','Verandert de hoed duidelijk van kleur bij uitdrogen?',['Ja','Nee','Onzeker'],9),
9:q('Sporenkleur','Gebruik bij voorkeur een sporenfiguur/sporee.',['Wit / crème','Roze','Bruin / roest','Purperbruin / donker','Onzeker'],10),
10:const WheelStep('Kandidaatgroep','Bekijk welke bronondersteunde groepen overblijven.',[WheelOption('Ga verder met veldkenmerken',next:15)]),
11:q('Buisjes / poriën','Scheid boleetachtige van andere poriëndragende vormen.',['Centraal gesteeld / boleetachtig','Zijdelings / houtbewonend','Onzeker'],12),
12:q('Verkleuring bij druk/snede','Noteer kleurverandering van vlees of poriën.',['Blauw verkleurend','Andere verkleuring','Geen verkleuring','Onzeker'],13),
13:q('Steeloppervlak','Vergelijk netwerk, schubjes/stippen en glad oppervlak.',['Netvormig','Schubbig / gestippeld','Glad / anders','Onzeker'],14),
14:const WheelStep('Boleet-route vastleggen','De buisjes-, verkleurings- en steelkenmerken zijn vastgelegd.',[WheelOption('Ga verder met veldkenmerken',next:15)]),
15:q('Vindplaats / vegetatietype','Leg het milieu vast.',['Bos','Grasland / open terrein','Tuin / park','Anders / onzeker'],16),
16:q('Waardplant / boomassociatie','Noteer een mogelijke waardplant of boom.',['Loofboom','Naaldboom','Geen duidelijke waardplant','Onzeker'],17),
17:q('Substraat','Waar komt het vruchtlichaam daadwerkelijk uit?',['Bodem / strooisel','Dood hout','Levend hout','Gras / mos','Mest / rijk organisch materiaal','Onzeker'],18),
18:q('Groeigedrag','Noteer afzonderlijk, groepen, bundels of rijen.',['Afzonderlijk','Groepjes','Bundels / vergroeid','Heksenkring / rij','Onzeker'],19),
19:q('Afmetingen','Noteer de grootte van hoed/vruchtlichaam en steel.',['Klein','Middelgroot','Groot','Niet gemeten / onzeker'],20),
20:q('Kleur','Leg kleuren van hoed, lamellen/poriën en steel vast.',['Licht / witachtig','Geel / oker','Bruin','Rood / oranje','Grijs / zwartachtig','Anders / meerkleurig'],21),
21:q('Geur','Geur kan een relevant macroscopisch kenmerk zijn.',['Opvallende geur','Geen opvallende geur','Niet beoordeeld'],22),
22:q('Melk / sap bij beschadiging','Binnen Russulaceae ondersteunt melk Lactarius en geen melk Russula.',['Melksap aanwezig','Geen melksap','Niet beoordeeld'],23),
23:q('Trama / vlees en reactie','Noteer structuur en kleurreacties.',['Broos / breekt krijtachtig','Vlezig / vezelig','Verkleurt bij druk/wrijven','Geen duidelijke reactie','Onzeker'],24),
24:const WheelStep('Controle & detailsleutel','Controleer gelijkende groepen en of microscopie nodig is.',[WheelOption('Toon eindresultaat',end:true)]),
};
