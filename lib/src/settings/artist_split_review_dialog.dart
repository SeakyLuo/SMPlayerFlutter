import 'dart:async';

import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/ui/popup_dialog.dart';

export 'artist_split_review_panel.dart';

import 'artist_split_review_panel.dart';

class ArtistSplitReviewDialog extends StatefulWidget {
  const ArtistSplitReviewDialog({
    super.key,
    required this.result,
    required this.applying,
    required this.onCancel,
    required this.onApply,
    this.title,
    this.appliedDirectSplits = false,
    this.artworkPathBySongId = const {},
  });

  final ArtistSplitAnalysisResult result;
  final bool applying;
  final VoidCallback onCancel;
  final FutureOr<void> Function(List<ArtistSplitResultItem> splits) onApply;
  final String? title;
  final bool appliedDirectSplits;
  final Map<int, String> artworkPathBySongId;

  @override
  State<ArtistSplitReviewDialog> createState() =>
      _ArtistSplitReviewDialogState();
}

class _ArtistSplitReviewDialogState extends State<ArtistSplitReviewDialog> {
  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final title =
        widget.title ?? i18n.t('local.startupArtistSplitSuggestionsTitle');

    return PopupDialog(
      overlayClassName: 'artist-split-review-overlay',
      className: 'artist-split-review-dialog ContentDialog',
      navClassName: 'artist-split-review-nav',
      navLabel: title,
      ariaLabel: title,
      width: 760,
      height: 820,
      verticalInset: 32,
      onClose: widget.applying ? () {} : widget.onCancel,
      navChildren: [Expanded(child: PopupDialogTitle(title))],
      child: ArtistSplitReviewPanel(
        directSplits: widget.result.directSplits,
        possibleSplits: widget.result.possibleSplits,
        mergeSuggestions: widget.result.mergeSuggestions,
        applying: widget.applying,
        appliedDirectSplits: widget.appliedDirectSplits,
        artworkPathBySongId: widget.artworkPathBySongId,
        onClose: widget.onCancel,
        onApply: widget.onApply,
      ),
    );
  }
}
