import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'photographic_assets.dart';
import 'wheel_steps.dart';

/// Two independent photographic dials. Rotation previews; only confirmation
/// records an answer or revisits a reached observation.
class PhotographicRotaryWheel extends StatefulWidget {
  const PhotographicRotaryWheel({super.key, required this.current,
    required this.reached, required this.onChoose, required this.onObservation,
    required this.onPossibilities, required this.remaining});
  final WheelStep current;
  final List<int> reached;
  final ValueChanged<WheelOption> onChoose;
  final ValueChanged<int> onObservation;
  final VoidCallback onPossibilities;
  final int remaining;
  @override
  State<PhotographicRotaryWheel> createState() => _PhotographicRotaryWheelState();
}
class _PhotographicRotaryWheelState extends State<PhotographicRotaryWheel> {
  int choice = 0;
  late int observation = widget.reached.length - 1;
  Widget _heading() => Column(mainAxisSize: MainAxisSize.min, children: [
    Text('Observatie ${widget.reached.length}', style: const TextStyle(color: Color(0xffdbc392), fontSize: 12)),
    Text(widget.current.title, textAlign: TextAlign.center, maxLines: 2,
      overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700)),
    const Text('Buitenring: keuzes · binnenring: observaties', textAlign: TextAlign.center,
      style: TextStyle(color: Color(0xffeee1c7), fontSize: 12)),
  ]);
  Widget _controls() => Column(mainAxisSize: MainAxisSize.min, children: [
    Row(children: [
      IconButton(tooltip: 'Vorige keuze', onPressed: () => setState(() => choice=(choice-1)%widget.current.options.length), icon: const Icon(Icons.chevron_left, color: Colors.white)),
      Expanded(child: FilledButton.icon(key: const ValueKey('confirm-top-choice'),
        onPressed: () => widget.onChoose(widget.current.options[choice]),
        style: FilledButton.styleFrom(backgroundColor: const Color(0xfff2d6a0), foregroundColor: const Color(0xff233c27), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12)),
        icon: const Icon(Icons.check_circle_outline, size: 20),
        label: Text(widget.current.options[choice].label, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis))),
      IconButton(tooltip: 'Volgende keuze', onPressed: () => setState(() => choice=(choice+1)%widget.current.options.length), icon: const Icon(Icons.chevron_right, color: Colors.white)),
    ]),
    TextButton.icon(onPressed: widget.onPossibilities,
      icon: const Icon(Icons.eco_outlined, size: 18),
      label: Text('${widget.remaining} mogelijkheden · bekijk'),
      style: TextButton.styleFrom(foregroundColor: const Color(0xffffeed1))),
  ]);
  Widget _wheel() => LayoutBuilder(builder: (context, limits) {
    final diameter=math.min(limits.maxWidth, limits.maxHeight);
    return Center(child: SizedBox(width: diameter, height: diameter, child: Stack(alignment: Alignment.center, children: [
      _PhotoDial(key: const ValueKey('choice-dial'),
        labels: widget.current.options.map((o)=>o.label).toList(),
        photos: widget.current.options.map((o)=>observationPhotographs[o.label]!).toList(),
        selected: choice, innerRatio: .53, onSelected: (i)=>setState(()=>choice=i)),
      SizedBox(width: diameter*.51, height: diameter*.51,
        child: _PhotoDial(key: const ValueKey('observation-dial'),
          labels: widget.reached.map((s)=>wheelSteps[s]!.title).toList(),
          photos: widget.reached.map((s)=>observationPhotographs[wheelSteps[s]!.options.first.label]!).toList(),
          selected: observation, innerRatio: .55, small: true,
          onSelected: (i)=>setState(()=>observation=i))),
      SizedBox(width: diameter*.27, height: diameter*.27, child: ClipOval(child: Stack(fit: StackFit.expand, children: [
        Image.asset(observationPhotographs['Plaatjes']!, fit: BoxFit.cover),
        const ColoredBox(color: Color(0x99313c25)),
        Material(color: Colors.transparent, child: InkWell(key: const ValueKey('confirm-top-observation'),
          onTap: widget.reached[observation] == widget.reached.last ? null : ()=>widget.onObservation(widget.reached[observation]),
          child: Center(child: Padding(padding: const EdgeInsets.all(6), child: Text(
            widget.reached[observation] == widget.reached.last ? 'Draai om\nte kijken' : 'Open\nobservatie',
            maxLines: 3, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)))))),
      ]))),
      Positioned(top: 0, child: IgnorePointer(child: Icon(Icons.arrow_drop_down, color: const Color(0xffffdda1), size: diameter*.11))),
      Positioned(top: diameter*.225, child: const IgnorePointer(child: Icon(Icons.arrow_drop_down, color: Color(0xffffdda1), size: 22))),
    ])));
  });
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, limits) {
    final landscape=limits.maxWidth>limits.maxHeight*1.25;
    return Padding(padding: const EdgeInsets.all(12), child: landscape
      ? Row(children: [Expanded(flex: 6, child: _wheel()), const SizedBox(width: 16),
          Expanded(flex: 4, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [_heading(), const SizedBox(height: 18), _controls()]))])
      : Column(children: [_heading(), const SizedBox(height: 8), Expanded(child: _wheel()), const SizedBox(height: 8), _controls()]));
  });
}

class _PhotoDial extends StatefulWidget {
  const _PhotoDial({super.key, required this.labels, required this.photos,
    required this.selected, required this.innerRatio, required this.onSelected, this.small=false});
  final List<String> labels, photos;
  final int selected;
  final double innerRatio;
  final ValueChanged<int> onSelected;
  final bool small;
  @override
  State<_PhotoDial> createState()=>_PhotoDialState();
}
class _PhotoDialState extends State<_PhotoDial> {
  double rotation=0;
  double? previous;
  double get slice=>2*math.pi/widget.labels.length;
  @override
  void initState() {super.initState(); rotation=-widget.selected*slice;}
  @override
  void didUpdateWidget(covariant _PhotoDial oldWidget) {
    super.didUpdateWidget(oldWidget);
    if(previous==null) rotation=-widget.selected*slice;
  }
  void _move(Offset point, double size) {
    final angle=math.atan2(point.dy-size/2, point.dx-size/2);
    if(previous!=null) {
      var delta=angle-previous!;
      if(delta>math.pi) delta-=2*math.pi;
      if(delta < -math.pi) delta+=2*math.pi;
      setState(()=>rotation+=delta);
    }
    previous=angle;
  }
  void _snap() {
    previous=null;
    final index=(-rotation/slice).round()%widget.labels.length;
    setState(()=>rotation=-index*slice);
    widget.onSelected(index);
  }
  @override
  Widget build(BuildContext context)=>LayoutBuilder(builder: (context, limits) {
    final size=limits.maxWidth;
    final radius=size/2;
    return Semantics(label: widget.small ? 'Observatieschijf' : 'Keuzeschijf',
      value: widget.labels[widget.selected],
      increasedValue: widget.labels[(widget.selected+1)%widget.labels.length],
      decreasedValue: widget.labels[(widget.selected-1)%widget.labels.length],
      onIncrease: ()=>widget.onSelected((widget.selected+1)%widget.labels.length),
      onDecrease: ()=>widget.onSelected((widget.selected-1)%widget.labels.length),
      child: GestureDetector(behavior: HitTestBehavior.opaque,
        onPanStart: (d)=>_move(d.localPosition,size),
        onPanUpdate: (d)=>_move(d.localPosition,size),
        onPanEnd: (_)=>_snap(), onPanCancel: _snap,
        child: Stack(children: [
          for(var i=0;i<widget.labels.length;i++) ...[
            Positioned.fill(child: ClipPath(clipper: _SectorClipper(-math.pi/2+rotation+i*slice-slice/2, slice, widget.innerRatio),
              child: GestureDetector(onTap: ()=>widget.onSelected(i), child: Stack(fit: StackFit.expand, children: [
                Image.asset(woodlandBackgroundAsset, fit: BoxFit.cover),
                Positioned(
                  left: widget.labels.length==1 ? 0 : radius+math.cos(-math.pi/2+rotation+i*slice)*radius*.76-size*.33,
                  top: widget.labels.length==1 ? 0 : radius+math.sin(-math.pi/2+rotation+i*slice)*radius*.76-size*.33,
                  width: widget.labels.length==1 ? size : size*.66, height: widget.labels.length==1 ? size : size*.66,
                  child: Image.asset(widget.photos[i], fit: BoxFit.cover, cacheWidth: widget.small ? 256 : 768)),
                ColoredBox(color: i==widget.selected ? const Color(0x18322c1a) : const Color(0x55322c1a)),
              ])))),
            if(!widget.small || i==widget.selected) Positioned(
              left: radius+math.cos(-math.pi/2+rotation+i*slice)*radius*(widget.small ? .77 : .69)-size*(widget.small ? .15 : .14),
              top: radius+math.sin(-math.pi/2+rotation+i*slice)*radius*(widget.small ? .77 : .69)-size*(widget.small ? .07 : .06),
              width: size*(widget.small ? .30 : .28),
              child: GestureDetector(key: ValueKey('${widget.small ? 'observation' : 'choice'}-sector-$i'),
                onTap: ()=>widget.onSelected(i),
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xcc203822), borderRadius: BorderRadius.circular(8)),
                  child: Text(widget.labels[i], textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                    textScaler: TextScaler.linear(math.min(MediaQuery.textScalerOf(context).scale(1),1.3)),
                    style: TextStyle(color: const Color(0xfffff5de), fontSize: widget.small ? 8 : 12, fontWeight: FontWeight.w700))))),
          ],
          Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _DialRim(widget.innerRatio,rotation,widget.labels.length)))),
        ])));
  });
}
class _SectorClipper extends CustomClipper<Path> {
  const _SectorClipper(this.angle,this.sweep,this.inner);
  final double angle,sweep,inner;
  @override
  Path getClip(Size size) {
    final c=Offset(size.width/2,size.height/2), r=size.width/2;
    return Path()..moveTo(c.dx+math.cos(angle)*r*inner,c.dy+math.sin(angle)*r*inner)
      ..lineTo(c.dx+math.cos(angle)*r,c.dy+math.sin(angle)*r)
      ..arcTo(Rect.fromCircle(center:c,radius:r),angle,sweep,false)
      ..lineTo(c.dx+math.cos(angle+sweep)*r*inner,c.dy+math.sin(angle+sweep)*r*inner)
      ..arcTo(Rect.fromCircle(center:c,radius:r*inner),angle+sweep,-sweep,false)..close();
  }
  @override
  bool shouldReclip(_SectorClipper old)=>angle!=old.angle||sweep!=old.sweep||inner!=old.inner;
}
class _DialRim extends CustomPainter {
  const _DialRim(this.inner,this.rotation,this.count);
  final double inner,rotation;
  final int count;
  @override
  void paint(Canvas canvas,Size size) {
    final paint=Paint()..color=const Color(0xffd8bb7e)..style=PaintingStyle.stroke..strokeWidth=3;
    final c=Offset(size.width/2,size.height/2);
    canvas.drawCircle(c,size.width/2-2,paint);
    canvas.drawCircle(c,size.width/2*inner,paint);
    if(count>1) for(var i=0;i<count;i++) {
      final a=-math.pi/2+rotation+(i-.5)*2*math.pi/count;
      final unit=Offset(math.cos(a),math.sin(a));
      canvas.drawLine(c+unit*(size.width/2*inner),c+unit*(size.width/2-2),paint..strokeWidth=1.5);
    }
  }
  @override
  bool shouldRepaint(_DialRim old)=>inner!=old.inner||rotation!=old.rotation||count!=old.count;
}
