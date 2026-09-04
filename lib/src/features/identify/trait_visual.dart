import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Compact, app-owned visual aid for determination choices.
/// These are schematic character illustrations, not species photographs.
class TraitVisual extends StatelessWidget {
  const TraitVisual({
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
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: optionLabel,
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: CustomPaint(
          painter: _TraitVisualPainter(
            traitCode: traitCode,
            variant: optionId,
            foreground: scheme.onSurfaceVariant,
            accent: scheme.primary,
          ),
        ),
      ),
    );
  }
}

class _TraitVisualPainter extends CustomPainter {
  const _TraitVisualPainter({
    required this.traitCode,
    required this.variant,
    required this.foreground,
    required this.accent,
  });

  final String traitCode;
  final int variant;
  final Color foreground;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = foreground
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = accent.withValues(alpha: .18)
      ..style = PaintingStyle.fill;

    if (traitCode == 'cap_shape') {
      _paintCapShape(canvas, size, stroke, fill);
      return;
    }
    if (traitCode == 'gill_attachment') {
      _paintGillAttachment(canvas, size, stroke, fill);
      return;
    }
    if (traitCode == 'hymenium') {
      _paintHymenium(canvas, size, stroke, fill);
      return;
    }
    if (traitCode == 'stem_base_shape') {
      _paintStemBase(canvas, size, stroke, fill);
      return;
    }
    if (traitCode == 'ring') {
      _paintRing(canvas, size, stroke, fill);
      return;
    }
    if (traitCode == 'volva') {
      _paintVolva(canvas, size, stroke, fill);
      return;
    }

    final c = Offset(size.width / 2, size.height / 2);
    final w = size.width;
    final h = size.height;
    if (traitCode.contains('color') || traitCode.contains('colour')) {
      final hue = ((variant * 47) % 360).toDouble();
      canvas.drawCircle(
        c,
        w * .25,
        Paint()..color = HSVColor.fromAHSV(1, hue, .55, .72).toColor(),
      );
      canvas.drawCircle(c, w * .25, stroke);
      return;
    }
    if (traitCode.contains('spore_print')) {
      canvas.drawOval(
        Rect.fromCenter(center: c, width: w * .58, height: h * .34),
        fill,
      );
      for (var i = 0; i < 9; i++) {
        canvas.drawCircle(
          Offset(w * (.25 + (i % 3) * .25), h * (.32 + (i ~/ 3) * .18)),
          2.2,
          Paint()..color = foreground.withValues(alpha: .65),
        );
      }
      return;
    }
    if (traitCode.contains('gill')) {
      _paintGillAttachment(canvas, size, stroke, fill);
      return;
    }
    if (traitCode.contains('ring')) {
      _paintRing(canvas, size, stroke, fill);
      return;
    }
    if (traitCode.contains('volva') || traitCode.contains('base')) {
      _paintVolva(canvas, size, stroke, fill);
      return;
    }
    if (traitCode.contains('surface')) {
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(w * .2, h * .18, w * .6, h * .64),
        const Radius.circular(14),
      );
      canvas.drawRRect(r, fill);
      canvas.drawRRect(r, stroke);
      for (var i = 0; i < 6; i++) {
        final y = h * (.27 + i * .085);
        canvas.drawLine(
          Offset(w * .3, y),
          Offset(w * .7, y + (i.isEven ? 3 : -3)),
          stroke,
        );
      }
      return;
    }
    if (traitCode.contains('habitat') || traitCode.contains('substrate')) {
      canvas.drawLine(Offset(w * .15, h * .75), Offset(w * .85, h * .75), stroke);
      canvas.drawLine(Offset(c.dx, h * .72), Offset(c.dx, h * .3), stroke);
      canvas.drawCircle(Offset(c.dx, h * .25), w * .17, fill);
      canvas.drawCircle(Offset(c.dx, h * .25), w * .17, stroke);
      return;
    }
    if (traitCode.contains('growth') || traitCode.contains('fruitbody')) {
      for (var i = 0; i < 3; i++) {
        _mushroom(
          canvas,
          Offset(w * (.3 + i * .2), h * .58),
          w * (.16 + i * .01),
          stroke,
          fill,
          i,
        );
      }
      return;
    }
    _mushroom(canvas, c, w * .5, stroke, fill, variant);
  }

  void _paintCapShape(Canvas canvas, Size size, Paint stroke, Paint fill) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final baseY = h * .58;
    final left = w * .18;
    final right = w * .82;
    final path = Path()..moveTo(left, baseY);

    switch (variant) {
      case 45: // conical
        path.lineTo(cx, h * .18)..lineTo(right, baseY);
      case 46: // bell-shaped
        path
          ..cubicTo(w * .31, h * .5, w * .35, h * .18, cx, h * .16)
          ..cubicTo(w * .65, h * .18, w * .69, h * .5, right, baseY);
      case 47: // depressed
        path
          ..cubicTo(w * .3, h * .34, w * .42, h * .42, cx, h * .44)
          ..cubicTo(w * .58, h * .42, w * .7, h * .34, right, baseY);
      case 48: // funnel
        path
          ..cubicTo(w * .33, h * .37, w * .42, h * .47, cx, h * .55)
          ..cubicTo(w * .58, h * .47, w * .67, h * .37, right, baseY);
      case 49: // umbonate
        path
          ..cubicTo(w * .3, h * .38, w * .4, h * .34, w * .45, h * .35)
          ..quadraticBezierTo(cx, h * .18, w * .55, h * .35)
          ..cubicTo(w * .6, h * .34, w * .7, h * .38, right, baseY);
      case 50: // irregular
        path
          ..cubicTo(w * .27, h * .36, w * .35, h * .48, w * .44, h * .35)
          ..cubicTo(w * .5, h * .25, w * .55, h * .5, w * .63, h * .34)
          ..cubicTo(w * .7, h * .24, w * .76, h * .44, right, baseY);
      case 51: // bracket/fan
        path
          ..cubicTo(w * .28, h * .34, w * .53, h * .24, right, h * .34)
          ..quadraticBezierTo(w * .72, h * .55, left, baseY);
      case 44: // hemispherical
        path.quadraticBezierTo(cx, h * .12, right, baseY);
      case 11: // broadly convex
        path.quadraticBezierTo(cx, h * .28, right, baseY);
      case 10: // convex to flat
      default:
        path
          ..quadraticBezierTo(cx, h * .32, right, baseY)
          ..quadraticBezierTo(cx, h * .54, left, baseY);
    }
    path.close();
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
    if (variant != 51) {
      final stem = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, h * .72),
          width: w * .16,
          height: h * .34,
        ),
        Radius.circular(w * .04),
      );
      canvas.drawRRect(stem, fill);
      canvas.drawRRect(stem, stroke);
    }
  }

  void _paintGillAttachment(Canvas canvas, Size size, Paint stroke, Paint fill) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final stemLeft = w * .45;
    final stemRight = w * .55;
    final capY = h * .27;
    final attachY = h * .46;
    canvas.drawPath(
      Path()
        ..moveTo(w * .14, attachY)
        ..quadraticBezierTo(cx, capY, w * .86, attachY),
      stroke,
    );
    canvas.drawRect(
      Rect.fromLTRB(stemLeft, attachY, stemRight, h * .86),
      fill,
    );
    canvas.drawRect(
      Rect.fromLTRB(stemLeft, attachY, stemRight, h * .86),
      stroke,
    );
    if (variant == 15) {
      canvas.drawLine(Offset(w * .2, h * .67), Offset(w * .8, h * .67), stroke);
      return;
    }

    Path gill(double x, bool leftSide) {
      final side = leftSide ? -1.0 : 1.0;
      final startX = cx + side * x;
      final path = Path()..moveTo(startX, attachY);
      switch (variant) {
        case 14: // free
          path.lineTo(cx + side * w * .08, h * .58);
        case 59: // adnexed
          path.quadraticBezierTo(
            cx + side * w * .05,
            h * .5,
            cx + side * w * .035,
            h * .58,
          );
        case 60: // adnate
          path.lineTo(cx + side * w * .01, h * .58);
        case 61: // sinuate
          path
            ..quadraticBezierTo(
              cx + side * w * .11,
              h * .54,
              cx + side * w * .04,
              h * .57,
            )
            ..quadraticBezierTo(
              cx + side * w * .02,
              h * .59,
              cx + side * w * .01,
              h * .6,
            );
        case 62: // decurrent
          path
            ..quadraticBezierTo(
              cx + side * w * .02,
              h * .52,
              cx + side * w * .02,
              h * .66,
            )
            ..lineTo(cx + side * w * .04, h * .72);
        default:
          path.lineTo(cx + side * w * .04, h * .58);
      }
      return path;
    }

    for (var i = 0; i < 4; i++) {
      final x = w * (.17 + i * .07);
      canvas.drawPath(gill(x, true), stroke);
      canvas.drawPath(gill(x, false), stroke);
    }
  }

  void _paintHymenium(Canvas canvas, Size size, Paint stroke, Paint fill) {
    final w = size.width;
    final h = size.height;
    final top = h * .24;
    final bottom = h * .68;
    final rect = Rect.fromLTWH(w * .16, top, w * .68, bottom - top);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(w * .08)),
      fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(w * .08)),
      stroke,
    );
    switch (variant) {
      case 4: // gills
        for (var i = 0; i < 7; i++) {
          final x = w * (.23 + i * .09);
          canvas.drawLine(Offset(x, top + 4), Offset(x, bottom - 4), stroke);
        }
      case 5: // pores
        for (var row = 0; row < 3; row++) {
          for (var col = 0; col < 5; col++) {
            canvas.drawCircle(
              Offset(w * (.27 + col * .115), h * (.34 + row * .12)),
              w * .025,
              stroke,
            );
          }
        }
      case 38: // teeth/spines
        for (var i = 0; i < 8; i++) {
          final x = w * (.22 + i * .08);
          canvas.drawLine(
            Offset(x, h * .42),
            Offset(x + (i.isEven ? -2 : 2), h * .62),
            stroke,
          );
        }
      case 39: // ridges/folds
        for (var i = 0; i < 5; i++) {
          final y = h * (.34 + i * .075);
          final p = Path()
            ..moveTo(w * .23, y)
            ..cubicTo(w * .36, y - 5, w * .54, y + 5, w * .77, y);
          canvas.drawPath(p, stroke);
        }
      case 40: // smooth
        canvas.drawLine(Offset(w * .28, h * .47), Offset(w * .72, h * .47), stroke);
      case 41: // enclosed
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(w * .5, h * .47),
            width: w * .42,
            height: h * .24,
          ),
          stroke,
        );
    }
  }

  void _paintStemBase(Canvas canvas, Size size, Paint stroke, Paint fill) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final stemTop = h * .15;
    final stemBottom = h * .7;
    final stemPath = Path()..moveTo(w * .44, stemTop);
    switch (variant) {
      case 16: // bulbous
        stemPath
          ..lineTo(w * .44, h * .55)
          ..cubicTo(w * .42, h * .66, w * .31, h * .74, w * .28, stemBottom)
          ..quadraticBezierTo(cx, h * .9, w * .72, stemBottom)
          ..cubicTo(w * .69, h * .74, w * .58, h * .66, w * .56, h * .55)
          ..lineTo(w * .56, stemTop);
      case 17: // sack-like volva
        stemPath
          ..lineTo(w * .44, h * .68)
          ..lineTo(w * .31, h * .62)
          ..quadraticBezierTo(cx, h * .92, w * .69, h * .62)
          ..lineTo(w * .56, h * .68)
          ..lineTo(w * .56, stemTop);
      case 18: // club/barrel
        stemPath
          ..lineTo(w * .39, h * .66)
          ..quadraticBezierTo(cx, h * .84, w * .61, h * .66)
          ..lineTo(w * .56, stemTop);
      case 63: // tapered
        stemPath
          ..lineTo(w * .48, stemBottom)
          ..lineTo(w * .52, stemBottom)
          ..lineTo(w * .56, stemTop);
      case 64: // rooting
        stemPath
          ..lineTo(w * .45, h * .65)
          ..quadraticBezierTo(cx, h * .8, w * .49, h * .92)
          ..quadraticBezierTo(cx, h * .97, w * .51, h * .92)
          ..quadraticBezierTo(cx, h * .8, w * .55, h * .65)
          ..lineTo(w * .56, stemTop);
      case 65: // equal/cylindrical
      default:
        stemPath
          ..lineTo(w * .44, stemBottom)
          ..lineTo(w * .56, stemBottom)
          ..lineTo(w * .56, stemTop);
    }
    stemPath.close();
    canvas.drawPath(stemPath, fill);
    canvas.drawPath(stemPath, stroke);
  }

  void _paintRing(Canvas canvas, Size size, Paint stroke, Paint fill) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    canvas.drawLine(Offset(cx, h * .15), Offset(cx, h * .84), stroke);
    if (variant == 7) return;
    if (variant == 42) {
      stroke = Paint()
        ..color = stroke.color.withValues(alpha: .55)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
    }
    final r = Rect.fromCenter(
      center: Offset(cx, h * .48),
      width: w * .5,
      height: h * .14,
    );
    canvas.drawOval(r, fill);
    canvas.drawOval(r, stroke);
    canvas.drawLine(Offset(cx, h * .49), Offset(cx, h * .62), stroke);
  }

  void _paintVolva(Canvas canvas, Size size, Paint stroke, Paint fill) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    canvas.drawLine(Offset(cx, h * .14), Offset(cx, h * .7), stroke);
    if (variant == 9) return;
    final path = Path()
      ..moveTo(w * .25, h * .61)
      ..quadraticBezierTo(w * .29, h * .82, cx, h * .88)
      ..quadraticBezierTo(w * .71, h * .82, w * .75, h * .61);
    if (variant == 43) {
      final faint = Paint()
        ..color = stroke.color.withValues(alpha: .5)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas.drawPath(path, faint);
    } else {
      canvas.drawPath(path, fill);
      canvas.drawPath(path, stroke);
    }
  }

  void _mushroom(
    Canvas canvas,
    Offset c,
    double width,
    Paint stroke,
    Paint fill,
    int v,
  ) {
    final stemTop = c.dy - width * .05;
    final stem = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(c.dx, c.dy + width * .2),
        width: width * .18,
        height: width * .62,
      ),
      Radius.circular(width * .07),
    );
    canvas.drawRRect(stem, fill);
    canvas.drawRRect(stem, stroke);
    final cap = Path()
      ..moveTo(c.dx - width * .48, stemTop)
      ..quadraticBezierTo(
        c.dx,
        stemTop - width * (.42 + (v % 4) * .06),
        c.dx + width * .48,
        stemTop,
      )
      ..quadraticBezierTo(
        c.dx,
        stemTop + width * .14,
        c.dx - width * .48,
        stemTop,
      )
      ..close();
    canvas.drawPath(cap, fill);
    canvas.drawPath(cap, stroke);
  }

  @override
  bool shouldRepaint(covariant _TraitVisualPainter oldDelegate) =>
      oldDelegate.traitCode != traitCode ||
      oldDelegate.variant != variant ||
      oldDelegate.foreground != foreground ||
      oldDelegate.accent != accent;
}
