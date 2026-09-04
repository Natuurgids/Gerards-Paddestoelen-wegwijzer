import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Compact, app-owned visual aid for determination choices.
/// These are schematic character illustrations, not species photographs.
class TraitVisual extends StatelessWidget {
  const TraitVisual({super.key, required this.traitCode, required this.optionId, required this.optionLabel, this.size = 72});
  final String traitCode; final int optionId; final String optionLabel; final double size;
  @override Widget build(BuildContext context){final scheme=Theme.of(context).colorScheme;return Semantics(label:optionLabel,image:true,child:Container(width:size,height:size,decoration:BoxDecoration(color:scheme.surfaceContainerLowest,borderRadius:BorderRadius.circular(10),border:Border.all(color:scheme.outlineVariant)),child:CustomPaint(painter:_TraitVisualPainter(traitCode:traitCode,variant:optionId,foreground:scheme.onSurfaceVariant,accent:scheme.primary))));}
}
class _TraitVisualPainter extends CustomPainter{
  const _TraitVisualPainter({required this.traitCode,required this.variant,required this.foreground,required this.accent});
  final String traitCode; final int variant; final Color foreground,accent;
  @override void paint(Canvas canvas,Size size){final p=Paint()..color=foreground..strokeWidth=2..style=PaintingStyle.stroke..strokeCap=StrokeCap.round;final fill=Paint()..color=accent.withValues(alpha:.18)..style=PaintingStyle.fill;final c=Offset(size.width/2,size.height/2),w=size.width,h=size.height;
    if(traitCode.contains('color')||traitCode.contains('colour')){final hue=((variant*47)%360).toDouble();canvas.drawCircle(c,w*.25,Paint()..color=HSVColor.fromAHSV(1,hue,.55,.72).toColor());canvas.drawCircle(c,w*.25,p);return;}
    if(traitCode.contains('spore_print')){canvas.drawOval(Rect.fromCenter(center:c,width:w*.58,height:h*.34),fill);for(var i=0;i<9;i++){canvas.drawCircle(Offset(w*(.25+(i%3)*.25),h*(.32+(i~/3)*.18)),2.2,Paint()..color=foreground.withValues(alpha:.65));}return;}
    if(traitCode.contains('gill')){canvas.drawArc(Rect.fromLTWH(w*.18,h*.18,w*.64,h*.64),3.35,2.72,false,p);for(var i=0;i<8;i++){final a=3.5+i*.32;canvas.drawLine(c,c+Offset(math.cos(a),math.sin(a))*w*.29,p);}return;}
    if(traitCode.contains('ring')){canvas.drawLine(Offset(c.dx,h*.16),Offset(c.dx,h*.84),p);final r=Rect.fromCenter(center:Offset(c.dx,h*.48),width:w*.48,height:h*.13);canvas.drawOval(r,fill);canvas.drawOval(r,p);return;}
    if(traitCode.contains('volva')||traitCode.contains('base')){canvas.drawLine(Offset(c.dx,h*.14),Offset(c.dx,h*.67),p);final path=Path()..moveTo(w*.25,h*.62)..quadraticBezierTo(c.dx,h*.92,w*.75,h*.62)..lineTo(w*.25,h*.62)..close();canvas.drawPath(path,fill);canvas.drawPath(path,p);return;}
    if(traitCode.contains('surface')){final r=RRect.fromRectAndRadius(Rect.fromLTWH(w*.2,h*.18,w*.6,h*.64),const Radius.circular(14));canvas.drawRRect(r,fill);canvas.drawRRect(r,p);for(var i=0;i<6;i++){final y=h*(.27+i*.085);canvas.drawLine(Offset(w*.3,y),Offset(w*.7,y+(i.isEven?3:-3)),p);}return;}
    if(traitCode.contains('habitat')||traitCode.contains('substrate')){canvas.drawLine(Offset(w*.15,h*.75),Offset(w*.85,h*.75),p);canvas.drawLine(Offset(c.dx,h*.72),Offset(c.dx,h*.3),p);canvas.drawCircle(Offset(c.dx,h*.25),w*.17,fill);canvas.drawCircle(Offset(c.dx,h*.25),w*.17,p);return;}
    if(traitCode.contains('growth')||traitCode.contains('fruitbody')){for(var i=0;i<3;i++){_mushroom(canvas,Offset(w*(.3+i*.2),h*.58),w*(.16+i*.01),p,fill,i);}return;}_mushroom(canvas,c,w*.5,p,fill,variant);}
  void _mushroom(Canvas canvas,Offset c,double width,Paint p,Paint fill,int v){final stemTop=c.dy-width*.05;final stem=RRect.fromRectAndRadius(Rect.fromCenter(center:Offset(c.dx,c.dy+width*.2),width:width*.18,height:width*.62),Radius.circular(width*.07));canvas.drawRRect(stem,fill);canvas.drawRRect(stem,p);final cap=Path()..moveTo(c.dx-width*.48,stemTop)..quadraticBezierTo(c.dx,stemTop-width*(.42+(v%4)*.06),c.dx+width*.48,stemTop)..quadraticBezierTo(c.dx,stemTop+width*.14,c.dx-width*.48,stemTop)..close();canvas.drawPath(cap,fill);canvas.drawPath(cap,p);}
  @override bool shouldRepaint(covariant _TraitVisualPainter oldDelegate)=>oldDelegate.traitCode!=traitCode||oldDelegate.variant!=variant||oldDelegate.foreground!=foreground||oldDelegate.accent!=accent;
}
