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

  Paint _stroke([double alpha = 1]) => Paint()
    ..color = foreground.withValues(alpha: alpha)
    ..strokeWidth = 2
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  Paint get _fill => Paint()
    ..color = accent.withValues(alpha: .18)
    ..style = PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {
    if (traitCode == 'cap_shape') {
      _paintCapShape(canvas, size);
      return;
    }
    if (traitCode == 'gill_attachment') {
      _paintGillAttachment(canvas, size);
      return;
    }
    if (traitCode == 'hymenium') {
      _paintHymenium(canvas, size);
      return;
    }
    if (traitCode == 'stem_base_shape') {
      _paintStemBase(canvas, size);
      return;
    }
    if (traitCode == 'ring') {
      _paintRing(canvas, size);
      return;
    }
    if (traitCode == 'volva') {
      _paintVolva(canvas, size);
      return;
    }
    _paintGeneric(canvas, size);
  }

  void _paintCapShape(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final baseY = h * .58;
    final left = w * .18;
    final right = w * .82;
    final path = Path()..moveTo(left, baseY);

    if (variant == 45) {
      path..lineTo(cx, h * .18)..lineTo(right, baseY);
    } else if (variant == 46) {
      path
        ..cubicTo(w * .31, h * .5, w * .35, h * .18, cx, h * .16)
        ..cubicTo(w * .65, h * .18, w * .69, h * .5, right, baseY);
    } else if (variant == 47) {
      path
        ..cubicTo(w * .3, h * .34, w * .42, h * .42, cx, h * .44)
        ..cubicTo(w * .58, h * .42, w * .7, h * .34, right, baseY);
    } else if (variant == 48) {
      path
        ..cubicTo(w * .33, h * .37, w * .42, h * .47, cx, h * .55)
        ..cubicTo(w * .58, h * .47, w * .67, h * .37, right, baseY);
    } else if (variant == 49) {
      path
        ..cubicTo(w * .3, h * .38, w * .4, h * .34, w * .45, h * .35)
        ..quadraticBezierTo(cx, h * .18, w * .55, h * .35)
        ..cubicTo(w * .6, h * .34, w * .7, h * .38, right, baseY);
    } else if (variant == 50) {
      path
        ..cubicTo(w * .27, h * .36, w * .35, h * .48, w * .44, h * .35)
        ..cubicTo(w * .5, h * .25, w * .55, h * .5, w * .63, h * .34)
        ..cubicTo(w * .7, h * .24, w * .76, h * .44, right, baseY);
    } else if (variant == 51) {
      path
        ..cubicTo(w * .28, h * .34, w * .53, h * .24, right, h * .34)
        ..quadraticBezierTo(w * .72, h * .55, left, baseY);
    } else if (variant == 44) {
      path.quadraticBezierTo(cx, h * .12, right, baseY);
    } else if (variant == 11) {
      path.quadraticBezierTo(cx, h * .28, right, baseY);
    } else {
      path
        ..quadraticBezierTo(cx, h * .32, right, baseY)
        ..quadraticBezierTo(cx, h * .54, left, baseY);
    }
    path.close();
    canvas.drawPath(path, _fill);
    canvas.drawPath(path, _stroke());

    if (variant != 51) {
      final stem = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, h * .72),
          width: w * .16,
          height: h * .34,
        ),
        Radius.circular(w * .04),
      );
      canvas.drawRRect(stem, _fill);
      canvas.drawRRect(stem, _stroke());
    }
  }

  void _paintGillAttachment(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final attachY = h * .46;
    canvas.drawPath(
      Path()
        ..moveTo(w * .14, attachY)
        ..quadraticBezierTo(cx, h * .27, w * .86, attachY),
      _stroke(),
    );
    canvas.drawRect(
      Rect.fromLTRB(w * .45, attachY, w * .55, h * .86),
      _fill,
    );
    canvas.drawRect(
      Rect.fromLTRB(w * .45, attachY, w * .55, h * .86),
      _stroke(),
    );
    if (variant == 15) {
      canvas.drawLine(
        Offset(w * .2, h * .67),
        Offset(w * .8, h * .67),
        _stroke(.55),
      );
      return;
    }
    for (var i = 0; i < 4; i++) {
      final x = w * (.17 + i * .07);
      canvas.drawPath(_gillPath(size, x, true), _stroke());
      canvas.drawPath(_gillPath(size, x, false), _stroke());
    }
  }

  Path _gillPath(Size size, double x, bool leftSide) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final side = leftSide ? -1.0 : 1.0;
    final attachY = h * .46;
    final path = Path()..moveTo(cx + side * x, attachY);
    if (variant == 14) {
      path.lineTo(cx + side * w * .08, h * .58);
    } else if (variant == 59) {
      path.quadraticBezierTo(
        cx + side * w * .05,
        h * .5,
        cx + side * w * .035,
        h * .58,
      );
    } else if (variant == 60) {
      path.lineTo(cx + side * w * .01, h * .58);
    } else if (variant == 61) {
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
    } else if (variant == 62) {
      path
        ..quadraticBezierTo(
          cx + side * w * .02,
          h * .52,
          cx + side * w * .02,
          h * .66,
        )
        ..lineTo(cx + side * w * .04, h * .72);
    } else {
      path.lineTo(cx + side * w * .04, h * .58);
    }
    return path;
  }

  void _paintHymenium(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Rect.fromLTWH(w * .16, h * .24, w * .68, h * .44);
    final panel = RRect.fromRectAndRadius(rect, Radius.circular(w * .08));
    canvas.drawRRect(panel, _fill);
    canvas.drawRRect(panel, _stroke());

    if (variant == 4) {
      for (var i = 0; i < 7; i++) {
        final x = w * (.23 + i * .09);
        canvas.drawLine(Offset(x, h * .28), Offset(x, h * .64), _stroke());
      }
    } else if (variant == 5) {
      for (var row = 0; row < 3; row++) {
        for (var col = 0; col < 5; col++) {
          canvas.drawCircle(
            Offset(w * (.27 + col * .115), h * (.34 + row * .12)),
            w * .025,
            _stroke(),
          );
        }
      }
    } else if (variant == 38) {
      for (var i = 0; i < 8; i++) {
        final x = w * (.22 + i * .08);
        canvas.drawLine(
          Offset(x, h * .38),
          Offset(x + (i.isEven ? -2 : 2), h * .62),
          _stroke(),
        );
      }
    } else if (variant == 39) {
      for (var i = 0; i < 5; i++) {
        final y = h * (.34 + i * .075);
        canvas.drawPath(
          Path()
            ..moveTo(w * .23, y)
            ..cubicTo(w * .36, y - 5, w * .54, y + 5, w * .77, y),
          _stroke(),
        );
      }
    } else if (variant == 40) {
      canvas.drawLine(
        Offset(w * .28, h * .47),
        Offset(w * .72, h * .47),
        _stroke(),
      );
    } else if (variant == 41) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(w * .5, h * .47),
          width: w * .42,
          height: h * .24,
        ),
        _stroke(),
      );
    }
  }

  void _paintStemBase(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final p = Path()..moveTo(w * .44, h * .15);
    if (variant == 16) {
      p
        ..lineTo(w * .44, h * .55)
        ..cubicTo(w * .42, h * .66, w * .31, h * .74, w * .28, h * .7)
        ..quadraticBezierTo(cx, h * .9, w * .72, h * .7)
        ..cubicTo(w * .69, h * .74, w * .58, h * .66, w * .56, h * .55)
        ..lineTo(w * .56, h * .15);
    } else if (variant == 17) {
      p
        ..lineTo(w * .44, h * .68)
        ..lineTo(w * .31, h * .62)
        ..quadraticBezierTo(cx, h * .92, w * .69, h * .62)
        ..lineTo(w * .56, h * .68)
        ..lineTo(w * .56, h * .15);
    } else if (variant == 18) {
      p
        ..lineTo(w * .39, h * .66)
        ..quadraticBezierTo(cx, h * .84, w * .61, h * .66)
        ..lineTo(w * .56, h * .15);
    } else if (variant == 63) {
      p
        ..lineTo(w * .48, h * .7)
        ..lineTo(w * .52, h * .7)
        ..lineTo(w * .56, h * .15);
    } else if (variant == 64) {
      p
        ..lineTo(w * .45, h * .65)
        ..quadraticBezierTo(cx, h * .8, w * .49, h * .92)
        ..quadraticBezierTo(cx, h * .97, w * .51, h * .92)
        ..quadraticBezierTo(cx, h * .8, w * .55, h * .65)
        ..lineTo(w * .56, h * .15);
    } else {
      p
        ..lineTo(w * .44, h * .7)
        ..lineTo(w * .56, h * .7)
        ..lineTo(w * .56, h * .15);
    }
    p.close();
    canvas.drawPath(p, _fill);
    canvas.drawPath(p, _stroke());
  }

  void _paintRing(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    canvas.drawLine(Offset(cx, h * .15), Offset(cx, h * .84), _stroke());
    if (variant == 7) return;
    final alpha = variant == 42 ? .5 : 1.0;
    final ring = Rect.fromCenter(
      center: Offset(cx, h * .48),
      width: w * .5,
      height: h * .14,
    );
    canvas.drawOval(ring, _fill);
    canvas.drawOval(ring, _stroke(alpha));
    canvas.drawLine(
      Offset(cx, h * .49),
      Offset(cx, h * .62),
      _stroke(alpha),
    );
  }

  void _paintVolva(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    canvas.drawLine(Offset(cx, h * .14), Offset(cx, h * .7), _stroke());
    if (variant == 9) return;
    final p = Path()
      ..moveTo(w * .25, h * .61)
      ..quadraticBezierTo(w * .29, h * .82, cx, h * .88)
      ..quadraticBezierTo(w * .71, h * .82, w * .75, h * .61);
    canvas.drawPath(p, _fill);
    canvas.drawPath(p, _stroke(variant == 43 ? .5 : 1));
  }

  void _paintGeneric(Canvas canvas, Size size) {
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
      canvas.drawCircle(c, w * .25, _stroke());
      return;
    }
    if (traitCode.contains('spore_print')) {
      canvas.drawOval(
        Rect.fromCenter(center: c, width: w * .58, height: h * .34),
        _fill,
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
    if (traitCode.contains('surface')) {
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(w * .2, h * .18, w * .6, h * .64),
        const Radius.circular(14),
      );
      canvas.drawRRect(r, _fill);
      canvas.drawRRect(r, _stroke());
      for (var i = 0; i < 6; i++) {
        final y = h * (.27 + i * .085);
        canvas.drawLine(
          Offset(w * .3, y),
          Offset(w * .7, y + (i.isEven ? 3 : -3)),
          _stroke(),
        );
      }
      return;
    }
    if (traitCode.contains('habitat') || traitCode.contains('substrate')) {
      canvas.drawLine(Offset(w * .15, h * .75), Offset(w * .85, h * .75), _stroke());
      canvas.drawLine(Offset(c.dx, h * .72), Offset(c.dx, h * .3), _stroke());
      canvas.drawCircle(Offset(c.dx, h * .25), w * .17, _fill);
      canvas.drawCircle(Offset(c.dx, h * .25), w * .17, _stroke());
      return;
    }
    if (traitCode.contains('growth') || traitCode.contains('fruitbody')) {
      for (var i = 0; i < 3; i++) {
        _mushroom(
          canvas,
          Offset(w * (.3 + i * .2), h * .58),
          w * (.16 + i * .01),
          i,
        );
      }
      return;
    }
    _mushroom(canvas, c, w * .5, variant);
  }

  void _mushroom(Canvas canvas, Offset c, double width, int v) {
    final stemTop = c.dy - width * .05;
    final stem = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(c.dx, c.dy + width * .2),
        width: width * .18,
        height: width * .62,
      ),
      Radius.circular(width * .07),
    );
    canvas.drawRRect(stem, _fill);
    canvas.drawRRect(stem, _stroke());
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
    canvas.drawPath(cap, _fill);
    canvas.drawPath(cap, _stroke());
  }

  @override
  bool shouldRepaint(covariant _TraitVisualPainter oldDelegate) =>
      oldDelegate.traitCode != traitCode ||
      oldDelegate.variant != variant ||
      oldDelegate.foreground != foreground ||
      oldDelegate.accent != accent;
}
