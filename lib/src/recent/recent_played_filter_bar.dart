part of 'recent_page.dart';

class _RecentPlayedFilterBar extends StatelessWidget {
  const _RecentPlayedFilterBar({
    required this.i18n,
    required this.activeFilter,
    required this.onChanged,
  });

  final SmPlayerI18n i18n;
  final RecentPlayedFilter activeFilter;
  final ValueChanged<RecentPlayedFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(bottom: 2),
        children: [
          _FilterButton(
            visualKey: const ValueKey('Recent.FilterButton.songs'),
            active: activeFilter == RecentPlayedFilter.songs,
            icon: const Icon(FluentIcons.music_note_2_20_regular, size: 18),
            label: i18n.t('common.songs'),
            onPressed: () => onChanged(RecentPlayedFilter.songs),
          ),
          _FilterButton(
            visualKey: const ValueKey('Recent.FilterButton.artists'),
            active: activeFilter == RecentPlayedFilter.artists,
            icon: const Icon(FluentIcons.people_24_regular, size: 18),
            label: i18n.t('recent.artists'),
            onPressed: () => onChanged(RecentPlayedFilter.artists),
          ),
          _FilterButton(
            visualKey: const ValueKey('Recent.FilterButton.albums'),
            active: activeFilter == RecentPlayedFilter.albums,
            icon: const _RecentFilterAlbumIcon(),
            label: i18n.t('recent.albums'),
            onPressed: () => onChanged(RecentPlayedFilter.albums),
          ),
          _FilterButton(
            visualKey: const ValueKey('Recent.FilterButton.playlists'),
            active: activeFilter == RecentPlayedFilter.playlists,
            icon: const _RecentFilterPlaylistIcon(),
            label: i18n.t('recent.playlists'),
            onPressed: () => onChanged(RecentPlayedFilter.playlists),
          ),
        ],
      ),
    );
  }
}

class _FilterButton extends StatefulWidget {
  const _FilterButton({
    required this.visualKey,
    required this.active,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final Key visualKey;
  final bool active;
  final Widget icon;
  final String label;
  final VoidCallback onPressed;

  @override
  State<_FilterButton> createState() => _FilterButtonState();
}

class _FilterButtonState extends State<_FilterButton> {
  var _hovered = false;
  var _focused = false;
  var _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = RecentThemeColors.of(context);
    final hovered = !widget.active && (_hovered || _focused || _pressed);
    final foreground =
        widget.active
            ? colors.playedFilterActiveText
            : hovered
            ? colors.appBarTabHoverText
            : colors.playedFilterText;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: Align(
          alignment: Alignment.center,
          widthFactor: 1,
          child: InkWell(
            borderRadius: BorderRadius.circular(_recentPlayedFilterRadius),
            hoverColor: Colors.transparent,
            focusColor: Colors.transparent,
            highlightColor: Colors.transparent,
            onHover: (value) {
              if (_hovered != value) {
                setState(() {
                  _hovered = value;
                });
              }
            },
            onFocusChange: (value) {
              if (_focused != value) {
                setState(() {
                  _focused = value;
                });
              }
            },
            onHighlightChanged: (value) {
              if (_pressed != value) {
                setState(() {
                  _pressed = value;
                });
              }
            },
            onTap: widget.onPressed,
            child: Container(
              key: widget.visualKey,
              height: 36,
              constraints: const BoxConstraints(minWidth: 72),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color:
                    widget.active
                        ? colors.playedFilterActiveSurface
                        : hovered
                        ? colors.appBarTabHoverSurface
                        : colors.playedFilterSurface,
                border: Border.all(
                  color:
                      widget.active
                          ? colors.playedFilterActiveBorder
                          : hovered
                          ? colors.appBarTabHoverBorder
                          : colors.playedFilterBorder,
                ),
                borderRadius: BorderRadius.circular(_recentPlayedFilterRadius),
                boxShadow:
                    widget.active ? colors.playedFilterActiveShadow : const [],
              ),
              child: IconTheme(
                data: IconThemeData(size: 18, color: foreground),
                child: DefaultTextStyle.merge(
                  style: TextStyle(
                    color: foreground,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      widget.icon,
                      const SizedBox(width: 8),
                      Text(widget.label),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentFilterAlbumIcon extends StatelessWidget {
  const _RecentFilterAlbumIcon();

  @override
  Widget build(BuildContext context) {
    final color =
        IconTheme.of(context).color ??
        DefaultTextStyle.of(context).style.color!;
    return IconTheme(
      data: IconTheme.of(context),
      child: SizedBox.square(
        dimension: 18,
        child: CustomPaint(painter: _RecentAlbumIconPainter(color)),
      ),
    );
  }
}

class _RecentFilterPlaylistIcon extends StatelessWidget {
  const _RecentFilterPlaylistIcon();

  @override
  Widget build(BuildContext context) {
    final color =
        IconTheme.of(context).color ??
        DefaultTextStyle.of(context).style.color!;
    return IconTheme(
      data: IconTheme.of(context),
      child: SizedBox.square(
        dimension: 18,
        child: CustomPaint(painter: _RecentPlaylistIconPainter(color)),
      ),
    );
  }
}

class _RecentAlbumIconPainter extends CustomPainter {
  const _RecentAlbumIconPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 24;
    final center = Offset(size.width / 2, size.height / 2);
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.65 * scale;
    canvas.drawCircle(center, 8 * scale, paint);
    canvas.drawCircle(center, 3 * scale, paint);
    canvas.drawCircle(
      center,
      1 * scale,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _RecentAlbumIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _RecentPlaylistIconPainter extends CustomPainter {
  const _RecentPlaylistIconPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 24;
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.65 * scale
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

    canvas.drawLine(
      Offset(4 * scale, 6 * scale),
      Offset(14 * scale, 6 * scale),
      paint,
    );
    canvas.drawLine(
      Offset(4 * scale, 12 * scale),
      Offset(13 * scale, 12 * scale),
      paint,
    );
    canvas.drawLine(
      Offset(4 * scale, 18 * scale),
      Offset(10 * scale, 18 * scale),
      paint,
    );
    canvas.drawLine(
      Offset(17 * scale, 8 * scale),
      Offset(17 * scale, 17 * scale),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(17 * scale, 8 * scale)
        ..quadraticBezierTo(20.5 * scale, 9 * scale, 21 * scale, 6.5 * scale),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(15.4 * scale, 18.1 * scale),
        width: 5.1 * scale,
        height: 4.1 * scale,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _RecentPlaylistIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
