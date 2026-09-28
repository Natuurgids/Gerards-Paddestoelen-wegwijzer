import 'package:flutter/material.dart';

enum DiagnosticArt { gills, pores, teeth, folds, gillFree, gillAttached, gillDecurrent, ring, volva, ringVolva, capSmooth, capFibrous, capScaly, capSlimy, sporeWhite, sporePink, sporeBrown, sporeDark, stemReticulate, stemScabrous, stemSmooth, soil, wood, moss, dung, unknown }

DiagnosticArt artFor(String label) {
  final s=label.toLowerCase();
  if(s.contains('plaatjes')) return DiagnosticArt.gills;
  if(s.contains('buisjes')||s.contains('poriën')) return DiagnosticArt.pores;
  if(s.contains('tanden')||s.contains('stekels')) return DiagnosticArt.teeth;
  if(s.contains('plooien')||s.contains('ribben')) return DiagnosticArt.folds;
  if(s=='vrij') return DiagnosticArt.gillFree;
  if(s=='aangehecht') return DiagnosticArt.gillAttached;
  if(s=='aflopend') return DiagnosticArt.gillDecurrent;
  if(s=='ring') return DiagnosticArt.ring;
  if(s.contains('beurs')&&!s.contains('beide')) return DiagnosticArt.volva;
  if(s=='beide') return DiagnosticArt.ringVolva;
  if(s=='glad') return DiagnosticArt.capSmooth;
  if(s=='vezelig') return DiagnosticArt.capFibrous;
  if(s.contains('schubbig / wrattig')) return DiagnosticArt.capScaly;
  if(s.contains('kleverig')) return DiagnosticArt.capSlimy;
  if(s.contains('wit / crème')) return DiagnosticArt.sporeWhite;
  if(s=='roze') return DiagnosticArt.sporePink;
  if(s.contains('bruin / roest')) return DiagnosticArt.sporeBrown;
  if(s.contains('purperbruin')) return DiagnosticArt.sporeDark;
  if(s=='netvormig') return DiagnosticArt.stemReticulate;
  if(s.contains('schubbig / gestippeld')) return DiagnosticArt.stemScabrous;
  if(s.contains('glad / anders')) return DiagnosticArt.stemSmooth;
  if(s.contains('bodem')||s.contains('strooisel')) return DiagnosticArt.soil;
  if(s.contains('hout')) return DiagnosticArt.wood;
  if(s.contains('gras / mos')) return DiagnosticArt.moss;
  if(s.contains('mest')) return DiagnosticArt.dung;
  return DiagnosticArt.unknown;
}

class DiagnosticIllustration extends StatelessWidget {
  const DiagnosticIllustration({super.key,required this.art,this.size=72});
  final DiagnosticArt art; final double size;
  @override Widget build(BuildContext context)=>SizedBox(width:size,height:size,child:CustomPaint(painter:_DiagnosticPainter(art,Theme.of(context).colorScheme)));
}

class _DiagnosticPainter extends CustomPainter {
  _DiagnosticPainter(this.art,this.cs); final DiagnosticArt art; final ColorScheme cs;
  Paint line([double w=2])=>Paint()..color=cs.onSurface..style=PaintingStyle.stroke..strokeWidth=w..strokeCap=StrokeCap.round;
  Paint fill()=>Paint()..color=cs.surfaceContainerHighest..style=PaintingStyle.fill;
  @override void paint(Canvas c,Size z){final w=z.width,h=z.height,p=line();
    void cap(){final r=Rect.fromLTWH(w*.12,h*.18,w*.76,h*.36);c.drawArc(r,3.25,2.92,false,p);c.drawLine(Offset(w*.13,h*.38),Offset(w*.87,h*.38),p);c.drawLine(Offset(w*.43,h*.38),Offset(w*.40,h*.88),p);c.drawLine(Offset(w*.57,h*.38),Offset(w*.60,h*.88),p);}
    switch(art){
      case DiagnosticArt.gills: cap(); for(var i=0;i<9;i++){final x=w*(.18+i*.08);c.drawLine(Offset(w*.5,h*.38),Offset(x,h*.54),line(1));} break;
      case DiagnosticArt.pores: cap(); for(var y=0;y<3;y++)for(var x=0;x<7;x++)c.drawCircle(Offset(w*(.24+x*.085),h*(.43+y*.06)),w*.018,line(1)); break;
      case DiagnosticArt.teeth: cap(); for(var i=0;i<10;i++){final x=w*(.18+i*.07);c.drawLine(Offset(x,h*.40),Offset(x,h*(.48+(i%2)*.05)),line(1.3));} break;
      case DiagnosticArt.folds: cap(); for(var i=0;i<7;i++){final x=w*(.23+i*.09);final path=Path()..moveTo(w*.5,h*.38)..quadraticBezierTo(x,h*.44,x,h*.55);c.drawPath(path,line(1.4));} break;
      case DiagnosticArt.gillFree: case DiagnosticArt.gillAttached: case DiagnosticArt.gillDecurrent:
        c.drawLine(Offset(w*.48,h*.18),Offset(w*.48,h*.88),p);c.drawLine(Offset(w*.56,h*.18),Offset(w*.56,h*.88),p);
        if(art==DiagnosticArt.gillFree){c.drawLine(Offset(w*.12,h*.38),Offset(w*.40,h*.38),p);c.drawLine(Offset(w*.64,h*.38),Offset(w*.90,h*.38),p);}
        else if(art==DiagnosticArt.gillAttached){c.drawLine(Offset(w*.12,h*.38),Offset(w*.48,h*.38),p);c.drawLine(Offset(w*.56,h*.38),Offset(w*.90,h*.38),p);}
        else {c.drawLine(Offset(w*.12,h*.30),Offset(w*.48,h*.48),p);c.drawLine(Offset(w*.56,h*.48),Offset(w*.90,h*.30),p);} break;
      case DiagnosticArt.ring: case DiagnosticArt.volva: case DiagnosticArt.ringVolva:
        cap(); if(art!=DiagnosticArt.volva)c.drawOval(Rect.fromCenter(center:Offset(w*.5,h*.58),width:w*.32,height:h*.10),p);if(art!=DiagnosticArt.ring)c.drawArc(Rect.fromLTWH(w*.30,h*.75,w*.40,h*.18),0,3.14,false,p);break;
      case DiagnosticArt.capSmooth: case DiagnosticArt.capFibrous: case DiagnosticArt.capScaly: case DiagnosticArt.capSlimy:
        cap();if(art==DiagnosticArt.capFibrous)for(var i=0;i<7;i++)c.drawLine(Offset(w*(.25+i*.08),h*.24),Offset(w*(.20+i*.10),h*.36),line(1));
        if(art==DiagnosticArt.capScaly)for(var i=0;i<7;i++)c.drawArc(Rect.fromCenter(center:Offset(w*(.25+i*.08),h*(.27+(i%2)*.06)),width:w*.09,height:h*.06),0,3.14,false,line(1));
        if(art==DiagnosticArt.capSlimy)c.drawArc(Rect.fromLTWH(w*.18,h*.13,w*.64,h*.20),3.2,2.8,false,line(4));break;
      case DiagnosticArt.sporeWhite: case DiagnosticArt.sporePink: case DiagnosticArt.sporeBrown: case DiagnosticArt.sporeDark:
        final color=art==DiagnosticArt.sporeWhite?Colors.white:art==DiagnosticArt.sporePink?const Color(0xffd79a9a):art==DiagnosticArt.sporeBrown?const Color(0xff8b5a3c):const Color(0xff3f3036);c.drawCircle(Offset(w*.5,h*.5),w*.29,Paint()..color=color);c.drawCircle(Offset(w*.5,h*.5),w*.29,line(1));for(var i=0;i<16;i++){final a=i*6.283/16;c.drawLine(Offset(w*.5,h*.5),Offset(w*.5+mathCos(a)*w*.26,h*.5+mathSin(a)*w*.26),Paint()..color=cs.outline.withValues(alpha:.35)..strokeWidth=1);}break;
      case DiagnosticArt.stemReticulate: case DiagnosticArt.stemScabrous: case DiagnosticArt.stemSmooth:
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w*.35,h*.10,w*.30,h*.80),Radius.circular(w*.10)),p);if(art==DiagnosticArt.stemReticulate){for(var y=.22;y<.80;y+=.13){c.drawLine(Offset(w*.37,h*y),Offset(w*.63,h*(y+.10)),line(1));c.drawLine(Offset(w*.63,h*y),Offset(w*.37,h*(y+.10)),line(1));}}if(art==DiagnosticArt.stemScabrous)for(var y=.20;y<.85;y+=.12){c.drawCircle(Offset(w*.43,h*y),2,p);c.drawCircle(Offset(w*.57,h*(y+.05)),2,p);}break;
      case DiagnosticArt.soil: case DiagnosticArt.wood: case DiagnosticArt.moss: case DiagnosticArt.dung:
        c.drawLine(Offset(w*.10,h*.68),Offset(w*.90,h*.68),p);if(art==DiagnosticArt.wood)c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w*.15,h*.43,w*.70,h*.22),Radius.circular(8)),p);else if(art==DiagnosticArt.moss)for(var i=0;i<8;i++)c.drawArc(Rect.fromLTWH(w*(.12+i*.1),h*.48,w*.12,h*.20),3.2,2.8,false,p);else if(art==DiagnosticArt.dung)c.drawOval(Rect.fromLTWH(w*.25,h*.48,w*.50,h*.20),p);else for(var i=0;i<10;i++)c.drawCircle(Offset(w*(.12+i*.08),h*(.72+(i%2)*.07)),2,p);break;
      case DiagnosticArt.unknown: c.drawCircle(Offset(w*.5,h*.5),w*.30,fill());final tp=TextPainter(text:TextSpan(text:'?',style:TextStyle(fontSize:w*.42,color:cs.onSurfaceVariant,fontWeight:FontWeight.bold)),textDirection:TextDirection.ltr)..layout();tp.paint(c,Offset(w*.5-tp.width/2,h*.5-tp.height/2));break;
    }
  }
  double mathCos(double x){return _cos(x);} double mathSin(double x){return _sin(x);}
  double _cos(double x){return math.cos(x);} double _sin(double x){return math.sin(x);}
  @override bool shouldRepaint(covariant _DiagnosticPainter old)=>old.art!=art||old.cs!=cs;
}
