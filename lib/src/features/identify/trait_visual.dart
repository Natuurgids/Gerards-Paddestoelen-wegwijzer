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
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: CustomPaint(
            painter: _TraitVisualPainter(
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

class _TraitVisualPainter extends CustomPainter {
  const _TraitVisualPainter({
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
      case 'cap_shape':
        _capShape(canvas, size);
        return;
      case 'gill_attachment':
        _gillAttachment(canvas, size);
        return;
      case 'hymenium':
        _hymenium(canvas, size);
        return;
      case 'stem_base_shape':
        _stemBase(canvas, size);
        return;
      case 'ring':
        _ring(canvas, size);
        return;
      case 'volva':
        _volva(canvas, size);
        return;
      default:
        _generic(canvas, size);
    }
  }

  void _capShape(Canvas canvas, Size s) {
    final w = s.width, h = s.height, cx = w / 2;
    final left = w * .15, right = w * .85, y = h * .58;
    final p = Path()..moveTo(left, y);

    if (optionId == 45) {
      p..lineTo(cx, h * .16)..lineTo(right, y);
    } else if (optionId == 46) {
      p
        ..cubicTo(w * .3, h * .48, w * .36, h * .17, cx, h * .15)
        ..cubicTo(w * .64, h * .17, w * .7, h * .48, right, y);
    } else if (optionId == 47) {
      p
        ..cubicTo(w * .3, h * .34, w * .42, h * .43, cx, h * .45)
        ..cubicTo(w * .58, h * .43, w * .7, h * .34, right, y);
    } else if (optionId == 48) {
      p
        ..cubicTo(w * .3, h * .32, w * .42, h * .5, cx, h * .57)
        ..cubicTo(w * .58, h * .5, w * .7, h * .32, right, y);
    } else if (optionId == 49) {
      p
        ..cubicTo(w * .3, h * .36, w * .4, h * .34, w * .45, h * .35)
        ..quadraticBezierTo(cx, h * .17, w * .55, h * .35)
        ..cubicTo(w * .6, h * .34, w * .7, h * .36, right, y);
    } else if (optionId == 50) {
      p
        ..cubicTo(w * .27, h * .36, w * .35, h * .48, w * .44, h * .35)
        ..cubicTo(w * .52, h * .22, w * .58, h * .49, w * .67, h * .33)
        ..cubicTo(w * .74, h * .25, w * .78, h * .45, right, y);
    } else if (optionId == 51) {
      p
        ..cubicTo(w * .28, h * .33, w * .58, h * .2, right, h * .34)
        ..quadraticBezierTo(w * .72, h * .57, left, y);
    } else if (optionId == 44) {
      p.quadraticBezierTo(cx, h * .1, right, y);
    } else if (optionId == 11) {
      p.quadraticBezierTo(cx, h * .26, right, y);
    } else {
      p
        ..quadraticBezierTo(cx, h * .31, right, y)
        ..quadraticBezierTo(cx, h * .54, left, y);
    }
    p.close();
    canvas.drawPath(p, fill);
    canvas.drawPath(p, stroke());

    if (optionId != 51) {
      final stem = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, h * .73),
          width: w * .16,
          height: h * .34,
        ),
        Radius.circular(w * .04),
      );
      canvas.drawRRect(stem, fill);
      canvas.drawRRect(stem, stroke());
    }
  }

  void _gillAttachment(Canvas canvas, Size s) {
    final w = s.width, h = s.height, cx = w / 2, y = h * .43;
    canvas.drawPath(
      Path()
        ..moveTo(w * .12, y)
        ..quadraticBezierTo(cx, h * .24, w * .88, y),
      stroke(),
    );
    canvas.drawRect(Rect.fromLTRB(w * .45, y, w * .55, h * .86), fill);
    canvas.drawRect(Rect.fromLTRB(w * .45, y, w * .55, h * .86), stroke());

    if (optionId == 15) {
      canvas.drawLine(Offset(w * .2, h * .64), Offset(w * .8, h * .64), stroke(.45));
      return;
    }

    for (var i = 0; i < 4; i++) {
      final d = w * (.17 + i * .07);
      for (final side in const [-1.0, 1.0]) {
        final p = Path()..moveTo(cx + side * d, y);
        if (optionId == 14) {
          p.lineTo(cx + side * w * .08, h * .57);
        } else if (optionId == 59) {
          p.quadraticBezierTo(
            cx + side * w * .05,
            h * .5,
            cx + side * w * .035,
            h * .57,
          );
        } else if (optionId == 60) {
          p.lineTo(cx + side * w * .01, h * .57);
        } else if (optionId == 61) {
          p
            ..quadraticBezierTo(
              cx + side * w * .11,
              h * .51,
              cx + side * w * .04,
              h * .55,
            )
            ..quadraticBezierTo(
              cx + side * w * .02,
              h * .59,
              cx + side * w * .01,
              h * .6,
            );
        } else if (optionId == 62) {
          p
            ..quadraticBezierTo(
              cx + side * w * .02,
              h * .52,
              cx + side * w * .02,
              h * .66,
            )
            ..lineTo(cx + side * w * .04, h * .72);
        } else {
          p.lineTo(cx + side * w * .04, h * .57);
        }
        canvas.drawPath(p, stroke());
      }
    }
  }

  void _hymenium(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final panel = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * .15, h * .22, w * .7, h * .48),
      Radius.circular(w * .08),
    );
    canvas.drawRRect(panel, fill);
    canvas.drawRRect(panel, stroke());

    if (optionId == 4) {
      for (var i = 0; i < 7; i++) {
        final x = w * (.23 + i * .09);
        canvas.drawLine(Offset(x, h * .27), Offset(x, h * .65), stroke());
      }
    } else if (optionId == 5) {
      for (var row = 0; row < 3; row++) {
        for (var col = 0; col < 5; col++) {
          canvas.drawCircle(
            Offset(w * (.27 + col * .115), h * (.34 + row * .12)),
            w * .025,
            stroke(),
          );
        }
      }
    } else if (optionId == 38) {
      for (var i = 0; i < 8; i++) {
        final x = w * (.22 + i * .08);
        canvas.drawLine(Offset(x, h * .34), Offset(x, h * .63), stroke());
      }
    } else if (optionId == 39) {
      for (var i = 0; i < 5; i++) {
        final y = h * (.33 + i * .075);
        canvas.drawPath(
          Path()
            ..moveTo(w * .22, y)
            ..cubicTo(w * .36, y - 5, w * .54, y + 5, w * .78, y),
          stroke(),
        );
      }
    } else if (optionId == 40) {
      canvas.drawLine(Offset(w * .27, h * .47), Offset(w * .73, h * .47), stroke());
    } else {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(w * .5, h * .47),
          width: w * .44,
          height: h * .25,
        ),
        stroke(),
      );
    }
  }

  void _stemBase(Canvas canvas, Size s) {
    final w = s.width, h = s.height, cx = w / 2;
    final p = Path()..moveTo(w * .44, h * .14);
    if (optionId == 16) {
      p
        ..lineTo(w * .44, h * .56)
        ..cubicTo(w * .41, h * .68, w * .3, h * .73, w * .28, h * .7)
        ..quadraticBezierTo(cx, h * .9, w * .72, h * .7)
        ..cubicTo(w * .7, h * .73, w * .59, h * .68, w * .56, h * .56)
        ..lineTo(w * .56, h * .14);
    } else if (optionId == 17) {
      p
        ..lineTo(w * .44, h * .68)
        ..lineTo(w * .29, h * .61)
        ..quadraticBezierTo(cx, h * .92, w * .71, h * .61)
        ..lineTo(w * .56, h * .68)
        ..lineTo(w * .56, h * .14);
    } else if (optionId == 18) {
      p
        ..lineTo(w * .39, h * .67)
        ..quadraticBezierTo(cx, h * .84, w * .61, h * .67)
        ..lineTo(w * .56, h * .14);
    } else if (optionId == 63) {
      p
        ..lineTo(w * .48, h * .72)
        ..lineTo(w * .52, h * .72)
        ..lineTo(w * .56, h * .14);
    } else if (optionId == 64) {
      p
        ..lineTo(w * .45, h * .65)
        ..quadraticBezierTo(cx, h * .8, w * .49, h * .92)
        ..quadraticBezierTo(cx, h * .97, w * .51, h * .92)
        ..quadraticBezierTo(cx, h * .8, w * .55, h * .65)
        ..lineTo(w * .56, h * .14);
    } else {
      p
        ..lineTo(w * .44, h * .72)
        ..lineTo(w * .56, h * .72)
        ..lineTo(w * .56, h * .14);
    }
    p.close();
    canvas.drawPath(p, fill);
    canvas.drawPath(p, stroke());
  }

  void _ring(Canvas canvas, Size s) {
    final w = s.width, h = s.height, cx = w / 2;
    canvas.drawLine(Offset(cx, h * .13), Offset(cx, h * .86), stroke());
    if (optionId == 7) return;
    final alpha = optionId == 42 ? .45 : 1.0;
    final r = Rect.fromCenter(
      center: Offset(cx, h * .46),
      width: w * .52,
      height: h * .14,
    );
    canvas.drawOval(r, fill);
    canvas.drawOval(r, stroke(alpha));
    canvas.drawLine(Offset(cx, h * .47), Offset(cx, h * .61), stroke(alpha));
  }

  void _volva(Canvas canvas, Size s) {
    final w = s.width, h = s.height, cx = w / 2;
    canvas.drawLine(Offset(cx, h * .13), Offset(cx, h * .7), stroke());
    if (optionId == 9) return;
    final p = Path()
      ..moveTo(w * .24, h * .6)
      ..quadraticBezierTo(w * .29, h * .82, cx, h * .89)
      ..quadraticBezierTo(w * .71, h * .82, w * .76, h * .6);
    canvas.drawPath(p, fill);
    canvas.drawPath(p, stroke(optionId == 43 ? .45 : 1));
  }

  void _generic(Canvas canvas, Size s) {
    final w = s.width, h = s.height, c = Offset(w / 2, h / 2);
    if (traitCode.contains('color') || traitCode.contains('colour')) {
      final hues = <Color>[
        Colors.red,
        Colors.green,
        Colors.brown,
        Colors.orange,
        Colors.yellow,
        Colors.grey,
        Colors.white,
        Colors.black,
        Colors.purple,
        Colors.pink,
      ];
      final color = hues[optionId.abs() % hues.length];
      canvas.drawCircle(c, w * .25, Paint()..color = color);
      canvas.drawCircle(c, w * .25, stroke());
      return;
    }
    if (traitCode.contains('spore_print')) {
      canvas.drawOval(
        Rect.fromCenter(center: c, width: w * .58, height: h * .34),
        fill,
      );
      for (var row = 0; row < 3; row++) {
        for (var col = 0; col < 3; col++) {
          canvas.drawCircle(
            Offset(w * (.28 + col * .22), h * (.34 + row * .16)),
            2,
            Paint()..color = foreground.withValues(alpha: .65),
          );
        }
      }
      return;
    }
    if (traitCode.contains('surface')) {
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(w * .2, h * .18, w * .6, h * .64),
        const Radius.circular(14),
      );
      canvas.drawRRect(r, fill);
      canvas.drawRRect(r, stroke());
      for (var i = 0; i < 6; i++) {
        final y = h * (.27 + i * .085);
        canvas.drawLine(Offset(w * .3, y), Offset(w * .7, y), stroke());
      }
      return;
    }
    if (traitCode.contains('habitat') || traitCode.contains('substrate')) {
      canvas.drawLine(Offset(w * .15, h * .76), Offset(w * .85, h * .76), stroke());
      canvas.drawLine(Offset(c.dx, h * .72), Offset(c.dx, h * .3), stroke());
      canvas.drawCircle(Offset(c.dx, h * .25), w * .17, fill);
      canvas.drawCircle(Offset(c.dx, h * .25), w * .17, stroke());
      return;
    }
    if (traitCode.contains('growth') || traitCode.contains('fruitbody')) {
      for (var i = 0; i < 3; i++) {
        _mushroom(canvas, Offset(w * (.3 + i * .2), h * .58), w * .17);
      }
      return;
    }
    _mushroom(canvas, c, w * .5);
  }

  void _mushroom(Canvas canvas, Offset c, double width) {
    final stem = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(c.dx, c.dy + width * .2),
        width: width * .18,
        height: width * .62,
      ),
      Radius.circular(width * .07),
    );
    canvas.drawRRect(stem, fill);
    canvas.drawRRect(stem, stroke());
    final top = c.dy - width * .05;
    final cap = Path()
      ..moveTo(c.dx - width * .48, top)
      ..quadraticBezierTo(c.dx, top - width * .45, c.dx + width * .48, top)
      ..quadraticBezierTo(c.dx, top + width * .14, c.dx - width * .48, top)
      ..close();
    canvas.drawPath(cap, fill);
    canvas.drawPath(cap, stroke());
  }

  @override
  bool shouldRepaint(covariant _TraitVisualPainter oldDelegate) =>
      oldDelegate.traitCode != traitCode ||
      oldDelegate.optionId != optionId ||
      oldDelegate.foreground != foreground ||
      oldDelegate.accent != accent;
}
