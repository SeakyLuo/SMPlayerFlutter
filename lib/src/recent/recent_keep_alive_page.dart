part of 'recent_page.dart';

class _RecentKeepAlivePage extends StatefulWidget {
  const _RecentKeepAlivePage({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<_RecentKeepAlivePage> createState() => _RecentKeepAlivePageState();
}

class _RecentKeepAlivePageState extends State<_RecentKeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return TickerMode(enabled: widget.active, child: widget.child);
  }
}
