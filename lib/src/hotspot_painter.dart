import 'package:flutter/widgets.dart';

class HotspotPainter extends CustomPainter {
  /// Paints a skrim with an empty hotspot
  HotspotPainter({
    required this.hotspotBounds,
    required this.skrimColor,
    required this.shapeBorder,
    this.hotspotBorderColor,
    this.hotspotBorderWidth,
  }) {
    if (shapeBorder is OutlinedBorder) {
      hotspotBorderColor ??= (shapeBorder as OutlinedBorder).side.color;
      hotspotBorderWidth ??= (shapeBorder as OutlinedBorder).side.width;
    }
  }

  /// The target to highlight with a hotspot.
  final Rect hotspotBounds;

  /// The color of the skrim which acts as the background
  /// between the hotspot callout and the view. Provides
  /// hotspot cutouts that surround the appropriate [HotspotTarget].
  final Color skrimColor;

  /// The color of the hotspot border. If null, value is derived from the [shapeBorder] if it is an [OutlinedBorder].
  Color? hotspotBorderColor;

  /// The width of the hotspot border. If null, value is derived from the [shapeBorder] if it is an [OutlinedBorder].
  num? hotspotBorderWidth;

  /// Override the convenience [radius] with a custom [ShapeBorder]
  ///
  /// Particularly useful for defining squircle borders.
  final ShapeBorder shapeBorder;

  @override
  void paint(Canvas canvas, Size size) {
    final skrimPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = skrimColor;

    final skrimPath = Path()
      ..addRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
      );

    final hotspotPath = shapeBorder.getOuterPath(hotspotBounds);

    final path = Path.combine(PathOperation.difference, skrimPath, hotspotPath);

    canvas.drawPath(path, skrimPaint);

    // Draw the border if borderColor and borderWidth are set
    if (hotspotBorderColor != null &&
        hotspotBorderWidth != null &&
        hotspotBorderWidth! > 0) {
      final borderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..color = hotspotBorderColor!
        ..strokeWidth = hotspotBorderWidth!.toDouble();

      canvas.drawPath(hotspotPath, borderPaint);
    }
  }

  @override
  bool shouldRepaint(HotspotPainter old) =>
      hotspotBounds != old.hotspotBounds ||
      skrimColor != old.skrimColor ||
      shapeBorder != old.shapeBorder ||
      hotspotBorderColor != old.hotspotBorderColor ||
      hotspotBorderWidth != old.hotspotBorderWidth;
}
