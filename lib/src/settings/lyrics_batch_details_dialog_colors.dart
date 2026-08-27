part of 'lyrics_batch_details_dialog.dart';

class _LyricsBatchDialogTitle extends StatelessWidget {
  const _LyricsBatchDialogTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = PopupDialogColors.resolve(context);
    final mobile =
        MediaQuery.sizeOf(context).width <= popupDialogMobileBreakpoint;
    return Text(
      text,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: colors.textStrong,
        fontSize: mobile ? 18 : 28,
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
    );
  }
}

class _LyricsBatchDetailsFooter extends StatelessWidget {
  const _LyricsBatchDetailsFooter({required this.label, required this.onClear});

  final String label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = PopupDialogColors.resolve(context);
    final mobile =
        MediaQuery.sizeOf(context).width <= popupDialogMobileBreakpoint;
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.border)),
      ),
      padding:
          mobile
              ? const EdgeInsets.fromLTRB(16, 16, 16, 24)
              : const EdgeInsets.fromLTRB(28, 18, 28, 24),
      alignment: Alignment.center,
      child: PopupDialogActionButton(label: label, onPressed: onClear),
    );
  }
}

class _LyricsBatchDetailsColors {
  const _LyricsBatchDetailsColors({
    required this.isDark,
    required this.listSurface,
    required this.listBorder,
    required this.rowBorder,
    required this.rowSurface,
    required this.title,
    required this.subtitle,
    required this.chevron,
    required this.inlinePanel,
    required this.overwrittenInlinePanel,
    required this.overwriteBannerBackground,
    required this.overwriteBannerBorder,
    required this.overwriteBannerText,
    required this.overwriteBannerIcon,
    required this.overwriteButtonBackground,
    required this.overwriteButtonBorder,
    required this.overwriteButtonText,
    required this.overwriteCanceledBackground,
    required this.overwriteCanceledBorder,
    required this.overwriteCanceledText,
    required this.previewBackground,
    required this.previewBorder,
    required this.oldBadgeBackground,
    required this.oldBadgeText,
    required this.newBadgeBackground,
    required this.newBadgeText,
    required this.compareArrowBackground,
    required this.compareArrow,
  });

  final bool isDark;
  final Color listSurface;
  final Color listBorder;
  final Color rowBorder;
  final Color rowSurface;
  final Color title;
  final Color subtitle;
  final Color chevron;
  final Color inlinePanel;
  final Color overwrittenInlinePanel;
  final Color overwriteBannerBackground;
  final Color overwriteBannerBorder;
  final Color overwriteBannerText;
  final Color overwriteBannerIcon;
  final Color overwriteButtonBackground;
  final Color overwriteButtonBorder;
  final Color overwriteButtonText;
  final Color overwriteCanceledBackground;
  final Color overwriteCanceledBorder;
  final Color overwriteCanceledText;
  final Color previewBackground;
  final Color previewBorder;
  final Color oldBadgeBackground;
  final Color oldBadgeText;
  final Color newBadgeBackground;
  final Color newBadgeText;
  final Color compareArrowBackground;
  final Color compareArrow;

  static _LyricsBatchDetailsColors resolve(BuildContext context) {
    final popup = PopupDialogColors.resolve(context);
    if (Theme.of(context).brightness == Brightness.dark) {
      return _LyricsBatchDetailsColors(
        isDark: true,
        listSurface: Colors.white.withValues(alpha: 0.035),
        listBorder: popup.border,
        rowBorder: popup.border,
        rowSurface: Colors.white.withValues(alpha: 0.03),
        title: popup.textStrong,
        subtitle: popup.textMuted,
        chevron: popup.textMuted,
        inlinePanel: Colors.white.withValues(alpha: 0.04),
        overwrittenInlinePanel: Colors.white.withValues(alpha: 0.04),
        overwriteBannerBackground: const Color(0x7378350f),
        overwriteBannerBorder: const Color(0x73fb923c),
        overwriteBannerText: const Color(0xe6fdba74),
        overwriteBannerIcon: const Color(0xfffb923c),
        overwriteButtonBackground: const Color(0x5978350f),
        overwriteButtonBorder: const Color(0x80fb923c),
        overwriteButtonText: const Color(0xf2fdba74),
        overwriteCanceledBackground: Colors.white.withValues(alpha: 0.08),
        overwriteCanceledBorder: popup.border,
        overwriteCanceledText: popup.textMuted,
        previewBackground: Colors.white.withValues(alpha: 0.045),
        previewBorder: popup.border,
        oldBadgeBackground: Colors.white.withValues(alpha: 0.10),
        oldBadgeText: popup.textMuted,
        newBadgeBackground: popup.accent.withValues(alpha: 0.20),
        newBadgeText: popup.accentStrong,
        compareArrowBackground: popup.accent.withValues(alpha: 0.16),
        compareArrow: popup.accentStrong,
      );
    }

    return _LyricsBatchDetailsColors(
      isDark: false,
      listSurface: Colors.white.withValues(alpha: 0.72),
      listBorder: const Color(0xebd2dce9),
      rowBorder: const Color(0xe6e2e8f0),
      rowSurface: Colors.white.withValues(alpha: 0.55),
      title: const Color(0xff111827),
      subtitle: const Color(0xff64748b),
      chevron: const Color(0xff94a3b8),
      inlinePanel: const Color(0xfffbfdff),
      overwrittenInlinePanel: Colors.white,
      overwriteBannerBackground: const Color(0xfffff7ed),
      overwriteBannerBorder: const Color(0x73fdba74),
      overwriteBannerText: const Color(0xff9a3412),
      overwriteBannerIcon: const Color(0xfff97316),
      overwriteButtonBackground: Colors.white.withValues(alpha: 0.90),
      overwriteButtonBorder: const Color(0xffcbd5e1),
      overwriteButtonText: const Color(0xff334155),
      overwriteCanceledBackground: const Color(0xffeff6ff),
      overwriteCanceledBorder: const Color(0xff93c5fd),
      overwriteCanceledText: const Color(0xff2563eb),
      previewBackground: const Color(0xb8f8fafc),
      previewBorder: const Color(0xffd6e0ee),
      oldBadgeBackground: const Color(0xffe2e8f0),
      oldBadgeText: const Color(0xff64748b),
      newBadgeBackground: const Color(0xffdbeafe),
      newBadgeText: const Color(0xff2563eb),
      compareArrowBackground: const Color(0xffeff6ff),
      compareArrow: const Color(0xff2563eb),
    );
  }

  (Color, Color) status(
    LyricsBatchDetailResult result, {
    required bool header,
  }) {
    if (isDark) {
      if (header &&
          (result == LyricsBatchDetailResult.skipped ||
              result == LyricsBatchDetailResult.missing ||
              result == LyricsBatchDetailResult.failed)) {
        return (Colors.white.withValues(alpha: 0.10), const Color(0xadcbd5e1));
      }
      return switch (result) {
        LyricsBatchDetailResult.overwritten => (
          const Color(0x5978350f),
          const Color(0xe6fdba74),
        ),
        LyricsBatchDetailResult.saved => (
          const Color(0x59064e3b),
          const Color(0xe66ee7b7),
        ),
        LyricsBatchDetailResult.skipped => (
          Colors.white.withValues(alpha: 0.08),
          const Color(0xadcbd5e1),
        ),
        LyricsBatchDetailResult.missing || LyricsBatchDetailResult.failed => (
          const Color(0x597f1d1d),
          const Color(0xe6fca5a5),
        ),
      };
    }

    return switch (result) {
      LyricsBatchDetailResult.overwritten => (
        const Color(0xffffedd5),
        const Color(0xffc2410c),
      ),
      LyricsBatchDetailResult.saved => (
        const Color(0xffdcfce7),
        const Color(0xff15803d),
      ),
      LyricsBatchDetailResult.skipped => (
        const Color(0xfff1f5f9),
        const Color(0xff64748b),
      ),
      LyricsBatchDetailResult.missing || LyricsBatchDetailResult.failed => (
        const Color(0xfffee2e2),
        const Color(0xffb91c1c),
      ),
    };
  }
}

class _LyricsBatchStatusPill extends StatelessWidget {
  const _LyricsBatchStatusPill({required this.result, required this.label});

  final LyricsBatchDetailResult result;
  final String label;

  @override
  Widget build(BuildContext context) {
    final statusColors = _LyricsBatchDetailsColors.resolve(
      context,
    ).status(result, header: false);
    return Container(
      key: ValueKey('lyrics-detail-status-${result.name}'),
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: statusColors.$1,
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: statusColors.$2,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LyricsBatchHeaderCountPill extends StatelessWidget {
  const _LyricsBatchHeaderCountPill({
    required this.result,
    required this.count,
  });

  final LyricsBatchDetailResult result;
  final int count;

  @override
  Widget build(BuildContext context) {
    final statusColors = _LyricsBatchDetailsColors.resolve(
      context,
    ).status(result, header: true);
    return Container(
      key: ValueKey('lyrics-detail-group-count-${result.name}'),
      constraints: const BoxConstraints(minWidth: 24, minHeight: 22),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: statusColors.$1,
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: TextStyle(
          color: statusColors.$2,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _lyricsBatchDetailId(LyricsBatchDetailResult result, int index) {
  return '${result.index}-$index';
}

String _lyricsBatchResultLabel(
  SmPlayerI18n i18n,
  LyricsBatchDetailResult result,
) {
  return switch (result) {
    LyricsBatchDetailResult.saved => i18n.t('settings.lyricsBatchSaved'),
    LyricsBatchDetailResult.overwritten => i18n.t(
      'settings.lyricsBatchOverwritten',
    ),
    LyricsBatchDetailResult.skipped => i18n.t('settings.lyricsBatchSkipped'),
    LyricsBatchDetailResult.missing => i18n.t('settings.lyricsBatchMissing'),
    LyricsBatchDetailResult.failed => i18n.t('settings.lyricsBatchFailed'),
  };
}

String _lyricsBatchReasonLabel(
  SmPlayerI18n i18n,
  LyricsBatchSkipReason? reason,
) {
  return switch (reason) {
    LyricsBatchSkipReason.alreadyExists => i18n.t(
      'settings.lyricsBatchReasonAlreadyExists',
    ),
    LyricsBatchSkipReason.sameContent => i18n.t(
      'settings.lyricsBatchReasonSameContent',
    ),
    null => '',
  };
}
