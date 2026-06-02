import 'package:flutter/material.dart';

class QuickJumpRail extends StatefulWidget {
  const QuickJumpRail({
    super.key,
    required this.scrollController,
    required this.height,
    required this.child,
    this.keyPrefix = 'QuickJump',
  });

  final ScrollController? scrollController;
  final double height;
  final Widget child;
  final String keyPrefix;

  @override
  State<QuickJumpRail> createState() => _QuickJumpRailState();
}

class _QuickJumpRailState extends State<QuickJumpRail> {
  static const _stickyTop = 6.0;

  double? _stickStartOffset;

  @override
  void initState() {
    super.initState();
    widget.scrollController?.addListener(_handleScroll);
    _scheduleStickStartSync();
  }

  @override
  void didUpdateWidget(QuickJumpRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController?.removeListener(_handleScroll);
      widget.scrollController?.addListener(_handleScroll);
      _stickStartOffset = null;
    }
    _scheduleStickStartSync();
  }

  @override
  void dispose() {
    widget.scrollController?.removeListener(_handleScroll);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _scheduleStickStartSync();
    final controller = widget.scrollController;
    final offset =
        controller != null && controller.hasClients ? controller.offset : 0.0;
    final translateY =
        _stickStartOffset == null
            ? 0.0
            : (offset - _stickStartOffset!).clamp(0.0, double.infinity);
    return SizedBox(
      key: ValueKey('${widget.keyPrefix}.StickyHost'),
      height: widget.height,
      child: Transform.translate(
        offset: Offset(0, translateY),
        child: widget.child,
      ),
    );
  }

  void _scheduleStickStartSync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncStickStart();
      }
    });
  }

  void _syncStickStart() {
    final controller = widget.scrollController;
    if (controller == null || !controller.hasClients) {
      return;
    }
    final scrollable = Scrollable.maybeOf(context);
    final railRenderObject = context.findRenderObject();
    final viewportRenderObject = scrollable?.context.findRenderObject();
    if (railRenderObject is! RenderBox || viewportRenderObject is! RenderBox) {
      return;
    }
    final railTop = railRenderObject.localToGlobal(Offset.zero).dy;
    final viewportTop = viewportRenderObject.localToGlobal(Offset.zero).dy;
    final nextStickStartOffset =
        controller.offset + railTop - viewportTop - _stickyTop;
    if (_stickStartOffset == nextStickStartOffset) {
      return;
    }
    setState(() {
      _stickStartOffset = nextStickStartOffset;
    });
  }

  void _handleScroll() {
    if (mounted) {
      setState(() {});
    }
  }
}
