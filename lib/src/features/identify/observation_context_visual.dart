import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Explicit states and diagrams for observations a generic photo cannot show.
class ObservationContextVisual extends StatelessWidget {
  const ObservationContextVisual({super.key, required this.trait,
    required this.code, required this.label, required this.size, required this.asset});
  final String trait, code, label, asset;
  final double size;
  static bool supports(String trait, String code) =>
    ['uncertain', 'not_applicable', 'mixed_unknown'].contains(code) ||
    ['odour', 'taste', 'spore_shape'].contains(trait);

  @override
  Widget build(BuildContext context) {
    final unknown = ['uncertain', 'mixed_unknown'].contains(code);
    final absent = code == 'not_applicable';
    final icon = unknown ? Icons.help_outline : absent ? Icons.not_interested :
      trait == 'taste' ? Icons.edit_note : switch (code) {
        'none' => Icons.do_not_disturb,
        'earthy' => Icons.landscape,
        'mealy' => Icons.grain,
        'anise' => Icons.star_outline,
        'almond' || 'coconut' => Icons.spa,
        'fruity' || 'apricot' || 'sweet' => Icons.local_grocery_store,
        'radish' || 'garlic' => Icons.grass,
        'phenol' || 'ink' => Icons.science,
        'fishy' || 'shrimp' => Icons.water,
        'rancid' || 'fetid' => Icons.warning_amber,
        _ => Icons.air,
      };
    return Semantics(label: label, image: true, child: SizedBox.square(
      dimension: size, child: DecoratedBox(decoration: BoxDecoration(
        color: const Color(0xfff3eee1), borderRadius: BorderRadius.circular(6)),
        child: LayoutBuilder(builder: (context, bounds) =>
          trait == 'spore_shape' && !unknown
            ? CustomPaint(painter: _SporeOutline(code))
            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Expanded(child: !unknown && !absent && (trait == 'odour' || trait == 'taste')
                ? Image.asset(asset, fit: BoxFit.contain, cacheWidth: 512)
                : FittedBox(fit: BoxFit.scaleDown,
                    child: Icon(icon, color: const Color(0xff385342), size: 72))),
              if (!unknown && !absent) Padding(padding: const EdgeInsets.all(2),
                child: Text(label, maxLines: 2, textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  textScaler: const TextScaler.linear(1),
                  style: TextStyle(color: const Color(0xff203b29),
                    fontSize: math.min(11, bounds.maxWidth * .15)))),
            ])))));
  }
}

/// Shape outlines are schematics, without invented microscopic photographs.
class _SporeOutline extends CustomPainter {
  const _SporeOutline(this.code);
  final String code;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width * .5, size.height * .47);
    canvas.scale(size.width * .72, size.height * .72);
    final paint = Paint()..color = const Color(0xff986b45)
      ..style = PaintingStyle.stroke..strokeWidth = .035;
    final path = Path();
    switch (code) {
      case 'globose':
        path.addOval(const Rect.fromLTWH(-.34, -.34, .68, .68));
      case 'subglobose':
        path.addOval(const Rect.fromLTWH(-.31, -.36, .62, .72));
      case 'ellipsoid':
        path.addOval(const Rect.fromLTWH(-.24, -.42, .48, .84));
      case 'ovoid':
        path.moveTo(0, -.43);
        path.cubicTo(.28, -.42, .38, .40, 0, .42);
        path.cubicTo(-.38, .40, -.28, -.42, 0, -.43);
      case 'elongate':
        path.addOval(const Rect.fromLTWH(-.15, -.45, .30, .90));
      case 'cylindrical':
        path.addRRect(RRect.fromRectAndRadius(
          const Rect.fromLTWH(-.14, -.44, .28, .88), const Radius.circular(.10)));
      case 'fusiform':
        path.moveTo(0, -.46);
        path.quadraticBezierTo(.39, 0, 0, .46);
        path.quadraticBezierTo(-.39, 0, 0, -.46);
      case 'allantoid':
        path.moveTo(-.22, -.39);
        path.cubicTo(.35, -.55, .35, .55, -.22, .39);
        path.quadraticBezierTo(-.35, .30, -.17, .24);
        path.cubicTo(.08, .25, .08, -.25, -.17, -.24);
        path.quadraticBezierTo(-.35, -.30, -.22, -.39);
      case 'reniform':
        path.moveTo(-.25, -.31);
        path.cubicTo(.40, -.60, .40, .60, -.25, .31);
        path.cubicTo(-.46, .12, .08, .12, -.25, -.08);
        path.quadraticBezierTo(-.40, -.20, -.25, -.31);
      case 'angular':
        path.moveTo(0, -.42);
        path.lineTo(.31, -.21);path.lineTo(.32, .22);
        path.lineTo(0, .42);path.lineTo(-.33, .19);
        path.lineTo(-.29, -.23);path.close();
      case 'lemon':
        path.moveTo(0, -.45);
        path.cubicTo(.08, -.30, .27, -.30, .27, 0);
        path.cubicTo(.27, .30, .08, .30, 0, .45);
        path.cubicTo(-.08, .30, -.27, .30, -.27, 0);
        path.cubicTo(-.27, -.30, -.08, -.30, 0, -.45);
    }
    canvas.drawPath(path, paint);
    canvas.restore();
    final caption = TextPainter(text: const TextSpan(text: 'Schema',
      style: TextStyle(color: Color(0xff385342), fontSize: 8)),
      textDirection: TextDirection.ltr)..layout(maxWidth: size.width);
    caption.paint(canvas, Offset((size.width - caption.width) / 2,
      size.height - caption.height - 2));
  }
  @override
  bool shouldRepaint(_SporeOutline old) => old.code != code;
}
