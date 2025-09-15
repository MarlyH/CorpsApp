import 'dart:math' as math;
import 'package:flutter/material.dart';

class CornerWedge extends StatelessWidget {
  const CornerWedge({
    super.key,
    this.size = 92,
    this.inset = 0,
    this.padding = 14,
    this.perpPadding = 6,
    this.centerText = true,
    this.color = const Color(0xFFD01417),
    this.text = 'BOOKED OUT',
    this.textStyle = const TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w800,
      letterSpacing: .6,
      fontSize: 11,
    ),
    this.showIcon = true,
    this.icon = Icons.event_busy,
    this.iconSize = 18,
    this.iconTextGap = 4,
    this.iconColor, // defaults to textStyle.color
  });

  final double size, inset, padding, perpPadding;
  final bool centerText;
  final Color color;
  final String text;
  final TextStyle textStyle;

  // NEW icon knobs
  final bool showIcon;
  final IconData? icon;
  final double iconSize;
  final double iconTextGap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: inset,
      right: inset,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: CornerWedgePainter(
            color: color,
            text: text,
            textStyle: textStyle,
            padding: padding,
            perpPadding: perpPadding,
            centerText: centerText,
            showIcon: showIcon,
            icon: icon,
            iconSize: iconSize,
            iconTextGap: iconTextGap,
            iconColor: iconColor ?? textStyle.color ?? Colors.white,
          ),
        ),
      ),
    );
  }
}

class CornerWedgePainter extends CustomPainter {
  CornerWedgePainter({
    required this.color,
    required this.text,
    required this.textStyle,
    required this.padding,
    this.perpPadding = 6,
    this.centerText = true,
    // NEW icon knobs
    this.showIcon = true,
    this.icon,
    this.iconSize = 18,
    this.iconTextGap = 4,
    this.iconColor = Colors.white,
  });

  final Color color;
  final String text;
  final TextStyle textStyle;
  final double padding;
  final double perpPadding;
  final bool centerText;

  final bool showIcon;
  final IconData? icon;
  final double iconSize;
  final double iconTextGap;
  final Color iconColor;

  @override
  void paint(Canvas canvas, Size s) {
    // Draw the triangular wedge in the top-right corner.
    final wedge = Path()
      ..moveTo(s.width, 0)
      ..lineTo(s.width, s.height)
      ..lineTo(0, 0)
      ..close();

    canvas.drawPath(wedge, Paint()..color = color);

    // Keep all painting clipped inside the wedge.
    canvas.save();
    canvas.clipPath(wedge);

    // Diagonal line endpoints (inset from both corners).
    final start = Offset(padding, padding);
    final end   = Offset(s.width - padding, s.height - padding);

    final vx = end.dx - start.dx;
    final vy = end.dy - start.dy;
    final len = math.sqrt(vx*vx + vy*vy);

    // Unit directions: along the slope (u) and inward normal (n).
    final ux = vx / len,  uy = vy / len;
    final nx =  vy / len, ny = -vx / len;

    // Shift inward away from the slope by `perpPadding`.
    final startShifted = Offset(
      start.dx + nx * perpPadding,
      start.dy + ny * perpPadding,
    );

    // Rotate so +X runs along the slope.
    final angle = math.atan2(vy, vx);
    canvas.translate(startShifted.dx, startShifted.dy);
    canvas.rotate(angle);

    // --- Layout text
    final tp = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(minWidth: 0, maxWidth: len);

    // --- Layout icon (as a font glyph so we can paint on canvas)
    TextPainter? ip;
    if (showIcon && icon != null) {
      ip = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon!.codePoint),
          style: TextStyle(
            fontFamily: icon!.fontFamily,
            package: icon!.fontPackage,
            fontSize: iconSize,
            color: iconColor,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    }

    final iconW = ip?.width ?? 0;
    final iconH = ip?.height ?? 0;
    final textW = tp.width;
    final textH = tp.height;

    // Group dimensions: stack icon above text (along +Y after rotation).
    final groupW = math.max(iconW, textW);
    final groupH = (ip != null ? iconH : 0) +
                   (ip != null && text.isNotEmpty ? iconTextGap : 0) +
                   (text.isNotEmpty ? textH : 0);

    // Center the whole group along the diagonal.
    final xGroup = centerText ? (len - groupW) / 2 : 0;

    // Paint icon (if any), centered within the group width.
    double yCursor = -groupH / 2;
    if (ip != null) {
      final xIcon = xGroup + (groupW - iconW) / 2;
      ip.paint(canvas, Offset(xIcon, yCursor));
      yCursor += iconH + iconTextGap;
    }

    // Paint text, centered within the group width.
    final xText = xGroup + (groupW - textW) / 2;
    tp.paint(canvas, Offset(xText, yCursor));

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CornerWedgePainter old) =>
      old.color != color ||
      old.text != text ||
      old.textStyle != textStyle ||
      old.padding != padding ||
      old.perpPadding != perpPadding ||
      old.centerText != centerText ||
      old.showIcon != showIcon ||
      old.icon != icon ||
      old.iconSize != iconSize ||
      old.iconTextGap != iconTextGap ||
      old.iconColor != iconColor;
}