import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'determination_engine.dart';
import 'detail_keys.dart';
import 'diagnostic_illustrations.dart';
import 'source_catalog.dart';
import 'wheel_steps.dart';
void main()=>runApp(const App());
class App extends StatelessWidget{const App({super.key,this.skipSplash=false});final bool skipSplash;@override Widget build(BuildContext context)=>MaterialApp(debugShowCheckedModeBanner:false,theme:ThemeData(colorScheme:ColorScheme.fromSeed(seedColor:const Color(0xff315d35)),useMaterial3:true),home:skipSplash?const Wheel():const _WheelSplash());}
class _WheelSplash extends StatefulWidget{const _WheelSplash();@override State<_WheelSplash> createState()=>_WheelSplashState();}
class _WheelSplashState extends State<_WheelSplash>{String? version;bool done=false;@override void initState(){super.initState();_start();}Future<void> _start()async{final info=await PackageInfo.fromPlatform();if(!mounted)return;setState(()=>version='v${info.version}');await Future<void>.delayed(const Duration(milliseconds:1400));if(mounted)setState(()=>done=true);}@override Widget build(BuildContext context)=>AnimatedSwitcher(duration:const Duration(milliseconds:300),child:done?const Wheel(key:ValueKey('wheel')):Scaffold(key:const ValueKey('splash'),backgroundColor:const Color(0xff173d2b),body:GestureDetector(onTap:()=>setState(()=>done=true),child:Stack(fit:StackFit.expand,children:[Image.asset('assets/splash.png',fit:BoxFit.cover,errorBuilder:(_,__,___)=>const SizedBox()),Align(alignment:const Alignment(0,.88),child:SafeArea(minimum:const EdgeInsets.all(18),child:DecoratedBox(decoration:BoxDecoration(color:const Color(0xff173d2b).withValues(alpha:.72),borderRadius:BorderRadius.circular(18)),child:Padding(padding:const EdgeInsets.symmetric(horizontal:24,vertical:10),child:Column(mainAxisSize:MainAxisSize.min,children:[const Text('Wiel',style:TextStyle(color:Colors.white,fontSize:30,fontWeight:FontWeight.w800)),if(version!=null)Text(version!,style:const TextStyle(color:Colors.white,fontSize:16))])))))]))));}
class Wheel extends StatefulWidget{const Wheel({super.key});@override State<Wheel> createState()=>_WheelState();}
class _WheelState extends State<Wheel>{int step=1;bool ended=false,showExcluded=false;final answers=<int,String>{};final route=<String>[];final history=<int>[];DeterminationResult get result=>determine(answers);void choose(WheelOption o)=>setState((){history.add(step);answers[step]=o.label;route.add('${wheelSteps[step]!.title}: ${o.label}');ended=o.end;if(o.next!=null)step=o.next!;});void back()=>setState((){if(history.isEmpty)return;final previous=history.removeLast();answers.remove(previous);if(route.isNotEmpty)route.removeLast();step=previous;ended=false;showExcluded=false;});void reset()=>setState((){step=1;ended=false;showExcluded=false;answers.clear();route.clear();history.clear();});@override Widget build(BuildContext context){final current=wheelSteps[step]!;return Scaffold(appBar:AppBar(title:Row(mainAxisSize:MainAxisSize.min,children:[ClipRRect(borderRadius:BorderRadius.circular(8),child:Image.asset('assets/app_icon.png',width:36,height:36,fit:BoxFit.cover)),const SizedBox(width:10),const Flexible(child:Text('Paddenstoelen Determinatiewiel'))]),actions:[IconButton(tooltip:'Vorige observatie',onPressed:history.isEmpty?null:back,icon:const Icon(Icons.undo)),IconButton(tooltip:'Nieuwe determinatie',onPressed:reset,icon:const Icon(Icons.restart_alt))]),body:SafeArea(child:LayoutBuilder(builder:(context,b)=>Padding(padding:const EdgeInsets.all(16),child:b.maxWidth>850?Row(children:[Expanded(flex:6,child:_wheel(current)),const SizedBox(width:20),Expanded(flex:5,child:_panel(current))]):Column(children:[Expanded(flex:5,child:_wheel(current)),Expanded(flex:6,child:_panel(current))])))));}
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
Widget _panel(WheelStep current){final r=result;return Card(child:Padding(padding:const EdgeInsets.all(18),child:ListView(children:[Text(ended?'Determinatie-overzicht':'Observatie ${route.length+1} — ${current.title}',style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.bold)),const SizedBox(height:10),if(answers.containsKey(4))...[_candidatePanel(r),const Divider(height:20)],if(ended)_resultPanel(r)else...current.options.map(_optionCard),if(route.isNotEmpty)...[const Divider(height:28),Row(children:[const Expanded(child:Text('Gevolgde route',style:TextStyle(fontWeight:FontWeight.bold))),if(history.isNotEmpty)TextButton.icon(onPressed:back,icon:const Icon(Icons.undo),label:const Text('Vorige'))]),Text(route.join('  →  '))]])));}
Widget _candidatePanel(DeterminationResult r)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Expanded(child:Text('Mogelijke groepen: ${r.remaining.length} · beste overeenkomst eerst',style:const TextStyle(fontWeight:FontWeight.bold))),TextButton.icon(onPressed:()=>setState(()=>showExcluded=!showExcluded),icon:Icon(showExcluded?Icons.expand_less:Icons.expand_more),label:Text('${r.excluded.length} uitgesloten'))]),Wrap(spacing:6,runSpacing:4,children:r.remaining.map((x){final score=x.score(answers),hard=x.supporting(answers),soft=x.typicalSupporting(answers);final evidence=<String>[if(hard.isNotEmpty)'Hard: ${hard.join(' • ')}',if(soft.isNotEmpty)'Aanvullend, niet uitsluitend: ${soft.join(' • ')}'];return Tooltip(message:evidence.isEmpty?'Nog geen specifiek bevestigend bronkenmerk vastgelegd':evidence.join('\n'),child:Chip(avatar:Icon(score.complete?Icons.task_alt:Icons.pending_outlined,size:16),label:Text('${x.name} · ${score.percent==null?'—':'${score.percent}%'} · ${(score.coverage*100).round()}% dekking')));}).toList()),if(showExcluded)...r.excluded.entries.map((e)=>ListTile(dense:true,leading:const Icon(Icons.block,size:18),title:Text(e.key.name),subtitle:Text(e.value)))]);
Widget _resultPanel(DeterminationResult r){final key=detailKeyFor(genusHint:r.genusHint,candidateNames:r.remaining.map((x)=>x.name));return Column(children:[const Icon(Icons.fact_check_outlined,size:48),if(r.remaining.length>1)const Padding(padding:EdgeInsets.only(bottom:8),child:Text('Gerangschikt op overeenkomst met harde bronkenmerken; aanvullende bronkenmerken breken alleen gelijke scores en sluiten nooit uit. Dit is geen waarschijnlijkheidsrangschikking.',textAlign:TextAlign.center)),if(r.genusHint!=null)ListTile(leading:const Icon(Icons.call_split),title:Text('Bronondersteunde geslachtssplitsing: ${r.genusHint}')),...r.remaining.map((x)=>ListTile(leading:const Icon(Icons.eco_outlined),title:Text(x.name),subtitle:Text('${x.score(answers).label}\n${x.supporting(answers).isEmpty?'Niet uitgesloten door de ingevoerde harde kenmerken':'Ondersteund door: ${x.supporting(answers).join(' • ')}'}${x.typicalSupporting(answers).isEmpty?'':'\nAanvullend bronkenmerk (niet uitsluitend): ${x.typicalSupporting(answers).join(' • ')}'}'))),if(key!=null)Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(children:[Text(key.title,style:Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.bold)),const SizedBox(height:6),Text(key.sourceNote,textAlign:TextAlign.center),const SizedBox(height:10),FilledButton.icon(onPressed:()=>_openDetailKey(key),icon:const Icon(Icons.account_tree_outlined),label:const Text('Open detailsleutel'))])))else const Text('Voor deze kandidaat bevat de huidige bronset nog geen eenduidige gecodeerde detailsleutel. Vul geen soortnaam in op basis van aannames.',textAlign:TextAlign.center),const SizedBox(height:12),const Text('De matchscore is géén kans dat de determinatie juist is: hij geeft alleen aan welk deel van de voor die kandidaat gecodeerde, beoordeelde kenmerken overeenkomt. Onbekende kenmerken tellen niet als fout. Sommige taxa vragen microscopie, chemische kenmerken of DNA voor verdere bevestiging.',textAlign:TextAlign.center),const SizedBox(height:12),Card(color:Theme.of(context).colorScheme.errorContainer,child:const Padding(padding:EdgeInsets.all(12),child:Text('Niet gebruiken als bewijs van eetbaarheid. Bevestig een determinatie onafhankelijk.'))),FilledButton.icon(onPressed:reset,icon:const Icon(Icons.restart_alt),label:const Text('Nieuwe determinatie'))]);}
void _openDetailKey(DetailKey key){String? initial;if(key.id=='russulaceae')initial=answers[22];if(key.id=='galerina')initial=answers[17];Navigator.of(context).push(MaterialPageRoute(builder:(_)=>DetailKeyPage(keyData:key,initialAnswer:initial)));}
Widget _optionCard(WheelOption o)=>Padding(padding:const EdgeInsets.only(bottom:10),child:Semantics(button:true,label:'Kies ${o.label}',child:InkWell(borderRadius:BorderRadius.circular(16),onTap:()=>choose(o),child:Container(padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:Theme.of(context).colorScheme.surfaceContainerHighest,borderRadius:BorderRadius.circular(16)),child:Row(children:[DiagnosticIllustration(art:artFor(o.label),size:78),const SizedBox(width:14),Expanded(child:Text(o.label,style:Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.w600))),const Icon(Icons.chevron_right)])))));}
class DetailKeyPage extends StatefulWidget{const DetailKeyPage({super.key,required this.keyData,this.initialAnswer});final DetailKey keyData;final String? initialAnswer;@override State<DetailKeyPage> createState()=>_DetailKeyPageState();}
class _DetailKeyPageState extends State<DetailKeyPage>{late String stepId;String? result;SourceTaxonCatalog? get catalog=>sourceCatalogs[widget.keyData.id];@override void initState(){super.initState();stepId=widget.keyData.start;if(widget.initialAnswer!=null){final step=widget.keyData.steps[stepId]!;for(final o in step.options){if(o.label==widget.initialAnswer&&o.result!=null)result=o.result;}}}void pick(DetailOption o)=>setState((){if(o.result!=null)result=o.result;if(o.next!=null)stepId=o.next!;});@override Widget build(BuildContext context){final step=widget.keyData.steps[stepId]!,cat=catalog;return Scaffold(appBar:AppBar(title:Text(widget.keyData.title)),body:ListView(padding:const EdgeInsets.all(20),children:[Text(widget.keyData.sourceNote,style:Theme.of(context).textTheme.bodySmall),if(cat!=null)...[const SizedBox(height:12),Card(child:ExpansionTile(initiallyExpanded:true,title:Text('Bronprofiel — ${cat.group}'),children:[for(final p in cat.profile)ListTile(dense:true,leading:const Icon(Icons.check_circle_outline,size:18),title:Text(p)),if(cat.taxa.isNotEmpty)...[const Divider(),ListTile(leading:const Icon(Icons.filter_alt_outlined),title:Text('${cat.taxa.length} nog mogelijke soort${cat.taxa.length==1?'':'en'} uit de aangeleverde bron',style:const TextStyle(fontWeight:FontWeight.bold)),subtitle:const Text('Deze namen blijven mogelijk binnen de overgebleven groep; ze zijn niet bevestigd.')),Padding(padding:const EdgeInsets.fromLTRB(16,0,16,12),child:Wrap(spacing:6,runSpacing:6,children:[for(final taxon in cat.taxa)Chip(avatar:const Icon(Icons.help_outline,size:16),label:Text(taxon))]))],if(cat.possibilityCaveat!=null)Padding(padding:const EdgeInsets.fromLTRB(16,0,16,12),child:Text(cat.possibilityCaveat!,style:Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle:FontStyle.italic))),if(cat.nextEvidence.isNotEmpty)...[const Divider(),const ListTile(title:Text('Wat kan verder onderscheid geven?',style:TextStyle(fontWeight:FontWeight.bold))),for(final evidence in cat.nextEvidence)ListTile(dense:true,leading:const Icon(Icons.biotech_outlined,size:18),title:Text(evidence))],Padding(padding:const EdgeInsets.all(12),child:Text(cat.note,style:Theme.of(context).textTheme.bodySmall))]))],const SizedBox(height:20),if(result==null)...[Text(step.title,style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.bold)),const SizedBox(height:8),Text(step.help),const SizedBox(height:16),...step.options.map((o)=>Card(child:ListTile(leading:DiagnosticIllustration(art:artFor(o.label),size:58),title:Text(o.label),trailing:const Icon(Icons.chevron_right),onTap:()=>pick(o)))),],if(result!=null)...[const Icon(Icons.account_tree_outlined,size:64),const SizedBox(height:12),Text(result!,textAlign:TextAlign.center,style:Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight:FontWeight.bold)),const SizedBox(height:12),const Text('Dit is het diepste niveau dat de momenteel gecodeerde broncriteria ondersteunen. Genoemde soorten blijven mogelijke referenties; een macroscopische sleutel kan niet altijd verder scheiden. Waar nodig moet verdere bevestiging met microscopie, chemische kenmerken of DNA gebeuren.',textAlign:TextAlign.center),const SizedBox(height:20),OutlinedButton(onPressed:()=>setState(()=>result=null),child:const Text('Waarneming opnieuw beoordelen'))]]));}}
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
