import 'package:flutter/material.dart';

import 'trait_visual.dart';

/// Routes determination options to explicit, app-owned schematic drawings when
/// the bundled trait vocabulary defines a visual family we can represent
/// unambiguously. Other traits keep using the established generic/specialized
/// [TraitVisual] implementation.
class DeterminationOptionVisual extends StatelessWidget {
  const DeterminationOptionVisual({
    super.key,
    required this.traitCode,
    required this.optionId,
    required this.optionLabel,
    this.size = 72,
  });

  final String traitCode;
  final int optionId;
  final String optionLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    const explicitTraits = {'gill_spacing', 'stem_surface', 'ring', 'volva'};
    if (!explicitTraits.contains(traitCode)) {
      return TraitVisual(
        traitCode: traitCode,
        optionId: optionId,
        optionLabel: optionLabel,
        size: size,
      );
    }

    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: optionLabel,
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: CustomPaint(
            painter: _ExplicitTraitPainter(
              traitCode: traitCode,
              optionId: optionId,
              foreground: scheme.onSurfaceVariant,
              accent: scheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ExplicitTraitPainter extends CustomPainter {
  const _ExplicitTraitPainter({
    required this.traitCode,
    required this.optionId,
    required this.foreground,
    required this.accent,
  });

  final String traitCode;
  final int optionId;
  final Color foreground;
  final Color accent;

  Paint stroke([double alpha = 1]) => Paint()
    ..color = foreground.withValues(alpha: alpha)
    ..strokeWidth = 2
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  Paint get fill => Paint()
    ..color = accent.withValues(alpha: .18)
    ..style = PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {
    switch (traitCode) {
      case 'gill_spacing':
        _gillSpacing(canvas, size);
      case 'stem_surface':
        _stemSurface(canvas, size);
      case 'ring':
        _ring(canvas, size);
      case 'volva':
        _volva(canvas, size);
    }
  }

  void _stemOutline(Canvas canvas, Size s) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s.width * .43, s.height * .14, s.width * .14, s.height * .7),
        Radius.circular(s.width * .04),
      ),
      stroke(),
    );
  }

  void _ring(Canvas canvas, Size s) {
    _stemOutline(canvas, s);
    if (optionId == 7) return; // absent
    if (optionId == 42) { // uncertain / traces
      canvas.drawArc(
        Rect.fromLTWH(s.width * .29, s.height * .38, s.width * .42, s.height * .18),
        0,
        2.2,
        false,
        stroke(.5),
      );
      return;
    }
    if (optionId == 6) { // present
      canvas.drawOval(
        Rect.fromLTWH(s.width * .27, s.height * .37, s.width * .46, s.height * .2),
        fill,
      );
      canvas.drawOval(
        Rect.fromLTWH(s.width * .27, s.height * .37, s.width * .46, s.height * .2),
        stroke(),
      );
      return;
    }
    canvas.drawLine(Offset(s.width * .4, s.height * .5), Offset(s.width * .6, s.height * .5), stroke(.45));
  }

  void _volva(Canvas canvas, Size s) {
    _stemOutline(canvas, s);
    if (optionId == 9) return; // absent
    final base = Path()
      ..moveTo(s.width * .28, s.height * .68)
      ..quadraticBezierTo(s.width * .31, s.height * .9, s.width * .5, s.height * .88)
      ..quadraticBezierTo(s.width * .69, s.height * .9, s.width * .72, s.height * .68);
    if (optionId == 8) { // present
      canvas.drawPath(base, stroke());
      return;
    }
    if (optionId == 43) { // uncertain / possible remnants
      canvas.drawPath(base, stroke(.5));
      canvas.drawCircle(Offset(s.width * .32, s.height * .72), s.width * .025, stroke(.45));
      canvas.drawCircle(Offset(s.width * .68, s.height * .75), s.width * .02, stroke(.45));
      return;
    }
    canvas.drawLine(Offset(s.width * .4, s.height * .78), Offset(s.width * .6, s.height * .78), stroke(.45));
  }

  void _gillSpacing(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final top = h * .3;
    final bottom = h * .72;
    canvas.drawPath(Path()..moveTo(w * .12, top)..quadraticBezierTo(w * .5, h * .16, w * .88, top), stroke());
    if (optionId == 96) {
      canvas.drawLine(Offset(w * .25, h * .68), Offset(w * .75, h * .42), stroke(.55));
      return;
    }
    final count = switch (optionId) {93 => 11, 94 => 7, 95 => 4, _ => 6};
    final left = w * .2;
    final right = w * .8;
    final step = count == 1 ? 0.0 : (right - left) / (count - 1);
    for (var i = 0; i < count; i++) {
      final x = left + step * i;
      canvas.drawLine(Offset(x, top + h * .03), Offset(x, bottom), stroke());
    }
  }

  void _stemSurface(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final stem = RRect.fromRectAndRadius(Rect.fromLTWH(w * .32, h * .12, w * .36, h * .76), Radius.circular(w * .08));
    canvas.drawRRect(stem, fill);
    canvas.drawRRect(stem, stroke());
    switch (optionId) {
      case 108:
        return;
      case 109:
        for (var i = 0; i < 5; i++) {
          final x = w * (.39 + i * .055);
          canvas.drawLine(Offset(x, h * .2), Offset(x, h * .8), stroke(.7));
        }
        return;
      case 110:
        for (var row = 0; row < 4; row++) {
          for (var col = 0; col < 2; col++) {
            final x = w * (.4 + col * .16), y = h * (.25 + row * .15);
            canvas.drawPath(Path()..moveTo(x - w * .045, y)..lineTo(x, y + h * .045)..lineTo(x + w * .045, y), stroke(.75));
          }
        }
        return;
      case 111:
        for (var i = 0; i < 4; i++) {
          final x = w * (.39 + i * .075);
          canvas.drawLine(Offset(x, h * .2), Offset(x, h * .8), stroke(.7));
        }
        for (var i = 0; i < 5; i++) {
          final y = h * (.24 + i * .12);
          canvas.drawLine(Offset(w * .36, y), Offset(w * .64, y), stroke(.7));
        }
        return;
      case 112:
        for (var i = 0; i < 4; i++) {
          final y = h * (.25 + i * .15);
          canvas.drawPath(Path()..moveTo(w * .38, y)..lineTo(w * .47, y + h * .045)..lineTo(w * .57, y - h * .025)..lineTo(w * .63, y + h * .02), stroke(.7));
        }
        return;
      case 113:
        for (var i = 0; i < 5; i++) {
          final y = h * (.22 + i * .14);
          canvas.drawLine(Offset(w * .35, y), Offset(w * .27, y + h * .035), stroke(.75));
          canvas.drawLine(Offset(w * .65, y + h * .035), Offset(w * .73, y), stroke(.75));
        }
        return;
      case 114:
        for (var row = 0; row < 5; row++) {
          for (var col = 0; col < 3; col++) {
            canvas.drawCircle(Offset(w * (.4 + col * .1), h * (.23 + row * .13)), w * .018, Paint()..color = foreground.withValues(alpha: .75));
          }
        }
        return;
      default:
        canvas.drawLine(Offset(w * .4, h * .5), Offset(w * .6, h * .5), stroke(.45));
    }
  }

  @override
  bool shouldRepaint(covariant _ExplicitTraitPainter oldDelegate) =>
      oldDelegate.traitCode != traitCode || oldDelegate.optionId != optionId || oldDelegate.foreground != foreground || oldDelegate.accent != accent;
}
