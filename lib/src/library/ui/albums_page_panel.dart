part of 'albums_page.dart';

class _AlbumsPagePanel extends StatelessWidget {
  const _AlbumsPagePanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 720;
    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 10 : 24, 0, 24, 0),
      child: SizedBox.expand(child: child),
    );
  }
}
