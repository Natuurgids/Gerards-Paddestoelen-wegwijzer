import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'determination_engine.dart';
import 'detail_keys.dart';
import 'diagnostic_illustrations.dart';
import 'source_catalog.dart';
import 'wheel_steps.dart';
const determinationSafetyWarning='Niet gebruiken als bewijs van eetbaarheid. Bevestig een determinatie onafhankelijk.';
void main()=>runApp(const App());
class App extends StatelessWidget{const App({super.key,this.skipSplash=false});final bool skipSplash;@override Widget build(BuildContext context)=>MaterialApp(debugShowCheckedModeBanner:false,theme:ThemeData(colorScheme:ColorScheme.fromSeed(seedColor:const Color(0xff315d35)),useMaterial3:true),home:skipSplash?const Wheel():const _WheelSplash());}
class _WheelSplash extends StatefulWidget{const _WheelSplash();@override State<_WheelSplash> createState()=>_WheelSplashState();}
class _WheelSplashState extends State<_WheelSplash> {
  String? version;
  bool done = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => version = 'v${info.version}');

    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (mounted) {
      setState(() => done = true);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 300),
    child: done
        ? const Wheel(key: ValueKey('wheel'))
        : Scaffold(
            key: const ValueKey('splash'),
            backgroundColor: const Color(0xff173d2b),
            body: GestureDetector(
              onTap: () => setState(() => done = true),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/splash.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(),
                  ),
                  Align(
                    alignment: const Alignment(0, .88),
                    child: SafeArea(
                      minimum: const EdgeInsets.all(18),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xff173d2b).withValues(alpha: .72),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 10,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Wiel',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (version != null)
                                Text(
                                  version!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
  );
}
class Wheel extends StatefulWidget{const Wheel({super.key});@override State<Wheel> createState()=>_WheelState();}
class _WheelState extends State<Wheel> {
  int step = 1;
  bool ended = false;
  bool showExcluded = false;
  final answers = <int, String>{};
  final route = <String>[];
  final history = <int>[];

  DeterminationResult get result => determine(answers);

  void choose(WheelOption option) => setState(() {
    history.add(step);
    answers[step] = option.label;
    route.add('${wheelSteps[step]!.title}: ${option.label}');
    ended = option.end;
    if (option.next != null) {
      step = option.next!;
    }
  });

  void back() => setState(() {
    if (history.isEmpty) return;
    final previous = history.removeLast();
    answers.remove(previous);
    if (route.isNotEmpty) {
      route.removeLast();
    }
    step = previous;
    ended = false;
    showExcluded = false;
  });

  void reset() => setState(() {
    step = 1;
    ended = false;
    showExcluded = false;
    answers.clear();
    route.clear();
    history.clear();
  });
void _selectObservation(int picked)=>setState((){
  final index=history.indexOf(picked);
  if(index>=0){
    for(final old in history.sublist(index)){answers.remove(old);}
    history.removeRange(index,history.length);
    if(route.length>index)route.removeRange(index,route.length);
  }
  step=picked;ended=false;showExcluded=false;
});
List<int> _reachableIn(List<int> steps){
  final reached=<int>{...history,step};
  return steps.where(reached.contains).toList();
}
bool _groupReachable(int index){
  if(index==4)return true;
  return _reachableIn(_wheelGroups[index].steps).isNotEmpty;
}
void _openGroup(int index){
  if(index==4){_showPossibilities();return;}
  if(!_groupReachable(index))return;
  final group=_wheelGroups[index];
  _openWheelSelector(group.title,group.steps);
}@override Widget build(BuildContext context){final current=wheelSteps[step]!;return Scaffold(backgroundColor:const Color(0xfff6f8f1),appBar:AppBar(backgroundColor:Colors.white,surfaceTintColor:Colors.transparent,titleSpacing:14,title:Row(children:[ClipRRect(borderRadius:BorderRadius.circular(11),child:Image.asset('assets/app_icon.png',width:42,height:42,fit:BoxFit.cover)),const SizedBox(width:12),Text('Wiel',style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.w800,color:const Color(0xff315d35)))]),actions:[IconButton(tooltip:'Vorige observatie',onPressed:history.isEmpty?null:back,icon:const Icon(Icons.undo_rounded)),IconButton(tooltip:'Nieuwe determinatie',onPressed:reset,icon:const Icon(Icons.restart_alt_rounded)),const SizedBox(width:4)]),body:SafeArea(child:LayoutBuilder(builder:(context,b){final mobile=b.maxWidth<850;return Padding(padding:EdgeInsets.fromLTRB(mobile?12:24,12,mobile?12:24,12),child:mobile?_mobilePanel(current):Row(children:[Expanded(flex:4,child:_wheel(current)),const SizedBox(width:24),Expanded(flex:6,child:_panel(current))]));})));}
Widget _mobilePanel(WheelStep current){return Column(children:[_mushroomInstrument(current),const SizedBox(height:6),Expanded(child:_panel(current,compact:true))]);}
Widget _mushroomInstrument(WheelStep current){
  final answered=answers.length,possibilities=result.remaining.length;
  return SizedBox(height:274,child:Stack(alignment:Alignment.topCenter,clipBehavior:Clip.none,children:[
    Positioned.fill(child:ClipRRect(borderRadius:BorderRadius.circular(22),child:IgnorePointer(child:Image.asset('assets/splash.png',fit:BoxFit.cover,alignment:Alignment.center)))),
    Positioned.fill(child:IgnorePointer(child:DecoratedBox(decoration:BoxDecoration(borderRadius:BorderRadius.circular(22),gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[Colors.black.withValues(alpha:.18),Colors.transparent,Colors.black.withValues(alpha:.22)]))))),
    Positioned(top:4,left:2,right:2,height:126,child:IgnorePointer(child:ClipPath(clipper:_MushroomCapClipper(),child:Image.asset('assets/app_icon.png',fit:BoxFit.cover)))),
    Positioned(top:22,left:44,right:44,child:GestureDetector(key:const ValueKey('mushroom-cap'),behavior:HitTestBehavior.translucent,onTap:_showPossibilities,child:Column(children:[
      _capDots(),const SizedBox(height:7),
      Text(ended?'Mogelijkheden':'Observatie ${route.length+1}',style:const TextStyle(color:Color(0xffffe8d6),fontSize:11,fontWeight:FontWeight.w800,letterSpacing:.35)),
      const SizedBox(height:3),
      Text(ended?'$possibilities mogelijkheden':'$possibilities mogelijkheden · ${current.title}',textAlign:TextAlign.center,maxLines:2,overflow:TextOverflow.ellipsis,style:Theme.of(context).textTheme.titleLarge?.copyWith(color:Colors.white,fontWeight:FontWeight.w900,height:1.02)),
    ]))),
    Positioned(top:105,width:156,height:158,child:DecoratedBox(decoration:BoxDecoration(gradient:const LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[Color(0xfffff6df),Color(0xffead3a5)]),borderRadius:const BorderRadius.only(topLeft:Radius.circular(20),topRight:Radius.circular(20),bottomLeft:Radius.circular(48),bottomRight:Radius.circular(48)),border:Border.all(color:const Color(0xffcaa96d),width:1.4),boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:.10),blurRadius:10,offset:const Offset(0,5))]))),
    Positioned(top:108,width:180,height:19,child:DecoratedBox(decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xfffff2d4),Color(0xffd2ad6b),Color(0xfffff2d4)]),borderRadius:BorderRadius.circular(50),border:Border.all(color:const Color(0xffb98f51)),boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:.08),blurRadius:4,offset:const Offset(0,2))]))),
    Positioned(top:118,left:16,right:16,height:136,child:_wheelStack(answered)),
  ]));
}
Widget _capDots(){
  final groups=_wheelGroups;
  return Row(mainAxisSize:MainAxisSize.min,children:List.generate(5,(i){
    final active=i==4?ended:groups[i].steps.contains(step),complete=i==4?ended:groups[i].steps.any(answers.containsKey),reachable=_groupReachable(i);
    final state=active&&complete?'actief en voltooid':active?'actief':complete?'voltooid':reachable?'beschikbaar':'niet bereikbaar';
    return Semantics(key:ValueKey('cap-wheel-semantics-$i'),label:'${groups[i].title} — $state',button:true,enabled:reachable,child:GestureDetector(key:ValueKey('cap-dot-$i'),behavior:HitTestBehavior.opaque,onTap:reachable?()=>_openGroup(i):null,child:AnimatedContainer(duration:const Duration(milliseconds:240),curve:Curves.easeOutBack,margin:const EdgeInsets.symmetric(horizontal:5),width:active?14:10,height:active?14:10,decoration:BoxDecoration(shape:BoxShape.circle,color:Colors.white.withValues(alpha:active ? 1 : (complete ? .88 : (reachable ? .58 : .25))),border:Border.all(color:Colors.white.withValues(alpha:.95),width:1.2),boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:active ? .28 : .16),blurRadius:active?7:4,offset:const Offset(0,2))]))));
  }));
}
Widget _wheelStack(int answered){
  final groups=_wheelGroups;
  final active=groups.indexWhere((g)=>g.steps.contains(step));
  return Column(
    mainAxisAlignment:MainAxisAlignment.center,
    children:[
      for(var i=0;i<groups.length;i++)
        Builder(builder:(context){
          final reachable=_groupReachable(i);
          final complete=i==4?ended:groups[i].steps.any(answers.containsKey);
          final isActive=i==active;
          final state=isActive&&complete
              ?'actief en voltooid'
              :isActive
                  ?'actief'
                  :complete
                      ?'voltooid'
                      :reachable
                          ?'beschikbaar'
                          :'niet bereikbaar';
          final width=isActive?218.0:184.0-i*6;
          return Semantics(
            key:ValueKey('stem-wheel-semantics-$i'),
            label:'${groups[i].title} — $state',
            button:true,
            enabled:reachable,
            child:Transform.translate(
              offset:Offset(0,isActive?-2:0),
              child:GestureDetector(
                key:ValueKey('stem-wheel-$i'),
                behavior:HitTestBehavior.opaque,
                onTap:!reachable?null:()=>_openGroup(i),
                onHorizontalDragEnd:reachable?(details)=>_openGroup(i):null,
                child:AnimatedOpacity(
                  duration:const Duration(milliseconds:220),
                  opacity:reachable?1:.38,
                  child:AnimatedContainer(
                    duration:const Duration(milliseconds:220),
                    curve:Curves.easeOutCubic,
                    margin:const EdgeInsets.symmetric(vertical:1.5),
                    height:isActive?27:20,
                    width:width,
                    decoration:BoxDecoration(
                      gradient:LinearGradient(
                        begin:Alignment.topCenter,
                        end:Alignment.bottomCenter,
                        colors:isActive
                            ?[const Color(0xff477748),const Color(0xff274f31)]
                            :complete
                                ?[const Color(0xffe4c98d),const Color(0xffb78e4e)]
                                :[const Color(0xffffedc8),const Color(0xffcfad70)],
                      ),
                      borderRadius:BorderRadius.circular(50),
                      border:Border.all(
                        color:isActive?const Color(0xff204126):const Color(0xffb89255),
                        width:isActive?1.4:1,
                      ),
                      boxShadow:[
                        BoxShadow(
                          color:Colors.black.withValues(alpha:isActive ? .22 : .10),
                          blurRadius:isActive?7:3,
                          offset:Offset(0,isActive?3:1),
                        ),
                        BoxShadow(
                          color:Colors.white.withValues(alpha:.45),
                          blurRadius:1,
                          offset:const Offset(0,-1),
                        ),
                      ],
                    ),
                    child:Center(
                      child:Row(
                        mainAxisSize:MainAxisSize.min,
                        children:[
                          if(isActive)const Icon(Icons.chevron_left_rounded,size:16,color:Colors.white),
                          Text(
                            groups[i].title,
                            style:TextStyle(
                              color:isActive?Colors.white:const Color(0xff4b3820),
                              fontSize:isActive?12.5:11.5,
                              fontWeight:FontWeight.w800,
                              letterSpacing:.15,
                            ),
                          ),
                          if(isActive)const Icon(Icons.chevron_right_rounded,size:16,color:Colors.white),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
    ],
  );
}
Future<void> _showPossibilities() async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height*.72),
      padding: const EdgeInsets.fromLTRB(16,12,16,20),
      decoration: const BoxDecoration(color: Color(0xfff6f8f1),borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      child: Column(mainAxisSize: MainAxisSize.min,children:[
        Container(width:42,height:4,decoration:BoxDecoration(color:Colors.black26,borderRadius:BorderRadius.circular(2))),
        const SizedBox(height:12),
        Text('${result.remaining.length} mogelijkheden',style:Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w900)),
        const SizedBox(height:4),
        const Text('Op basis van de observaties tot nu toe. Geen waarschijnlijkheden.',textAlign:TextAlign.center),
        const SizedBox(height:10),
        Flexible(child:ListView(shrinkWrap:true,children:result.remaining.map((x)=>ListTile(dense:true,leading:const Icon(Icons.eco_outlined),title:Text(x.name),subtitle:Text(x.score(answers).label))).toList())),
      ]),
    ),
  );
}
Future<void> _openWheelSelector(String title, List<int> steps) async {
  final available = _reachableIn(steps).where(wheelSteps.containsKey).toList();
  if (available.isEmpty) return;
  var initial = available.indexOf(step);
  if (initial < 0) initial = 0;
  final controller = PageController(viewportFraction: .72, initialPage: initial);
  final picked = await showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _WheelSelectorSheet(
      title: title,
      available: available,
      answers: answers,
      controller: controller,
    ),
  );
  controller.dispose();
  if (picked != null && mounted) _selectObservation(picked);
}
Widget _wheel(WheelStep current){
  return Center(
    child:AspectRatio(
      aspectRatio:1,
      child:Stack(
        alignment:Alignment.center,
        children:[
          CustomPaint(size:Size.infinite,painter:_WheelPainter(route.length,ended)),
          FractionallySizedBox(
            widthFactor:.52,
            heightFactor:.52,
            child:Card(
              elevation:8,
              shape:const CircleBorder(),
              child:Padding(
                padding:const EdgeInsets.all(12),
                child:FittedBox(
                  fit:BoxFit.scaleDown,
                  child:SizedBox(
                    width:260,
                    child:Column(
                      mainAxisSize:MainAxisSize.min,
                      mainAxisAlignment:MainAxisAlignment.center,
                      children:[
                        Text(ended?'Controle':'Observatie ${route.length+1}',textAlign:TextAlign.center,style:Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight:FontWeight.bold)),
                        Text(current.title,textAlign:TextAlign.center,style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.bold)),
                        const SizedBox(height:8),
                        Text(current.help,textAlign:TextAlign.center),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
Widget _panel(WheelStep current,{bool compact=false}){
  final r=result;
  return Card(
    elevation:compact?0:1,
    margin:EdgeInsets.zero,
    color:compact?const Color(0xfffffcf5):null,
    shape:RoundedRectangleBorder(
      borderRadius:BorderRadius.circular(compact?26:22),
      side:BorderSide(color:compact?const Color(0xffd7bd89):Theme.of(context).colorScheme.outlineVariant.withValues(alpha:.45)),
    ),
    child:Padding(
      padding:EdgeInsets.fromLTRB(compact?12:18,compact?10:18,compact?12:18,compact?12:18),
      child:ListView(children:[
        if(compact&&!ended)...[
          Center(child:Container(width:44,height:4,decoration:BoxDecoration(color:const Color(0xffc8ae7c),borderRadius:BorderRadius.circular(2)))),
          const SizedBox(height:8),
          Text('KIES WAT JE ZIET',textAlign:TextAlign.center,style:Theme.of(context).textTheme.labelSmall?.copyWith(color:const Color(0xff315d35),fontWeight:FontWeight.w900,letterSpacing:1.05)),
          const SizedBox(height:8),
        ],
        if(!compact)...[
          Text(ended?'Determinatie-overzicht':'Observatie ${route.length+1} — ${current.title}',style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.bold)),
          const SizedBox(height:10),
        ],
        if(answers.containsKey(4))...[_candidatePanel(r),const Divider(height:20)],
        if(ended)_resultPanel(r)else if(compact&&MediaQuery.sizeOf(context).height>=700) LayoutBuilder(builder:(context,limits)=>GridView.builder(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),gridDelegate:SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:2,crossAxisSpacing:9,mainAxisSpacing:9,childAspectRatio:limits.maxWidth<350?1.05:1.18),itemCount:current.options.length,itemBuilder:(context,i)=>_compactOptionCard(current.options[i]))) else...current.options.map(_optionCard),
        if(route.isNotEmpty)...[
          const Divider(height:28),
          Row(children:[const Expanded(child:Text('Gevolgde route',style:TextStyle(fontWeight:FontWeight.bold))),if(history.isNotEmpty)TextButton.icon(onPressed:back,icon:const Icon(Icons.undo),label:const Text('Vorige'))]),
          Text(route.join('  →  ')),
        ],
      ]),
    ),
  );
}
Widget _candidatePanel(DeterminationResult r)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Expanded(child:Text('Mogelijke groepen: ${r.remaining.length} · beste overeenkomst eerst',style:const TextStyle(fontWeight:FontWeight.bold))),TextButton.icon(onPressed:()=>setState(()=>showExcluded=!showExcluded),icon:Icon(showExcluded?Icons.expand_less:Icons.expand_more),label:Text('${r.excluded.length} uitgesloten'))]),Wrap(spacing:6,runSpacing:4,children:r.remaining.map((x){final score=x.score(answers),hard=x.supporting(answers),soft=x.typicalSupporting(answers);final evidence=<String>[if(hard.isNotEmpty)'Hard: ${hard.join(' • ')}',if(soft.isNotEmpty)'Aanvullend, niet uitsluitend: ${soft.join(' • ')}'];return Tooltip(message:evidence.isEmpty?'Nog geen specifiek bevestigend bronkenmerk vastgelegd':evidence.join('\n'),child:Chip(avatar:Icon(score.complete?Icons.task_alt:Icons.pending_outlined,size:16),label:Text('${x.name} · ${score.percent==null?'—':'${score.percent}%'} · ${(score.coverage*100).round()}% dekking')));}).toList()),if(showExcluded)...r.excluded.entries.map((e)=>ListTile(dense:true,leading:const Icon(Icons.block,size:18),title:Text(e.key.name),subtitle:Text(e.value)))]);
Widget _resultPanel(DeterminationResult r){final key=detailKeyFor(genusHint:r.genusHint,candidateNames:r.remaining.map((x)=>x.name));return Column(children:[const Icon(Icons.fact_check_outlined,size:48),if(r.remaining.length>1)const Padding(padding:EdgeInsets.only(bottom:8),child:Text('Gerangschikt op overeenkomst met harde bronkenmerken; aanvullende bronkenmerken breken alleen gelijke scores en sluiten nooit uit. Dit is geen waarschijnlijkheidsrangschikking.',textAlign:TextAlign.center)),if(r.genusHint!=null)ListTile(leading:const Icon(Icons.call_split),title:Text('Bronondersteunde geslachtssplitsing: ${r.genusHint}')),...r.remaining.map((x)=>ListTile(leading:const Icon(Icons.eco_outlined),title:Text(x.name),subtitle:Text('${x.score(answers).label}\n${x.supporting(answers).isEmpty?'Niet uitgesloten door de ingevoerde harde kenmerken':'Ondersteund door: ${x.supporting(answers).join(' • ')}'}${x.typicalSupporting(answers).isEmpty?'':'\nAanvullend bronkenmerk (niet uitsluitend): ${x.typicalSupporting(answers).join(' • ')}'}'))),if(key!=null)Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(children:[Text(key.title,style:Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.bold)),const SizedBox(height:6),Text(key.sourceNote,textAlign:TextAlign.center),const SizedBox(height:10),FilledButton.icon(onPressed:()=>_openDetailKey(key),icon:const Icon(Icons.account_tree_outlined),label:const Text('Open detailsleutel'))])))else const Text('Voor deze kandidaat bevat de huidige bronset nog geen eenduidige gecodeerde detailsleutel. Vul geen soortnaam in op basis van aannames.',textAlign:TextAlign.center),const SizedBox(height:12),const Text('De matchscore is géén kans dat de determinatie juist is: hij geeft alleen aan welk deel van de voor die kandidaat gecodeerde, beoordeelde kenmerken overeenkomt. Onbekende kenmerken tellen niet als fout. Sommige taxa vragen microscopie, chemische kenmerken of DNA voor verdere bevestiging.',textAlign:TextAlign.center),const SizedBox(height:12),Card(color:Theme.of(context).colorScheme.errorContainer,child:const Padding(padding:EdgeInsets.all(12),child:Text(determinationSafetyWarning))),FilledButton.icon(onPressed:reset,icon:const Icon(Icons.restart_alt),label:const Text('Nieuwe determinatie'))]);}
void _openDetailKey(DetailKey key){String? initial;if(key.id=='russulaceae')initial=answers[22];if(key.id=='galerina')initial=answers[17];Navigator.of(context).push(MaterialPageRoute(builder:(_)=>DetailKeyPage(keyData:key,initialAnswer:initial)));}
String? _photographFor(String label){
  const photos=<String,String>{
    'Hoed + steel':'fruitbody_form_cap_stem',
    'Bol-/buikvormig':'fruitbody_form_puffball',
    'Hout-/korstvormig':'fruitbody_form_bracket',
    'Andere vorm':'fruitbody_form_coral',
    'Glad':'cap_surface_smooth',
    'Vezelig':'cap_surface_fibrous',
    'Schubbig / wrattig':'cap_surface_scaly',
    'Kleverig / slijmerig':'cap_surface_viscid',
    'Vrij':'gill_attachment_free',
    'Aangehecht':'gill_attachment_adnate',
    'Aflopend':'gill_attachment_decurrent',
    'Blauw verkleurend':'bruising_blueing',
    'Geen verkleuring':'bruising_none',
    'Rood / oranje':'cap_color_red',
    'Bruin':'cap_color_brown',
    'Geel / oker':'cap_color_yellow',
    'Dood hout':'growth_position_on_wood',
    'Bodem / strooisel':'growth_position_terrestrial',
    'Naaldboom':'habitat_tree_group_conifers',
    'Plaatjes':'gill_spacing_crowded',
  };
  final name=photos[label];
  return name==null?null:'assets/photographs/$name.png';
}
Widget _optionPhotograph(WheelOption o,{double size=82}){
  final path=_photographFor(o.label);
  if(path==null)return DiagnosticIllustration(art:artFor(o.label),size:size);
  return ClipRRect(borderRadius:BorderRadius.circular(12),child:Image.asset(path,fit:BoxFit.cover,width:double.infinity,height:double.infinity,semanticLabel:'Fotografische illustratie van ${o.label}'));
}
Widget _compactOptionCard(WheelOption o)=>Semantics(button:true,label:'Kies ${o.label}',child:Material(color:Colors.transparent,child:InkWell(onTap:()=>choose(o),borderRadius:BorderRadius.circular(18),child:Ink(decoration:BoxDecoration(gradient:const LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[Colors.white,Color(0xfffff5df)]),borderRadius:BorderRadius.circular(18),border:Border.all(color:const Color(0xffd9bd82)),boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:.07),blurRadius:8,offset:const Offset(0,3))]),child:Padding(padding:const EdgeInsets.all(8),child:Column(children:[Expanded(child:_optionPhotograph(o)),Text(o.label,textAlign:TextAlign.center,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w800,color:Color(0xff372e20))),const Icon(Icons.chevron_right_rounded,size:18,color:Color(0xff315d35))]))))));
Widget _optionCard(WheelOption o)=>Padding(
  padding:const EdgeInsets.only(bottom:10),
  child:Semantics(
    button:true,
    label:'Kies ${o.label}',
    child:InkWell(
      borderRadius:BorderRadius.circular(18),
      onTap:()=>choose(o),
      child:Container(
        padding:const EdgeInsets.symmetric(horizontal:12,vertical:9),
        decoration:BoxDecoration(
          gradient:const LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[Color(0xffffffff),Color(0xfffff8ea)]),
          border:Border.all(color:const Color(0xffddc99f)),
          borderRadius:BorderRadius.circular(18),
          boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:.045),blurRadius:9,offset:const Offset(0,3))],
        ),
        child:Row(children:[
          Container(
            width:62,height:62,
            decoration:BoxDecoration(color:const Color(0xffedf3e7),borderRadius:BorderRadius.circular(16),border:Border.all(color:const Color(0xffd5e0cf))),
            child:Center(child:_optionPhotograph(o,size:52)),
          ),
          const SizedBox(width:13),
          Expanded(child:Text(o.label,style:Theme.of(context).textTheme.titleMedium?.copyWith(color:const Color(0xff332c21),fontWeight:FontWeight.w800))),
          Container(width:30,height:30,decoration:const BoxDecoration(color:Color(0xffe4eddf),shape:BoxShape.circle),child:const Icon(Icons.chevron_right_rounded,color:Color(0xff315d35),size:21)),
        ]),
      ),
    ),
  ),
);
}
class DetailKeyPage extends StatefulWidget {
  const DetailKeyPage({
    super.key,
    required this.keyData,
    this.initialAnswer,
  });

  final DetailKey keyData;
  final String? initialAnswer;

  @override
  State<DetailKeyPage> createState() => _DetailKeyPageState();
}

class _DetailKeyPageState extends State<DetailKeyPage> {
  late String stepId;
  String? result;

  SourceTaxonCatalog? get catalog => sourceCatalogs[widget.keyData.id];

  @override
  void initState() {
    super.initState();
    stepId = widget.keyData.start;
    if (widget.initialAnswer == null) return;

    final step = widget.keyData.steps[stepId]!;
    for (final option in step.options) {
      if (option.label == widget.initialAnswer && option.result != null) {
        result = option.result;
      }
    }
  }

  void pick(DetailOption option) => setState(() {
    if (option.result != null) {
      result = option.result;
    }
    if (option.next != null) {
      stepId = option.next!;
    }
  });

  @override
  Widget build(BuildContext context) {
    final step = widget.keyData.steps[stepId]!;
    final cat = catalog;
    return Scaffold(appBar:AppBar(title:Text(widget.keyData.title)),body:ListView(padding:const EdgeInsets.all(20),children:[Text(widget.keyData.sourceNote,style:Theme.of(context).textTheme.bodySmall),if(cat!=null)...[const SizedBox(height:12),Card(child:ExpansionTile(initiallyExpanded:true,title:Text('Bronprofiel — ${cat.group}'),children:[for(final p in cat.profile)ListTile(dense:true,leading:const Icon(Icons.check_circle_outline,size:18),title:Text(p)),if(cat.taxa.isNotEmpty)...[const Divider(),ListTile(leading:const Icon(Icons.filter_alt_outlined),title:Text('${cat.taxa.length} nog mogelijke soort${cat.taxa.length==1?'':'en'} uit de aangeleverde bron',style:const TextStyle(fontWeight:FontWeight.bold)),subtitle:const Text('Deze namen blijven mogelijk binnen de overgebleven groep; ze zijn niet bevestigd.')),Padding(padding:const EdgeInsets.fromLTRB(16,0,16,12),child:Wrap(spacing:6,runSpacing:6,children:[for(final taxon in cat.taxa)Chip(avatar:const Icon(Icons.help_outline,size:16),label:Text(taxon))]))],if(cat.possibilityCaveat!=null)Padding(padding:const EdgeInsets.fromLTRB(16,0,16,12),child:Text(cat.possibilityCaveat!,style:Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle:FontStyle.italic))),if(cat.nextEvidence.isNotEmpty)...[const Divider(),const ListTile(title:Text('Wat kan verder onderscheid geven?',style:TextStyle(fontWeight:FontWeight.bold))),for(final evidence in cat.nextEvidence)ListTile(dense:true,leading:const Icon(Icons.biotech_outlined,size:18),title:Text(evidence))],Padding(padding:const EdgeInsets.all(12),child:Text(cat.note,style:Theme.of(context).textTheme.bodySmall))]))],const SizedBox(height:20),if(result==null)...[Text(step.title,style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.bold)),const SizedBox(height:8),Text(step.help),const SizedBox(height:16),...step.options.map((o)=>Card(child:ListTile(leading:DiagnosticIllustration(art:artFor(o.label),size:58),title:Text(o.label),trailing:const Icon(Icons.chevron_right),onTap:()=>pick(o)))),],if(result!=null)...[const Icon(Icons.account_tree_outlined,size:64),const SizedBox(height:12),Text(result!,textAlign:TextAlign.center,style:Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight:FontWeight.bold)),const SizedBox(height:12),const Text('Dit is het diepste niveau dat de momenteel gecodeerde broncriteria ondersteunen. Genoemde soorten blijven mogelijke referenties; een macroscopische sleutel kan niet altijd verder scheiden. Waar nodig moet verdere bevestiging met microscopie, chemische kenmerken of DNA gebeuren.',textAlign:TextAlign.center),const SizedBox(height:12),Card(color:Theme.of(context).colorScheme.errorContainer,child:const Padding(padding:EdgeInsets.all(12),child:Text(determinationSafetyWarning,textAlign:TextAlign.center))),const SizedBox(height:20),OutlinedButton(onPressed:()=>setState(()=>result=null),child:const Text('Waarneming opnieuw beoordelen'))]]));
  }
}
class _WheelPainter extends CustomPainter{
  _WheelPainter(this.completed,this.ended);
  final int completed;
  final bool ended;
  @override void paint(Canvas c,Size z){
    final center=Offset(z.width/2,z.height/2),radius=z.shortestSide*.48;
    final base=Paint()..style=PaintingStyle.stroke..strokeWidth=z.shortestSide*.11..strokeCap=StrokeCap.round..color=const Color(0xffdde8d7);
    c.drawCircle(center,radius*.86,base);
    // The source sections are not a fixed sequential determination scale.
    // Only show a completed ring when the observation route has ended.
    if(ended){
        final progress=Paint()..style=PaintingStyle.stroke..strokeWidth=z.shortestSide*.11..strokeCap=StrokeCap.round..color=const Color(0xff315d35);
        c.drawCircle(center,radius*.86,progress);
    }
    final tp=TextPainter(textDirection:TextDirection.ltr,textAlign:TextAlign.center);
    tp.text=TextSpan(text:ended?'controle':completed==0?'start':'$completed\nwaarnemingen',style:TextStyle(fontSize:z.shortestSide*.035,fontWeight:FontWeight.w700,color:const Color(0xff315d35)));
    tp.layout();
    tp.paint(c,center-Offset(tp.width/2,tp.height/2));
  }
  @override bool shouldRepaint(covariant _WheelPainter old)=>old.completed!=completed||old.ended!=ended;
}


class _WheelGroup {
  const _WheelGroup(this.title,this.steps);
  final String title;
  final List<int> steps;
}
const _wheelGroups=< _WheelGroup>[
  _WheelGroup('Bouw',[1,4]),
  _WheelGroup('Kenmerken',[5,6,7,8,9,10,11,12,13,14]),
  _WheelGroup('Ecologie',[15,16,17,18]),
  _WheelGroup('Aanvullend',[19,20,21,22,23,24]),
  _WheelGroup('Mogelijkheden',[]),
];
class _WheelSelectorSheet extends StatefulWidget {
  const _WheelSelectorSheet({required this.title,required this.available,required this.answers,required this.controller});
  final String title; final List<int> available; final Map<int,String> answers; final PageController controller;
  @override State<_WheelSelectorSheet> createState()=>_WheelSelectorSheetState();
}
class _WheelSelectorSheetState extends State<_WheelSelectorSheet>{
  late int centered;
  @override void initState(){super.initState();centered=widget.controller.initialPage.clamp(0,widget.available.length-1);}
  @override Widget build(BuildContext context)=>Container(
    height:424,
    padding:const EdgeInsets.only(top:10,bottom:16),
    decoration:BoxDecoration(
      gradient:const LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[Color(0xfffff7e7),Color(0xfff3ead6)]),
      borderRadius:const BorderRadius.vertical(top:Radius.circular(32)),
      border:const Border(top:BorderSide(color:Color(0xffd7bd89),width:1.2)),
      boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:.18),blurRadius:22,offset:const Offset(0,-6))],
    ),
    child:Column(children:[
      Container(width:44,height:4,decoration:BoxDecoration(color:const Color(0xff8d744d).withValues(alpha:.38),borderRadius:BorderRadius.circular(2))),
      const SizedBox(height:11),
      Text(widget.title.toUpperCase(),style:Theme.of(context).textTheme.labelLarge?.copyWith(color:const Color(0xff315d35),fontWeight:FontWeight.w900,letterSpacing:1.1)),
      const SizedBox(height:3),
      Text(widget.available.length==1?'Eén bereikte observatie · tik op bevestigen':'Veeg links/rechts · centreer de observatie',style:Theme.of(context).textTheme.bodySmall?.copyWith(color:const Color(0xff6c604c),fontWeight:FontWeight.w600)),
      const SizedBox(height:7),
      Expanded(child:PageView.builder(
        key:const ValueKey('observation-wheel'),
        controller:widget.controller,itemCount:widget.available.length,
        onPageChanged:(i)=>setState(()=>centered=i),
        itemBuilder:(context,i){
          final s=widget.available[i],ws=wheelSteps[s]!,selected=widget.answers[s],isCentered=i==centered;
          return AnimatedScale(
            duration:const Duration(milliseconds:180),scale:isCentered?1:.91,
            child:Padding(
              padding:const EdgeInsets.symmetric(horizontal:7,vertical:10),
              child:AnimatedContainer(
                duration:const Duration(milliseconds:180),
                decoration:BoxDecoration(
                  color:isCentered?const Color(0xfffffcf4):const Color(0xffeee2c9),
                  borderRadius:BorderRadius.circular(28),
                  border:Border.all(color:isCentered?const Color(0xff527653):const Color(0xffd0b98a),width:isCentered?2:1),
                  boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:isCentered ? .13 : .06),blurRadius:isCentered?12:5,offset:Offset(0,isCentered?5:2))],
                ),
                child:Padding(
                  padding:const EdgeInsets.all(18),
                  child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
                    Container(
                      width:48,height:48,
                      decoration:BoxDecoration(
                        shape:BoxShape.circle,
                        gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:isCentered?[const Color(0xff4c7a4e),const Color(0xff294e31)]:[const Color(0xffbca475),const Color(0xff90764d)]),
                        boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:.12),blurRadius:5,offset:const Offset(0,2))],
                      ),
                      alignment:Alignment.center,
                      child:Text('$s',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w900,fontSize:16)),
                    ),
                    const SizedBox(height:10),
                    Text(ws.title,textAlign:TextAlign.center,style:Theme.of(context).textTheme.titleMedium?.copyWith(color:const Color(0xff30291f),fontWeight:FontWeight.w900,height:1.15)),
                    const SizedBox(height:8),
                    DecoratedBox(
                      decoration:BoxDecoration(color:selected==null?const Color(0xffeee7d8):const Color(0xffe1eddd),borderRadius:BorderRadius.circular(30)),
                      child:Padding(
                        padding:const EdgeInsets.symmetric(horizontal:12,vertical:6),
                        child:Text(selected??'Nog niet ingevuld',textAlign:TextAlign.center,maxLines:2,overflow:TextOverflow.ellipsis,style:TextStyle(color:selected==null?const Color(0xff756b59):const Color(0xff315d35),fontSize:12,fontWeight:FontWeight.w700)),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          );
        },
      )),
      Padding(
        padding:const EdgeInsets.fromLTRB(24,2,24,0),
        child:SizedBox(width:double.infinity,child:FilledButton.icon(
          key:const ValueKey('select-centered-observation'),
          style:FilledButton.styleFrom(backgroundColor:const Color(0xff315d35),foregroundColor:Colors.white,padding:const EdgeInsets.symmetric(vertical:14),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18))),
          onPressed:()=>Navigator.pop(context,widget.available[centered]),
          icon:const Icon(Icons.check_circle_outline),
          label:const Text('Selecteer deze observatie',style:TextStyle(fontWeight:FontWeight.w800)),
        )),
      ),
    ]),
  );
}
class _MushroomCapPainter extends CustomPainter{
  @override void paint(Canvas c,Size z){
    final shadow=Paint()..color=Colors.black.withValues(alpha:.16)..maskFilter=const MaskFilter.blur(BlurStyle.normal,8);
    final path=Path()..moveTo(z.width*.025,z.height*.88)..cubicTo(z.width*.08,z.height*.29,z.width*.27,z.height*.045,z.width*.50,z.height*.035)..cubicTo(z.width*.74,z.height*.04,z.width*.92,z.height*.30,z.width*.975,z.height*.88)..cubicTo(z.width*.82,z.height*.77,z.width*.67,z.height*.75,z.width*.50,z.height*.81)..cubicTo(z.width*.33,z.height*.75,z.width*.18,z.height*.77,z.width*.025,z.height*.88);
    c.save();c.translate(0,4);c.drawPath(path,shadow);c.restore();
    final fill=Paint()..shader=const LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[Color(0xffd95243),Color(0xffa82d28)]).createShader(Offset.zero&z);c.drawPath(path,fill);
    final highlight=Paint()..color=Colors.white.withValues(alpha:.09);c.drawOval(Rect.fromCenter(center:Offset(z.width*.38,z.height*.31),width:z.width*.28,height:z.height*.18),highlight);
    final spots=Paint()..color=const Color(0xfffff3d8);
    for(final spot in const <(double,double,double)>[(.19,.66,.025),(.28,.38,.018),(.40,.22,.022),(.61,.18,.015),(.72,.36,.024),(.84,.63,.018),(.51,.47,.016),(.34,.64,.013),(.65,.62,.014)]){c.drawOval(Rect.fromCenter(center:Offset(z.width*spot.$1,z.height*spot.$2),width:z.width*spot.$3*2,height:z.width*spot.$3),spots);}
    final rim=Paint()..color=const Color(0xff7f211f).withValues(alpha:.42)..style=PaintingStyle.stroke..strokeWidth=1.4;c.drawPath(path,rim);
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate)=>false;
}

class _MushroomCapClipper extends CustomClipper<Path>{
  @override Path getClip(Size z)=>Path()..moveTo(z.width*.025,z.height*.88)..cubicTo(z.width*.08,z.height*.29,z.width*.27,z.height*.045,z.width*.50,z.height*.035)..cubicTo(z.width*.74,z.height*.04,z.width*.92,z.height*.30,z.width*.975,z.height*.88)..cubicTo(z.width*.82,z.height*.77,z.width*.67,z.height*.75,z.width*.50,z.height*.81)..cubicTo(z.width*.33,z.height*.75,z.width*.18,z.height*.77,z.width*.025,z.height*.88);
  @override bool shouldReclip(covariant CustomClipper<Path> oldClipper)=>false;
}
