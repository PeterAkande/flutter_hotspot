import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:hotspot/hotspot.dart';
import 'package:provider/provider.dart';

import 'callout_layout_delegate.dart';
import 'callout_tail_painter.dart';
import 'hotspot_notification.dart';
import 'hotspot_painter.dart';
import 'paint_bounds_builder.dart';

/// Example of a typical HotspotProvider with actionBuilder handling the
/// progress dots, dismiss button, and next button.
///
/// We recommend setting the bodyWidth to 80% of the viewport width as a default.
///
///
/// ```dart
/// HotspotProvider(
///   curve: Sprung.overDamped,
///   color: Colors.deepPurple.shade800,
///   bodyWidth: min(280.0, MediaQuery.of(context).size.width * 0.8),
///   hotspotShapeBorder: crb.ContinuousRectangleBorder(cornerRadius: 12.0),
///   skrimColor: Colors.black.withOpacity(0.7),
///   child: child,
///   actionBuilder: (_, controller) {
///     return Row(
///       children: [
///         SizedBox(width: 8),
///         FlatButton(
///           child: Text("End tour"),
///           textColor: Colors.white54,
///           onPressed: controller.onDismiss,
///         ),
///         Spacer(flex: 1),
///         Transform.translate(
///           offset: Offset(-8, 0),
///           child: Row(
///             children: [
///               for (var i = 0; i < controller.pages; i++)
///                 AnimatedContainer(
///                   margin: EdgeInsets.all(3),
///                   duration: Duration(milliseconds: 250),
///                   decoration: BoxDecoration(
///                     color: controller.index == i ? Colors.white : Colors.white30,
///                     borderRadius: BorderRadius.circular(99),
///                   ),
///                   height: 6,
///                   width: 6,
///                 ),
///             ],
///           ),
///         ),
///         Spacer(flex: 1),
///         RaisedButton(
///           child: AnimatedCrossFade(
///             crossFadeState: controller.index + 1 < controller.pages
///                 ? CrossFadeState.showFirst
///                 : CrossFadeState.showSecond,
///             duration: Duration(milliseconds: 250),
///             firstChild: Text("Next"),
///             secondChild: Text("Done"),
///           ),
///           color: Colors.deepPurpleAccent,
///           textColor: Colors.white,
///           onPressed: controller.onNext,
///           elevation: 0.0,
///         ),
///         SizedBox(width: 8),
///       ],
///     );
///   },
/// )
/// ```
class HotspotProvider extends StatefulWidget {
  /// Set this to `false` to disable logging
  static var log = true;

  /// Listens for [HotspotTarget]s and provides a scrim with highlighting hotspot
  /// and overlay callout with actions for going to the next [HotspotTarget].
  const HotspotProvider({
    Key? key,
    this.actionBuilder,
    required this.child,
    this.backgroundColor,
    this.foregroundColor,
    this.curve = Curves.easeOutQuint,
    this.duration = const Duration(milliseconds: 750),
    this.padding = const EdgeInsets.all(16),
    this.tailInsets = const EdgeInsets.all(-2),
    this.tailSize = const Size(14, 8),
    this.bodyMargin = const EdgeInsets.all(8),
    this.bodyWidth = 322,
    this.skrimColor,
    this.hotspotShapeBorder = const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16))),
    this.bodyPadding = const EdgeInsets.all(16),
    this.dismissibleSkrim = true,
    this.skrimCurve = Curves.easeOutExpo,
    this.hotspotBorderColor,
    this.hotspotBorderWidth,
    this.autoScroll = true,
    this.scrollDuration = const Duration(milliseconds: 500),
    this.scrollAlignment = 0.5,
    this.scrollTimeout = const Duration(seconds: 2),
    this.skipInvisibleTargets = true,
  }) : super(key: key);

  /// The child which contains multiple [HotspotTarget] in the tree.
  final Widget child;

  /// The transition duration for the hotspot and callout.
  final Duration duration;

  /// The transition curve to use for the hotspot and callout.
  final Curve curve;

  /// The hotspot padding.
  final EdgeInsets padding;

  /// The margin between the hotspot and the tail.
  final EdgeInsets tailInsets;

  /// The size of the callout tail.
  final Size tailSize;

  /// The margin between the callout body and the viewport.
  final EdgeInsets bodyMargin;

  /// The color of the callout body and tail.
  final Color? backgroundColor;

  /// The color of text and icons.
  final Color? foregroundColor;

  /// The width of the callout body;
  final double bodyWidth;

  /// The color of the skrim which acts as the background
  /// between the hotspot callout and the view. Provides
  /// hotspot cutouts that surround the appropriate [HotspotTarget].
  final Color? skrimColor;

  /// The shape of the hotspot border.
  final ShapeBorder hotspotShapeBorder;

  /// The padding to apply to the callout body.
  final EdgeInsets bodyPadding;

  /// The actions to build at the bottom of the callout body.
  ///
  /// Localize the default by constructing [HotspotActionBuilder] with new strings
  final CalloutActionBuilder? actionBuilder;

  /// Tapping on the skrim dismisses the flow when `true`.
  final bool dismissibleSkrim;

  /// Curve for the skrim.
  final Curve skrimCurve;

  /// Border color of the hotspot. if null, value is derived from the [hotspotShapeBorder] if it is an [OutlinedBorder].
  final Color? hotspotBorderColor;

  /// Width of the border of the hotspot. if null, value is derived from the [hotspotShapeBorder] if it is an [OutlinedBorder].
  final num? hotspotBorderWidth;

  /// Whether to automatically scroll to targets that are not visible in the viewport.
  final bool autoScroll;

  /// Duration for the scroll animation.
  final Duration scrollDuration;

  /// Alignment used when scrolling to position targets (0.0 for top, 0.5 for center, 1.0 for bottom).
  final double scrollAlignment;

  /// Timeout for scrolling attempts before moving to the next target.
  final Duration scrollTimeout;

  /// Whether to automatically skip targets that cannot be scrolled into view.
  final bool skipInvisibleTargets;

  /// Retreive the ancestor [HotspotProvider] for the purpose of performing actions.
  static HotspotProviderState of(BuildContext context) =>
      Provider.of<HotspotProviderState>(context, listen: false);

  @override
  HotspotProviderState createState() => HotspotProviderState();
}

class HotspotProviderState extends State<HotspotProvider>
    with TickerProviderStateMixin {
  CalloutActionBuilder get actionBuilder =>
      widget.actionBuilder ?? (_, c) => HotspotActionBuilder(c);

  final _targets = <HotspotTargetState>[];

  var _flow = '';
  var _index = 0;
  var _visible = false;

  /// When we start the flow we save the last focus node, dismiss
  /// focus to close the keyboard, and after the tour is done we
  /// put the focus back where it was.
  FocusNode? _lastFocusNode;

  /// Track whether we're currently in a scrolling operation
  bool _isScrolling = false;

  /// Animation controller for position updates
  late AnimationController _positionAnimationController;

  @override
  void initState() {
    super.initState();
    _positionAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
  }

  @override
  void dispose() {
    _positionAnimationController.dispose();
    super.dispose();
  }

  /// Convenience getter for the current flow sorted by order.
  List<HotspotTargetState> get currentFlow =>
      _targets.where((e) => e.widget.flow == _flow).toList()
        ..sort((a, b) => a.widget.order.compareTo(b.widget.order));

  /// Initiate a hotspot flow
  Future<void> startFlow([String flow = 'main']) async {
    /// Dismiss keyboard if open
    _lastFocusNode = FocusManager.instance.primaryFocus;
    _lastFocusNode?.unfocus();

    _pruneUnmountedTargets();

    setState(() {
      _flow = flow;
      _index = 0;

      if (currentFlow.isEmpty) {
        if (HotspotProvider.log) {
          debugPrint('[Hotspot] warning, flow dispatched, '
              'but no hotspots found. flow: $flow');
        }
      } else {
        _visible = true;
      }
    });

    // Give the UI a moment to render before attempting to scroll
    if (widget.autoScroll && currentFlow.isNotEmpty) {
      // Use a small delay to ensure everything is properly laid out
      await Future.delayed(const Duration(milliseconds: 200));
      await _ensureTargetVisibility(currentFlow[_index]);
    }
  }

  /// Called when tapping the next button.
  /// Can be called externally.
  Future<void> next() async {
    _pruneUnmountedTargets();

    if (_index + 1 < currentFlow.length) {
      setState(() => _index++);

      // Ensure the next target is visible if auto-scroll is enabled
      if (widget.autoScroll) {
        await Future.delayed(const Duration(milliseconds: 100));
        await _ensureTargetVisibility(currentFlow[_index]);
      }
    } else {
      dismiss();
    }
  }

  /// Called when tapping the previous button.
  /// Can be called externally.
  Future<void> previous() async {
    _pruneUnmountedTargets();

    if (_index >= 1) {
      setState(() => _index--);

      // Ensure the previous target is visible if auto-scroll is enabled
      if (widget.autoScroll) {
        await Future.delayed(const Duration(milliseconds: 100));
        await _ensureTargetVisibility(currentFlow[_index]);
      }
    } else {
      dismiss();
    }
  }

  /// Called when tapping the dismiss button.
  /// Can be called externally.
  void dismiss() {
    _pruneUnmountedTargets();

    setState(() => _visible = false);

    /// Put the focus back where it was if we
    /// have a previously-saved focus node.
    _lastFocusNode?.requestFocus();
    _lastFocusNode = null;

    /// don't animate to first tag on subsequent flow runs
    Future.delayed(widget.duration, () => setState(() => _index = 0));
  }

  /// Removes all targets that are not mounted
  void _pruneUnmountedTargets() =>
      _targets.removeWhere((e) => e.mounted == false);

  /// Handle new targets as they become available
  void _handleNewTarget(HotspotTargetState e) {
    _targets.add(e);
    _pruneUnmountedTargets();
  }

  /// Checks if a target is visible in the viewport
  bool _isTargetVisible(HotspotTargetState target) {
    if (!target.mounted) return false;

    try {
      // Get the global paint bounds of the target
      final targetBounds = target.globalPaintBounds;

      // Get the viewport bounds
      final viewportBounds = Rect.fromLTWH(
        0,
        0,
        MediaQuery.of(context).size.width,
        MediaQuery.of(context).size.height,
      );

      if (HotspotProvider.log) {
        debugPrint(
            '[Hotspot] checking visibility: ${target.widget.flow}:${target.widget.order}');
        debugPrint(
            '[Hotspot] target bounds: $targetBounds, viewport: $viewportBounds');
      }

      // Consider target visible if it's at least 30% visible in the viewport
      final intersection = targetBounds.intersect(viewportBounds);
      final visibleArea = intersection.width * intersection.height;
      final targetArea = targetBounds.width * targetBounds.height;

      final isVisible =
          !intersection.isEmpty && (visibleArea / targetArea) > 0.3;

      if (HotspotProvider.log) {
        debugPrint(
            '[Hotspot] target visibility: $isVisible (${(visibleArea / targetArea * 100).toStringAsFixed(1)}%)');
      }

      return isVisible;
    } catch (e) {
      debugPrint('[Hotspot] Error checking visibility: $e');
      return false;
    }
  }

  /// Attempts to scroll a target into view
  Future<bool> _scrollTargetIntoView(HotspotTargetState target) async {
    if (!target.mounted) return false;

    if (HotspotProvider.log) {
      debugPrint(
          '[Hotspot] attempting to scroll to target: ${target.widget.flow}:${target.widget.order}');
    }

    try {
      // Try to scroll the target into view with a timeout
      return await Future.any([
        _scrollToTarget(target),
        Future.delayed(widget.scrollTimeout, () {
          if (HotspotProvider.log) {
            debugPrint('[Hotspot] scroll timeout reached');
          }
          return false;
        })
      ]);
    } catch (e) {
      if (HotspotProvider.log) {
        debugPrint('[Hotspot] error scrolling to target: $e');
      }
      return false;
    }
  }

  /// Performs the actual scrolling operation
  Future<bool> _scrollToTarget(HotspotTargetState target) async {
    try {
      if (HotspotProvider.log) {
        debugPrint(
            '[Hotspot] scrolling to target: ${target.widget.flow}:${target.widget.order}');
      }

      _isScrolling = true;

      // Find the actual scrollable ancestor
      final ScrollableState? scrollable = Scrollable.of(target.context);

      if (scrollable == null) {
        if (HotspotProvider.log) {
          debugPrint('[Hotspot] no scrollable found for target');
        }
        _isScrolling = false;
        return _isTargetVisible(target);
      }

      // Get the initial position to detect if scrolling actually occurred
      final initialPosition = scrollable.position.pixels;

      // Try more directly to control the scrolling
      final RenderObject? targetRenderObject =
          target.context.findRenderObject();

      if (targetRenderObject == null) {
        _isScrolling = false;
        return _isTargetVisible(target);
      }

      final RenderAbstractViewport? viewport =
          RenderAbstractViewport.of(targetRenderObject);

      if (viewport == null) {
        if (HotspotProvider.log) {
          debugPrint('[Hotspot] no viewport found for target');
        }
        _isScrolling = false;
        return _isTargetVisible(target);
      }

      // Calculate the scroll offset needed
      await scrollable.position.ensureVisible(
        targetRenderObject,
        alignment: widget.scrollAlignment,
        duration: widget.scrollDuration,
        curve: widget.curve,
      );

      // Check if scrolling actually occurred
      final didScroll = scrollable.position.pixels != initialPosition;

      if (didScroll) {
        // Wait for layout to settle after scrolling
        await Future.delayed(const Duration(milliseconds: 300));

        // Force a rebuild to update the hotspot position
        if (mounted) {
          // Reset animation controller
          _positionAnimationController.reset();

          // Start the animation to update position smoothly
          _positionAnimationController.forward();

          setState(() {
            // Just trigger a rebuild to recalculate target positions
          });
        }
      }

      // Wait a bit more to ensure animations complete
      await Future.delayed(const Duration(milliseconds: 100));

      _isScrolling = false;

      // Check if target is now visible
      final isVisible = _isTargetVisible(target);
      if (HotspotProvider.log) {
        debugPrint('[Hotspot] after scrolling, target visibility: $isVisible');
      }
      return isVisible;
    } catch (e) {
      debugPrint('[Hotspot] error in scroll operation: $e');
      _isScrolling = false;

      // Fallback to standard method if custom approach fails
      try {
        await Scrollable.ensureVisible(
          target.context,
          alignment: widget.scrollAlignment,
          duration: widget.scrollDuration,
          curve: widget.curve,
        );

        // Wait for layout to settle after scrolling
        await Future.delayed(const Duration(milliseconds: 300));

        // Force a rebuild to update the hotspot position
        if (mounted) {
          // Reset animation controller
          _positionAnimationController.reset();

          // Start the animation to update position smoothly
          _positionAnimationController.forward();

          setState(() {
            // Just trigger a rebuild to recalculate target positions
          });
        }

        await Future.delayed(const Duration(milliseconds: 100));

        return _isTargetVisible(target);
      } catch (e) {
        debugPrint('[Hotspot] fallback scroll method also failed: $e');
        return _isTargetVisible(target);
      }
    }
  }

  /// Ensures target visibility, skipping to next target if needed
  Future<void> _ensureTargetVisibility(HotspotTargetState target) async {
    if (!target.mounted) return;

    if (HotspotProvider.log) {
      debugPrint(
          '[Hotspot] ensuring visibility of target: ${target.widget.flow}:${target.widget.order}');
    }

    if (!_isTargetVisible(target)) {
      final scrolled = await _scrollTargetIntoView(target);

      // Ensure we force a rebuild after scrolling to update positions
      if (scrolled && mounted) {
        // Reset animation controller
        _positionAnimationController.reset();

        // Start the animation to update position smoothly
        _positionAnimationController.forward();

        setState(() {
          // This will trigger a rebuild with the latest positions
        });
      }

      // If target can't be scrolled into view and auto-skip is enabled, go to next target
      if (!scrolled &&
          widget.skipInvisibleTargets &&
          _index + 1 < currentFlow.length) {
        if (HotspotProvider.log) {
          debugPrint(
              '[Hotspot] target not visible after scrolling, skipping to next target');
        }
        await next();
      }
    } else if (HotspotProvider.log) {
      debugPrint('[Hotspot] target already visible, no need to scroll');
    }
  }

  Color get bg =>
      widget.backgroundColor ?? Theme.of(context).colorScheme.surfaceBright;

  Color get fg =>
      widget.foregroundColor ?? Theme.of(context).colorScheme.onSurface;

  @override
  Widget build(BuildContext context) {
    /// Update this index manually to transition between targets
    final currentTarget = currentFlow.isEmpty ? null : currentFlow[_index];

    return Provider<HotspotProviderState>(
      create: (_) => this,
      child: Material(
        child: Stack(
          children: [
            NotificationListener<HotspotNotification>(
              onNotification: (e) {
                if (e.target.mounted) _handleNewTarget(e.target);
                return true;
              },
              child: RepaintBoundary(
                child: widget.child,
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                ignoring: _visible == false,
                child: AnimatedOpacity(
                  opacity: _visible ? 1.0 : 0.0,
                  curve: widget.skrimCurve,
                  duration: widget.duration,
                  child: () {
                    if (currentTarget == null) {
                      return Container();
                    } else {
                      return PaintBoundsBuilder(
                        builder: (context, paintBounds) {
                          // Always get fresh position data when building
                          final targetBounds =
                              _getUpdatedTargetBounds(currentTarget);

                          final delegate = CalloutLayoutDelegate(
                            tailSize: widget.tailSize,
                            tailInsets: widget.tailInsets,
                            paintBounds: paintBounds,
                            targetBounds: targetBounds,
                            hotspotPadding: widget.padding,
                            bodyMargin: widget.bodyMargin,
                            bodyWidth: widget.bodyWidth,
                            hotspotSize: currentTarget.widget.hotspotSize,
                            hotspotOffset: currentTarget.widget.hotspotOffset,
                          );

                          return buildHotspotAndCallout(
                            context: context,
                            delegate: delegate,
                            currentTarget: currentTarget,
                          );
                        },
                      );
                    }
                  }(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Get fresh target bounds, ensuring we have the most up-to-date position
  Rect _getUpdatedTargetBounds(HotspotTargetState target) {
    if (!target.mounted) {
      return Rect.zero;
    }

    try {
      // Force a fresh calculation of the global paint bounds
      final RenderBox renderBox =
          target.context.findRenderObject() as RenderBox;
      final position = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;
      return Rect.fromLTWH(position.dx, position.dy, size.width, size.height);
    } catch (e) {
      debugPrint('[Hotspot] Error getting updated bounds: $e');
      // Fall back to the original method if there's an error
      return target.globalPaintBounds;
    }
  }

  /// Build the hotspot and callout
  Widget buildHotspotAndCallout({
    required BuildContext context,
    required CalloutLayoutDelegate delegate,
    required HotspotTargetState currentTarget,
  }) {
    return Stack(
      children: [
        /// Skrim with hotspot cutout
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.dismissibleSkrim
                ? () {
                    dismiss();
                  }
                : null,
            child: TweenAnimationBuilder<Rect?>(
              curve: widget.curve,
              tween: RectTween(end: delegate.hotspotBounds),
              duration: widget.duration,
              builder: (context, t, child) {
                return CustomPaint(
                  painter: HotspotPainter(
                    hotspotBounds: t!,
                    hotspotBorderColor:
                        currentTarget.widget.hotspotBorderColor ??
                            widget.hotspotBorderColor,
                    hotspotBorderWidth:
                        currentTarget.widget.hotspotBorderWidth ??
                            widget.hotspotBorderWidth,
                    shapeBorder: currentTarget.widget.hotspotShape ??
                        widget.hotspotShapeBorder,
                    skrimColor: widget.skrimColor ??
                        Theme.of(context).colorScheme.scrim.withOpacity(0.4),
                  ),
                );
              },
            ),
          ),
        ),

        /// Callout painter
        Positioned.fill(
          child: Stack(
            children: [
              /// Callout tail
              TweenAnimationBuilder<Rect?>(
                curve: widget.curve,
                duration: widget.duration,
                tween: RectTween(
                  end: delegate.tailBounds,
                ),
                builder: (context, t, child) {
                  return CustomPaint(
                    painter: CalloutTailPainter(
                      tailBounds: t!,
                      color: bg,
                    ),
                  );
                },
              ),

              /// Callout body
              TweenAnimationBuilder<Rect?>(
                curve: widget.curve,
                duration: widget.duration,
                tween: RectTween(
                  end: delegate.bodyContainerBounds,
                ),
                builder: (context, t, child) {
                  return Positioned.fromRect(
                    rect: t!,
                    child: AnimatedContainer(
                      curve: widget.curve,
                      duration: widget.duration,
                      height: delegate.bodyContainerHeight,
                      width: delegate.bodyWidth,
                      alignment: delegate.targetIsAboveCenter
                          ? Alignment.topCenter
                          : Alignment.bottomCenter,

                      /// Absorb tap events so we don't dismiss when tapping on the callout body.
                      /// Without this, the tap event is passed through to the skrim GestureDetector
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          decoration: BoxDecoration(color: bg),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              /// Callout body
                              Padding(
                                padding: widget.bodyPadding,
                                child: AnimatedSize(
                                  duration: widget.duration,
                                  alignment: Alignment.topCenter,
                                  curve: widget.curve,
                                  child: currentTarget.widget.calloutBody,
                                ),
                              ),

                              /// Callout controls
                              actionBuilder(
                                context,
                                CalloutActionController(
                                  dismiss: dismiss,
                                  next: next,
                                  previous: previous,
                                  index: _index,
                                  pages: currentFlow.length,
                                  foregroundColor: fg,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A function that contains all the data needed to build the
/// action section of a callout body.
typedef CalloutActionBuilder = Widget Function(
    BuildContext context, CalloutActionController controller);

class CalloutActionController {
  /// A stateless controller that passes events back to [HotspotProvider]
  /// while providing key metrics to the builder.
  CalloutActionController({
    required this.dismiss,
    required this.next,
    required this.previous,
    required this.index,
    required this.pages,
    required this.foregroundColor,
  });

  final Color? foregroundColor;

  /// Dismiss the callout.
  final VoidCallback dismiss;

  /// Go to the next [HotspotTarget]
  final VoidCallback next;

  /// Go to the previous [HotspotTarget]
  final VoidCallback previous;

  /// The current target's index.
  final int index;

  /// The total number of targets.
  final int pages;

  /// Convenience getter for if we're currently on the last page.
  bool get isLastPage => index + 1 == pages;

  /// Convenience getter for if we're currently on the first page.
  bool get isFirstPage => index == 0;
}
