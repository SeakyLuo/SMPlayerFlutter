part of 'artists_page.dart';

class _ArtistsDetailLoadingState extends StatelessWidget {
  const _ArtistsDetailLoadingState();

  @override
  Widget build(BuildContext context) =>
      const SmPlayerLoadingState(layout: SmPlayerLoadingLayout.detail);
}
