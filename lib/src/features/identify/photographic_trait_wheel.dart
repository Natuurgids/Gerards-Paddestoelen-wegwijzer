import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../data/models.dart';
import 'determination_option_visual.dart';

const _forestPhoto =
    'determination_wheel/assets/interface/woodland-background.png';
const _gold = Color(0xfff2d6a0);

/// Independent observations: rotation previews, confirmation records a value.
/// A seven-sector window keeps long choice lists readable on small screens.
class PhotographicTraitWheel extends StatefulWidget {
  const PhotographicTraitWheel({super.key, required this.groups,
    required this.selected, required this.onChoose, required this.onResults,
    required this.language});
  final List<List<TraitChoice>> groups;
  final Map<int, int> selected;
  final ValueChanged<TraitChoice> onChoose;
  final VoidCallback onResults;
  final String language;
  @override
  State<PhotographicTraitWheel> createState() => _PhotographicTraitWheelState();
}

class _PhotographicTraitWheelState extends State<PhotographicTraitWheel> {
  int group = 0, groupPreview = 0, choice = 0;
  String text(String nl, String en, String de) =>
      widget.language == 'nl' ? nl : widget.language == 'de' ? de : en;
  List<TraitChoice> get choices => widget.groups[group];
  void open(int index) {
    setState(() {
      group = groupPreview = index;
      final stored = widget.selected[choices.first.traitId];
      final previous = choices.indexWhere((item) => item.optionId == stored);
      choice = previous < 0 ? 0 : previous;
    });
  }
  void confirm() {
    widget.onChoose(choices[choice]);
    if (group < widget.groups.length - 1) open(group + 1);
  }
  Widget visual(TraitChoice item, double size) => DeterminationOptionVisual(
    traitCode: item.traitCode, optionId: item.optionId,
    optionLabel: item.optionLabel, size: size);
  Widget heading() => Column(mainAxisSize: MainAxisSize.min, children: [
    Text('${widget.selected.length}/${widget.groups.length} · '
      '${widget.groups.fold<int>(0, (n, g) => n + g.length)} '
      '${text('keuzes', 'choices', 'Optionen')}',
      style: const TextStyle(color: _gold, fontSize: 12)),
    Text(choices.first.traitLabel, maxLines: 2,
      textAlign: TextAlign.center, overflow: TextOverflow.ellipsis,
      style: const TextStyle(color: Colors.white, fontSize: 20,
        fontWeight: FontWeight.bold)),
    Text(text('Draai de keuze naar boven en bevestig',
      'Rotate a choice to the top and confirm',
      'Option nach oben drehen und bestätigen'),
      textAlign: TextAlign.center,
      style: const TextStyle(color: _gold, fontSize: 12)),
  ]);
  Widget controls() => Column(mainAxisSize: MainAxisSize.min, children: [
    Row(children: [
      IconButton(tooltip: text('Vorige keuze', 'Previous choice', 'Vorige Option'),
        onPressed: () => setState(() => choice = (choice - 1) % choices.length),
        icon: const Icon(Icons.chevron_left, color: _gold)),
      Expanded(child: FilledButton.icon(key: const ValueKey('confirm-trait'),
        style: FilledButton.styleFrom(backgroundColor: _gold,
          foregroundColor: const Color(0xff203b29)),
        onPressed: confirm, icon: const Icon(Icons.check),
        label: Text(choices[choice].optionLabel, maxLines: 2,
          overflow: TextOverflow.ellipsis, textAlign: TextAlign.center))),
      IconButton(tooltip: text('Volgende keuze', 'Next choice', 'Nächste Option'),
        onPressed: () => setState(() => choice = (choice + 1) % choices.length),
        icon: const Icon(Icons.chevron_right, color: _gold)),
    ]),
    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Flexible(child: TextButton(onPressed: () => open((group + 1) % widget.groups.length),
        child: Text(text('Overslaan', 'Skip', 'Überspringen'),
          style: const TextStyle(color: _gold)))),
      Flexible(child: TextButton.icon(onPressed: widget.onResults,
        icon: const Icon(Icons.eco, color: _gold, size: 18),
        label: Text(text('Nederlandse soorten', 'Dutch species', 'Niederländische Arten'),
          style: const TextStyle(color: _gold)))),
    ]),
    Text(text('Foto’s zijn voorbeelden; fijne varianten kunnen een groepsfoto delen.',
      'Photos are examples; fine variants may share a group photo.',
      'Fotos sind Beispiele; feine Varianten können ein Gruppenfoto teilen.'),
      maxLines: 2, textAlign: TextAlign.center,
      style: const TextStyle(color: Color(0xffe5dfcc), fontSize: 10)),
  ]);
  Widget wheel() => LayoutBuilder(builder: (context, bounds) {
    final size = math.min(bounds.maxWidth, bounds.maxHeight);
    return Center(child: SizedBox.square(dimension: size,
      child: Stack(alignment: Alignment.center, children: [
        PhotographicChoiceDial(key: const ValueKey('trait-choice-dial'),
          count: choices.length, selected: choice, inner: .56,
          label: text('Keuzeschijf', 'Choice dial', 'Optionsscheibe'),
          labels: choices.map((item) => item.optionLabel).toList(),
          imageBuilder: (index) => visual(choices[index], size),
          onChanged: (index) => setState(() => choice = index)),
        SizedBox.square(dimension: size * .54,
          child: PhotographicChoiceDial(key: const ValueKey('trait-group-dial'),
            count: widget.groups.length, selected: groupPreview, inner: .55,
            label: text('Observatieschijf', 'Observation dial', 'Beobachtungsscheibe'),
            labels: widget.groups.map((g) => g.first.traitLabel).toList(),
            imageBuilder: (index) => visual(widget.groups[index].first, size * .54),
            onChanged: (index) => setState(() => groupPreview = index))),
        SizedBox.square(dimension: size * .28,
          child: ClipOval(child: Material(color: const Color(0xff203b29),
            child: InkWell(key: const ValueKey('open-trait-group'),
              onTap: () => open(groupPreview),
              child: Center(child: Padding(padding: const EdgeInsets.all(6),
                child: Text(widget.groups[groupPreview].first.traitLabel,
                  maxLines: 3, textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _gold, fontSize: 11,
                    fontWeight: FontWeight.bold)))))))),
        Positioned(top: 0, child: IgnorePointer(child:
          Icon(Icons.arrow_drop_down, color: _gold, size: size * .1))),
        Positioned(top: size * .22, child: const IgnorePointer(child:
          Icon(Icons.arrow_drop_down, color: _gold, size: 22))),
      ])));
  });
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(image: DecorationImage(
      image: AssetImage(_forestPhoto), fit: BoxFit.cover)),
    child: ColoredBox(color: const Color(0x88313c25),
      child: LayoutBuilder(builder: (context, bounds) {
        final wide = bounds.maxWidth > bounds.maxHeight * 1.2;
        return Padding(padding: const EdgeInsets.all(10), child: wide
          ? Row(children: [Expanded(flex: 6, child: wheel()),
            Expanded(flex: 4, child: SingleChildScrollView(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [heading(), const SizedBox(height: 10), controls()])))])
          : Column(children: [heading(), Expanded(child: wheel()), controls()]));
      })));
}

class PhotographicChoiceDial extends StatefulWidget {
  const PhotographicChoiceDial({super.key, required this.count,
    required this.selected, required this.labels, required this.imageBuilder,
    required this.onChanged, required this.label, required this.inner});
  final int count, selected;
  final List<String> labels;
  final Widget Function(int) imageBuilder;
  final ValueChanged<int> onChanged;
  final String label;
  final double inner;
  @override
  State<PhotographicChoiceDial> createState() => _PhotographicChoiceDialState();
}
class _PhotographicChoiceDialState extends State<PhotographicChoiceDial> {
  double rotation = 0;
  double? previous;
  int origin = 0;
  int get slots => math.min(7, widget.count);
  double get slice => 2 * math.pi / slots;
  void move(Offset position, double size) {
    final angle = math.atan2(position.dy - size / 2, position.dx - size / 2);
    if (previous != null) {
      var delta = angle - previous!;
      if (delta > math.pi) delta -= 2 * math.pi;
      if (delta < -math.pi) delta += 2 * math.pi;
      setState(() => rotation += delta);
    } else {origin = widget.selected; rotation = 0;}
    previous = angle;
  }
  void snap() {
    final selected = (origin - (rotation / slice).round()) % widget.count;
    setState(() {previous = null; rotation = 0;});
    widget.onChanged(selected);
  }
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, bounds) {
    final size = bounds.maxWidth, radius = size / 2;
    final shift = previous == null ? 0 : (rotation / slice).round();
    final top = previous == null ? widget.selected : (origin - shift) % widget.count;
    final fraction = previous == null ? 0.0 : rotation - shift * slice;
    return Semantics(label: widget.label, value: widget.labels[widget.selected],
      increasedValue: widget.labels[(widget.selected + 1) % widget.count],
      decreasedValue: widget.labels[(widget.selected - 1) % widget.count],
      onIncrease: () => widget.onChanged((widget.selected + 1) % widget.count),
      onDecrease: () => widget.onChanged((widget.selected - 1) % widget.count),
      child: GestureDetector(behavior: HitTestBehavior.opaque,
        onPanStart: (d) => move(d.localPosition, size),
        onPanUpdate: (d) => move(d.localPosition, size),
        onPanEnd: (_) => snap(), onPanCancel: snap,
        child: Stack(children: [
          for (var slot = 0; slot < slots; slot++) ...[
            Positioned.fill(child: ClipPath(clipper: _Wedge(
              -math.pi / 2 + slot * slice + fraction - slice / 2, slice, widget.inner),
              child: GestureDetector(onTap: () => widget.onChanged((top + (slot <= slots ~/ 2 ? slot : slot - slots)) % widget.count),
                child: Stack(fit: StackFit.expand, children: [
                  Positioned(left: radius + math.cos(-math.pi / 2 + slot * slice + fraction) * radius * .77 - size * .3,
                    top: radius + math.sin(-math.pi / 2 + slot * slice + fraction) * radius * .77 - size * .3,
                    width: size * .6, height: size * .6,
                    child: widget.imageBuilder((top + (slot <= slots ~/ 2 ? slot : slot - slots)) % widget.count)),
                  ColoredBox(color: slot == 0 ? const Color(0x18233b29) : const Color(0x55233b29)),
                ])))),
            if (slot == 0) Positioned(top: size * .10, left: size * .30,
              width: size * .40,
              child: IgnorePointer(child: Container(
                decoration: BoxDecoration(color: const Color(0xe6233b29),
                  borderRadius: BorderRadius.circular(7)),
                padding: const EdgeInsets.all(3),
                child: Text(widget.labels[top], maxLines: 2,
                  overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                  textScaler: const TextScaler.linear(1),
                  style: TextStyle(color: _gold, fontSize: size > 240 ? 12 : 8))))),
          ],
          Positioned.fill(child: IgnorePointer(child: CustomPaint(
            painter: _Rings(widget.inner)))),
        ])));
  });
}
class _Wedge extends CustomClipper<Path> {
  const _Wedge(this.angle, this.sweep, this.inner);
  final double angle, sweep, inner;
  @override
  Path getClip(Size size) {
    final center = Offset(size.width / 2, size.height / 2), radius = size.width / 2;
    return Path()
      ..moveTo(center.dx + math.cos(angle) * radius * inner,
        center.dy + math.sin(angle) * radius * inner)
      ..lineTo(center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius)
      ..arcTo(Rect.fromCircle(center: center, radius: radius), angle, sweep, false)
      ..lineTo(center.dx + math.cos(angle + sweep) * radius * inner,
        center.dy + math.sin(angle + sweep) * radius * inner)
      ..arcTo(Rect.fromCircle(center: center, radius: radius * inner),
        angle + sweep, -sweep, false)..close();
  }
  @override
  bool shouldReclip(_Wedge old) => old.angle != angle || old.sweep != sweep || old.inner != inner;
}
class _Rings extends CustomPainter {
  const _Rings(this.inner);
  final double inner;
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..color = _gold..style = PaintingStyle.stroke..strokeWidth = 2;
    canvas.drawCircle(center, size.width / 2 - 2, paint);
    canvas.drawCircle(center, size.width / 2 * inner, paint);
  }
  @override
  bool shouldRepaint(_Rings old) => old.inner != inner;
}
