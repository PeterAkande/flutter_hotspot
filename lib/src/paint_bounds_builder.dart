import 'package:flutter/widgets.dart';

class PaintBoundsBuilder extends StatefulWidget {
  /// Safely builds the widget when paintBounds of the ancestor are available.
  ///
  /// Downside to this method is it skips one frame while the widget is being laid out
  const PaintBoundsBuilder({Key? key, required this.builder}) : super(key: key);

  /// Builder method to build the widget based on paintBounds
  final Widget Function(BuildContext context, Rect paintBounds) builder;

  @override
  _PaintBoundsBuilderState createState() => _PaintBoundsBuilderState();
}

class _PaintBoundsBuilderState extends State<PaintBoundsBuilder> {
  Rect? _paintBounds;

  @override
  void initState() {
    _scheduleBoundsUpdate();
    super.initState();
  }

  @override
  void didUpdateWidget(PaintBoundsBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Check for updates when the widget changes
    _scheduleBoundsUpdate();
  }

  void _scheduleBoundsUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final RenderObject? renderObj = context.findRenderObject();
      if (renderObj != null && renderObj is RenderBox && renderObj.hasSize) {
        setState(() {
          _paintBounds = renderObj.paintBounds;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_paintBounds == null) return Container();
    return widget.builder(context, _paintBounds!);
  }
}
