part of 'artists_page.dart';

class _ArtistsPagePanel extends StatelessWidget {
  const _ArtistsPagePanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.zero,
      child: SizedBox.expand(child: child),
    );
  }
}
