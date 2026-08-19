part of 'recent_page.dart';

class _RecentTimelineScrollView<T> extends StatefulWidget {
  const _RecentTimelineScrollView({
    required this.controller,
    required this.groups,
    required this.contentExtentForGroup,
    required this.onTimelineLabelChange,
    required this.slivers,
  });

  final ScrollController controller;
  final List<_RecentTimeGroup<T>> groups;
  final double Function(_RecentTimeGroup<T> group) contentExtentForGroup;
  final ValueChanged<String> onTimelineLabelChange;
  final List<Widget> slivers;

  @override
  State<_RecentTimelineScrollView<T>> createState() =>
      _RecentTimelineScrollViewState<T>();
}

class _RecentTimelineScrollViewState<T>
    extends State<_RecentTimelineScrollView<T>> {
  var _active = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncTimelineLabel();
      }
    });
  }

  @override
  void didUpdateWidget(_RecentTimelineScrollView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncTimelineLabel();
      }
    });
  }

  void _syncTimelineLabel() {
    if (!_active) {
      return;
    }
    final offset =
        widget.controller.hasClients ? widget.controller.position.pixels : 0.0;
    widget.onTimelineLabelChange(_timelineLabelForOffset(offset + 1));
  }

  String _timelineLabelForOffset(double offset) {
    var groupStart = 0.0;
    for (final group in widget.groups) {
      final headerEnd = groupStart + _recentTimeGroupHeaderExtent;
      final groupEnd = headerEnd + widget.contentExtentForGroup(group);
      if (offset < headerEnd) {
        return '';
      }
      if (offset < groupEnd) {
        return group.label;
      }
      groupStart = groupEnd;
    }
    return widget.groups.isEmpty ? '' : widget.groups.last.label;
  }

  @override
  Widget build(BuildContext context) {
    final active = TickerMode.of(context);
    if (active && !_active) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _syncTimelineLabel();
        }
      });
    }
    _active = active;
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.axis == Axis.vertical) {
          _syncTimelineLabel();
        }
        return false;
      },
      child: CustomScrollView(
        controller: widget.controller,
        slivers: widget.slivers,
      ),
    );
  }
}

class _RecentTimeGroup<T> {
  const _RecentTimeGroup({required this.label, required this.items});

  final String label;
  final List<T> items;
}

List<_RecentTimeGroup<T>> _groupRecentItems<T>(
  List<T> items,
  String Function(T item) getDateLabel,
  SmPlayerI18n i18n,
) {
  final groups = <_RecentTimeGroup<T>>[];
  for (final item in items) {
    final label = categorizeRecentDate(getDateLabel(item), i18n);
    final currentGroup = groups.isEmpty ? null : groups.last;
    if (currentGroup?.label == label) {
      currentGroup!.items.add(item);
    } else {
      groups.add(_RecentTimeGroup(label: label, items: [item]));
    }
  }
  return groups;
}

const _recentTimeGroupHeaderExtent = 36.0;
