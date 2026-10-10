import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'determination_engine.dart';
import 'detail_keys.dart';
import 'photographic_assets.dart';
import 'source_catalog.dart';
import 'wheel_steps.dart';
const determinationSafetyWarning='Niet gebruiken als bewijs van eetbaarheid. Bevestig een determinatie onafhankelijk.';
void main()=>runApp(const App());
class App extends StatelessWidget{const App({super.key,this.skipSplash=false});final bool skipSplash;@override Widget build(BuildContext context)=>MaterialApp(debugShowCheckedModeBanner:false,theme:ThemeData(fontFamily:'FieldSans',colorScheme:ColorScheme.fromSeed(seedColor:const Color(0xff315d35)),scaffoldBackgroundColor:const Color(0xfffaf5e8),cardTheme:const CardThemeData(color:Color(0xfffffbf1),surfaceTintColor:Colors.transparent),useMaterial3:true),home:skipSplash?const Wheel():const _WheelSplash());}
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
}@override
Widget build(BuildContext context) {
  final current=wheelSteps[step]!;
  return Scaffold(
    extendBodyBehindAppBar: true,
    backgroundColor: const Color(0xff173322),
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: const Color(0xfffff5df),
      titleSpacing: 14,
      title: Row(children:[
        ClipRRect(borderRadius:BorderRadius.circular(10),child:Image.asset('assets/app_icon.png',width:38,height:38,fit:BoxFit.cover)),
        const SizedBox(width:10),
        const Expanded(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Wiel',style:TextStyle(fontSize:18,fontWeight:FontWeight.w800)),Text('Gerards Paddestoelen Wegwijzer',maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(fontSize:10))])),
      ]),
      actions:[
        IconButton(tooltip:'Vorige observatie',onPressed:history.isEmpty?null:back,icon:const Icon(Icons.undo_rounded)),
        IconButton(tooltip:'Nieuwe determinatie',onPressed:reset,icon:const Icon(Icons.restart_alt_rounded)),
        IconButton(tooltip:'Hulp bij waarnemen',onPressed:_showObservationHelp,icon:const Icon(Icons.help_outline_rounded)),
      ],
    ),
    body:Stack(children:[
      const Positioned.fill(child:WoodlandBackground()),
      SafeArea(child:LayoutBuilder(builder:(context,b){
        if(b.maxWidth<850&&b.maxWidth<=b.maxHeight*1.35) return _mobilePanel(current);
        return Padding(padding:const EdgeInsets.all(24),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Expanded(flex:4,child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:480),child:_mushroomInstrument(current,height:b.maxHeight>560?560:b.maxHeight)))),
          const SizedBox(width:24),
          Expanded(flex:6,child:_panel(current)),
        ]));
      })),
    ]),
  );
}
void _showObservationHelp()=>showModalBottomSheet<void>(
  context:context,isScrollControlled:true,
  builder:(ctx)=>SafeArea(child:SingleChildScrollView(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text('Kijk naar je eigen vondst',style:Theme.of(ctx).textTheme.headlineSmall),
    const SizedBox(height:12),
    const Text('De beelden zijn illustratieve voorbeelden. Kies op basis van wat je werkelijk waarneemt. Kies bij twijfel Onzeker of Niet beoordeeld; dat sluit geen mogelijkheden uit.'),
    const SizedBox(height:12),
    const Text('Tik op een bereikbare ring of veeg erover. Veeg in de selector naar een observatie en bevestig deze expliciet. Een eerdere observatie wijzigen verwijdert de latere antwoorden.'),
    const SizedBox(height:12),
    const Text(determinationSafetyWarning),
    const SizedBox(height:16),
    FilledButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Verder waarnemen')),
  ]))),
);
void _swipeObservation(DragEndDetails details){
  final speed=details.primaryVelocity??0;
  if(speed.abs()<180)return;
  if(speed>0){if(history.isNotEmpty)back();return;}
  if(ended)return;
  final options=wheelSteps[step]!.options;
  if(options.length==1)choose(options.first);
  else _openWheelSelector(wheelSteps[step]!.title,[step]);
}
Widget _mobilePanel(WheelStep current)=>LayoutBuilder(builder:(context,limits){
  final instrumentHeight=(limits.maxHeight*.48).clamp(270.0,410.0);
  return Column(children:[
    _mushroomInstrument(current,height:instrumentHeight),
    Expanded(child:_panel(current,compact:true)),
  ]);
});
Widget _mushroomInstrument(WheelStep current,{double height=460}) {
  return SizedBox(height:height,child:ClipRRect(borderRadius:BorderRadius.circular(24),child:LayoutBuilder(builder:(context,limits)=>Stack(alignment:Alignment.topCenter,children:[
    Positioned.fill(child:ExcludeSemantics(child:Image.asset(mushroomInstrumentAsset,fit:BoxFit.fill))),
    const Positioned.fill(child:IgnorePointer(child:DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,stops:[0,.40,.62,1],colors:[Color(0x400e1e0d),Color(0x180e1e0d),Colors.transparent,Color(0x200e1e0d)]))))),
    Positioned(top:0,left:0,right:0,height:height*.43,child:GestureDetector(key:const ValueKey('swipeable-mushroom-wheel'),behavior:HitTestBehavior.translucent,onHorizontalDragEnd:_swipeObservation,child:Padding(padding:const EdgeInsets.fromLTRB(8,8,8,0),child:FittedBox(fit:BoxFit.scaleDown,alignment:Alignment.topCenter,child:SizedBox(width:limits.maxWidth-16,child:Column(mainAxisSize:MainAxisSize.min,children:[
      _capDots(),
      const SizedBox(height:5),
      GestureDetector(key:const ValueKey('mushroom-cap'),behavior:HitTestBehavior.opaque,onTap:_showPossibilities,child:Semantics(button:true,label:'Bekijk de levende mogelijkheden',child:Column(children:[
        Text(ended?'Determinatie voltooid':'Observatie ${route.length+1}',style:const TextStyle(color:Color(0xfffff4de),fontSize:10,fontWeight:FontWeight.w800,letterSpacing:1)),
        const SizedBox(height:3),
        Text.rich(TextSpan(children:[TextSpan(text:'${result.remaining.length} mogelijkheden · ',style:const TextStyle(fontSize:11,fontWeight:FontWeight.w500)),TextSpan(text:current.title)]),textAlign:TextAlign.center,maxLines:2,style:const TextStyle(color:Colors.white,fontSize:20,fontWeight:FontWeight.w900,shadows:[Shadow(color:Colors.black,blurRadius:10)])),

      ]))),
    ])))))),
    Positioned(top:height*.43,left:12,right:12,bottom:height*.07,child:_wheelStack(answers.length)),
    Positioned(bottom:5,left:8,right:8,child:Text('VEEG OVER DE RINGEN · TIK OM TE KIEZEN',textAlign:TextAlign.center,style:TextStyle(fontSize:9,fontWeight:FontWeight.w700,letterSpacing:.5,color:Colors.white,shadows:[Shadow(color:Colors.black,blurRadius:5)]))),
  ]))));
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
  return LayoutBuilder(builder:(context,limits)=>FittedBox(
    fit:BoxFit.scaleDown,child:SizedBox(width:290,child:Column(
    mainAxisSize:MainAxisSize.min,
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
          final width=isActive?270.0:250.0-i*3;
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
                onHorizontalDragEnd:reachable?(_)=>_openGroup(i):null,
                child:AnimatedOpacity(
                  duration:const Duration(milliseconds:220),
                  opacity:reachable?1:.88,
                  child:AnimatedContainer(
                    duration:const Duration(milliseconds:220),
                    curve:Curves.easeOutCubic,
                    margin:const EdgeInsets.symmetric(vertical:1.5),
                    height:44,
                    width:width,
                    decoration:BoxDecoration(
                      color:isActive?const Color(0xffffd77c):const Color(0xfffff2da),
                      image:DecorationImage(image:const AssetImage(stemRingTextureAsset),fit:BoxFit.cover,colorFilter:ColorFilter.mode(isActive?const Color(0x80ffcc5b):const Color(0x45fff1cf),BlendMode.srcATop)),
                      borderRadius:BorderRadius.circular(50),
                      border:Border.all(
                        color:isActive?const Color(0xff84591f):const Color(0xffb89255),
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
                          Icon(_groupIcons[i],size:22,color:const Color(0xff675033)),const SizedBox(width:10),
                          Flexible(child:Text(
                            groups[i].title,
                            maxLines:1,overflow:TextOverflow.ellipsis,
                            style:TextStyle(
                              color:const Color(0xff47321b),
                              fontSize:14,
                              fontWeight:FontWeight.w800,
                              letterSpacing:.15,
                            ),
                          )),
                          const SizedBox(width:8),if(isActive)const Icon(Icons.chevron_right_rounded,size:20,color:Color(0xff513817)),
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
  ))));
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
        Flexible(child:ListView(shrinkWrap:true,children:result.remaining.map((x)=>_candidateTile(x)).toList())),
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
Widget _panel(WheelStep current,{bool compact=false}){
  final r=result;
  return Card(
    elevation:compact?0:1,
    margin:EdgeInsets.zero,
    color:compact?const Color(0xfffff9ed):const Color(0xfffff9ed),
    shape:RoundedRectangleBorder(
      borderRadius:BorderRadius.circular(compact?30:22),
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
        if(answers.containsKey(4)&&!ended)...[_candidatePanel(r),const SizedBox(height:10)],
        if(ended)_resultPanel(r)else if(compact&&MediaQuery.sizeOf(context).height>=700&&MediaQuery.textScalerOf(context).scale(12)<=16) LayoutBuilder(builder:(context,limits)=>GridView.builder(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),gridDelegate:SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:2,crossAxisSpacing:9,mainAxisSpacing:9,childAspectRatio:limits.maxWidth < 350 ? 0.91 : 1.02),itemCount:current.options.length,itemBuilder:(context,i)=>_compactOptionCard(current.options[i]))) else...current.options.map(_optionCard),
        if(route.isNotEmpty)...[
          const Divider(height:28),
          Row(children:[const Expanded(child:Text('Gevolgde route',style:TextStyle(fontWeight:FontWeight.bold))),if(history.isNotEmpty)TextButton.icon(onPressed:back,icon:const Icon(Icons.undo),label:const Text('Vorige'))]),
          Text(route.join('  →  ')),
        ],
      ]),
    ),
  );
}
String _candidatePhotoLabel(Candidate candidate) {
  for(final traits in [candidate.underside,candidate.form,candidate.surface,candidate.spore]) {
    if(traits!=null) for(final label in traits) {
      if(observationPhotographs.containsKey(label)) return label;
    }
  }
  return 'Toon eindresultaat';
}
Widget _candidateTile(Candidate x,{bool evidence=false})=>Card(
  margin:const EdgeInsets.symmetric(vertical:5),
  shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18),side:const BorderSide(color:Color(0xffdfcda8))),
  child:ListTile(contentPadding:const EdgeInsets.all(12),
    leading:SizedBox(width:64,height:72,child:ChoicePhotograph(label:_candidatePhotoLabel(x))),
    title:Text(x.name,style:const TextStyle(fontWeight:FontWeight.w800)),
    subtitle:Text('${x.score(answers).label}${!evidence?'':'\n${x.supporting(answers).isEmpty?'Niet uitgesloten door de ingevoerde harde kenmerken':'Ondersteund door: ${x.supporting(answers).join(' • ')}'}${x.typicalSupporting(answers).isEmpty?'':'\nAanvullend bronkenmerk (niet uitsluitend): ${x.typicalSupporting(answers).join(' • ')}'}'}'),
  ),
);
Widget _candidatePanel(DeterminationResult r)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
  Row(children:[Expanded(child:Text('Mogelijke groepen: ${r.remaining.length} · beste overeenkomst eerst',style:const TextStyle(fontSize:12,fontWeight:FontWeight.bold))),TextButton(onPressed:()=>setState(()=>showExcluded=!showExcluded),child:Text('${r.excluded.length} uitgesloten'))]),
  SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:r.remaining.map((x){
    final score=x.score(answers),hard=x.supporting(answers),soft=x.typicalSupporting(answers);
    final evidence=<String>[if(hard.isNotEmpty)'Hard: ${hard.join(' • ')}',if(soft.isNotEmpty)'Aanvullend, niet uitsluitend: ${soft.join(' • ')}'];
    return Padding(padding:const EdgeInsets.only(right:6),child:Tooltip(message:evidence.isEmpty?'Nog geen specifiek bevestigend bronkenmerk vastgelegd':evidence.join('\n'),child:Chip(
      avatar:Icon(score.complete?Icons.task_alt:Icons.pending_outlined,size:16),
      label:Text('${x.name} · ${score.percent==null?'—':'${score.percent}%'} · ${(score.coverage*100).round()}% dekking'),
    )));
  }).toList())),
  Align(alignment:Alignment.centerRight,child:TextButton.icon(onPressed:_showPossibilities,icon:const Icon(Icons.view_list_outlined,size:18),label:const Text('Bekijk mogelijkheden'))),
  if(showExcluded)...r.excluded.entries.map((e)=>ListTile(dense:true,leading:const Icon(Icons.block,size:18),title:Text(e.key.name),subtitle:Text(e.value))),
]);
Widget _resultPanel(DeterminationResult r){final key=detailKeyFor(genusHint:r.genusHint,candidateNames:r.remaining.map((x)=>x.name));return Column(children:[const Icon(Icons.fact_check_outlined,size:48),if(r.remaining.length>1)const Padding(padding:EdgeInsets.only(bottom:8),child:Text('Gerangschikt op overeenkomst met harde bronkenmerken; aanvullende bronkenmerken breken alleen gelijke scores en sluiten nooit uit. Dit is geen waarschijnlijkheidsrangschikking.',textAlign:TextAlign.center)),if(r.genusHint!=null)ListTile(leading:const Icon(Icons.call_split),title:Text('Bronondersteunde geslachtssplitsing: ${r.genusHint}')),...r.remaining.map((x)=>_candidateTile(x,evidence:true)),if(key!=null)Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(children:[Text(key.title,style:Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.bold)),const SizedBox(height:6),Text(key.sourceNote,textAlign:TextAlign.center),const SizedBox(height:10),FilledButton.icon(onPressed:()=>_openDetailKey(key),icon:const Icon(Icons.account_tree_outlined),label:const Text('Open detailsleutel'))])))else const Text('Voor deze kandidaat bevat de huidige bronset nog geen eenduidige gecodeerde detailsleutel. Vul geen soortnaam in op basis van aannames.',textAlign:TextAlign.center),const SizedBox(height:12),const Text('De matchscore is géén kans dat de determinatie juist is: hij geeft alleen aan welk deel van de voor die kandidaat gecodeerde, beoordeelde kenmerken overeenkomt. Onbekende kenmerken tellen niet als fout. Sommige taxa vragen microscopie, chemische kenmerken of DNA voor verdere bevestiging.',textAlign:TextAlign.center),const SizedBox(height:12),Card(color:Theme.of(context).colorScheme.errorContainer,child:const Padding(padding:EdgeInsets.all(12),child:Text(determinationSafetyWarning))),FilledButton.icon(onPressed:reset,icon:const Icon(Icons.restart_alt),label:const Text('Nieuwe determinatie'))]);}
void _openDetailKey(DetailKey key){String? initial;if(key.id=='russulaceae')initial=answers[22];if(key.id=='galerina')initial=answers[17];Navigator.of(context).push(MaterialPageRoute(builder:(_)=>DetailKeyPage(keyData:key,initialAnswer:initial)));}
Widget _optionPhotograph(WheelOption o,{double size=82})=>ChoicePhotograph(label:o.label);
Widget _compactOptionCard(WheelOption o)=>Semantics(button:true,label:'Kies ${o.label}',child:Material(color:const Color(0xfffffcf5),borderRadius:BorderRadius.circular(16),clipBehavior:Clip.antiAlias,child:InkWell(onTap:()=>choose(o),child:Container(
  decoration:BoxDecoration(border:Border.all(color:const Color(0xffdfc698)),borderRadius:BorderRadius.circular(16)),
  child:Column(children:[
    Expanded(child:Padding(padding:const EdgeInsets.all(4),child:_optionPhotograph(o))),
    Padding(padding:const EdgeInsets.fromLTRB(8,4,6,8),child:Row(children:[
      Expanded(child:Text(o.label,maxLines:3,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w800,color:Color(0xff3c3224)))),
      const SizedBox(width:4),
      Container(width:28,height:28,decoration:const BoxDecoration(color:Color(0xffe4eddc),shape:BoxShape.circle),child:const Icon(Icons.chevron_right_rounded,color:Color(0xff315d35),size:22)),
    ])),
  ]),
))));
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
            width:72,height:72,
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
    return Scaffold(appBar:AppBar(backgroundColor:const Color(0xfffff3dd),title:Text(widget.keyData.title)),body:Stack(children:[const Positioned.fill(child:WoodlandBackground()),Container(margin:const EdgeInsets.all(12),decoration:BoxDecoration(color:const Color(0xfffff9ed),borderRadius:BorderRadius.circular(24)),child:ListView(padding:const EdgeInsets.all(20),children:[Text(widget.keyData.sourceNote,style:Theme.of(context).textTheme.bodySmall),if(cat!=null)...[const SizedBox(height:12),Card(child:ExpansionTile(initiallyExpanded:true,title:Text('Bronprofiel — ${cat.group}'),children:[for(final p in cat.profile)ListTile(dense:true,leading:const Icon(Icons.check_circle_outline,size:18),title:Text(p)),if(cat.taxa.isNotEmpty)...[const Divider(),ListTile(leading:const Icon(Icons.filter_alt_outlined),title:Text('${cat.taxa.length} nog mogelijke soort${cat.taxa.length==1?'':'en'} uit de aangeleverde bron',style:const TextStyle(fontWeight:FontWeight.bold)),subtitle:const Text('Deze namen blijven mogelijk binnen de overgebleven groep; ze zijn niet bevestigd.')),Padding(padding:const EdgeInsets.fromLTRB(16,0,16,12),child:Wrap(spacing:6,runSpacing:6,children:[for(final taxon in cat.taxa)Chip(avatar:const Icon(Icons.help_outline,size:16),label:Text(taxon))]))],if(cat.possibilityCaveat!=null)Padding(padding:const EdgeInsets.fromLTRB(16,0,16,12),child:Text(cat.possibilityCaveat!,style:Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle:FontStyle.italic))),if(cat.nextEvidence.isNotEmpty)...[const Divider(),const ListTile(title:Text('Wat kan verder onderscheid geven?',style:TextStyle(fontWeight:FontWeight.bold))),for(final evidence in cat.nextEvidence)ListTile(dense:true,leading:const Icon(Icons.biotech_outlined,size:18),title:Text(evidence))],Padding(padding:const EdgeInsets.all(12),child:Text(cat.note,style:Theme.of(context).textTheme.bodySmall))]))],const SizedBox(height:20),if(result==null)...[Text(step.title,style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.bold)),const SizedBox(height:8),Text(step.help),const SizedBox(height:16),...step.options.map((o)=>Card(child:ListTile(leading:SizedBox(width:64,height:64,child:ChoicePhotograph(label:o.label)),title:Text(o.label),trailing:const Icon(Icons.chevron_right),onTap:()=>pick(o)))),],if(result!=null)...[const Icon(Icons.account_tree_outlined,size:64),const SizedBox(height:12),Text(result!,textAlign:TextAlign.center,style:Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight:FontWeight.bold)),const SizedBox(height:12),const Text('Dit is het diepste niveau dat de momenteel gecodeerde broncriteria ondersteunen. Genoemde soorten blijven mogelijke referenties; een macroscopische sleutel kan niet altijd verder scheiden. Waar nodig moet verdere bevestiging met microscopie, chemische kenmerken of DNA gebeuren.',textAlign:TextAlign.center),const SizedBox(height:12),Card(color:Theme.of(context).colorScheme.errorContainer,child:const Padding(padding:EdgeInsets.all(12),child:Text(determinationSafetyWarning,textAlign:TextAlign.center))),const SizedBox(height:20),OutlinedButton(onPressed:()=>setState(()=>result=null),child:const Text('Waarneming opnieuw beoordelen'))]]))]));
  }
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
    height:(MediaQuery.sizeOf(context).height*.80).clamp(280.0,500.0),
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
                  padding:const EdgeInsets.all(12),
                  child:SingleChildScrollView(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
                    SizedBox(width:72,height:60,child:ChoicePhotograph(label:selected??ws.options.first.label)),
                    const SizedBox(height:8),
                    Container(
                      width:32,height:32,
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
                  ])),
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

const _groupIcons=[Icons.umbrella_outlined,Icons.fingerprint,Icons.forest_outlined,Icons.search,Icons.format_list_bulleted];
