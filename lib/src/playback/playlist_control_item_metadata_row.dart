part of 'playlist_control_item.dart';

class _QueueMetadataRow extends MultiChildRenderObjectWidget {
  const _QueueMetadataRow({required super.children});

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderQueueMetadataRow(Directionality.of(context));
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderQueueMetadataRow renderObject,
  ) {
    renderObject.textDirection = Directionality.of(context);
  }
}

class _QueueMetadataParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderQueueMetadataRow extends RenderBox
    with
        ContainerRenderObjectMixin<
          RenderBox,
          ContainerBoxParentData<RenderBox>
        >,
        RenderBoxContainerDefaultsMixin<
          RenderBox,
          ContainerBoxParentData<RenderBox>
        > {
  _RenderQueueMetadataRow(this._textDirection);

  TextDirection _textDirection;

  set textDirection(TextDirection value) {
    if (_textDirection == value) return;
    _textDirection = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    child.parentData = _QueueMetadataParentData();
  }

  @override
  void performLayout() {
    final children = getChildrenAsList();
    final widths = [
      for (final child in children)
        child.getMaxIntrinsicWidth(constraints.maxHeight),
    ];
    final totalWidth = widths.fold(0.0, (total, width) => total + width);
    size = constraints.constrain(Size(totalWidth, constraints.maxHeight));
    final scale = totalWidth > size.width ? size.width / totalWidth : 1.0;
    var offset = 0.0;
    for (var index = 0; index < children.length; index++) {
      final child = children[index];
      final width = widths[index] * scale;
      child.layout(
        BoxConstraints.tightFor(width: width, height: size.height),
        parentUsesSize: true,
      );
      final parentData = child.parentData! as ContainerBoxParentData<RenderBox>;
      parentData.offset = Offset(
        _textDirection == TextDirection.ltr
            ? offset
            : size.width - offset - width,
        0,
      );
      offset += width;
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }
}
