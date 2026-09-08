import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/ui/popup_dialog.dart';

import 'smplayer_auto_hide_scrollbar.dart';

class VoiceAssistantHelp extends StatefulWidget {
  const VoiceAssistantHelp({
    super.key,
    required this.i18n,
    required this.onClose,
  });
  final SmPlayerI18n i18n;
  final VoidCallback onClose;
  @override
  State<VoiceAssistantHelp> createState() => _VoiceAssistantHelpState();
}

class _VoiceAssistantHelpState extends State<VoiceAssistantHelp> {
  final _scrollController = ScrollController();
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final i18n = widget.i18n;
    final colors = PopupDialogColors.resolve(context);
    final commands = [
      ('play', 'play1'),
      ('', 'play2'),
      ('', 'play3'),
      ('playControl', 'playControl1'),
      ('volume', 'volume1'),
      ('', 'volume2'),
      ('search', 'search1'),
      ('help', 'help1'),
    ];
    final notices = [
      'noticeCommandLanguage',
      'noticeSmartness',
      'noticeCommandIntro',
      'noticeExample',
    ];
    final style = TextStyle(
      color: colors.textStrong,
      fontSize: 14,
      height: 1.45,
    );
    return PopupDialog(
      overlayClassName: 'music-dialog-overlay VoiceAssistantHelpDialogOverlay',
      className:
          'voice-assistant-help-dialog ContentDialog VoiceAssistantHelpDialog',
      navClassName: 'music-dialog-pivot VoiceAssistantHelpDialogPivot',
      navLabel: i18n.t('voiceAssistant.helpTitle'),
      ariaLabel: i18n.t('voiceAssistant.helpTitle'),
      onClose: widget.onClose,
      navChildren: [
        Expanded(child: PopupDialogTitle(i18n.t('voiceAssistant.helpTitle'))),
      ],
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow =
              MediaQuery.sizeOf(context).width <= popupDialogMobileBreakpoint;
          return Padding(
            padding: EdgeInsets.fromLTRB(
              narrow ? 12 : 28,
              0,
              narrow ? 12 : 28,
              narrow ? 28 : 44,
            ),
            child: SmPlayerAutoHideScrollbar(
              controller: _scrollController,
              child: SingleChildScrollView(
                controller: _scrollController,
                child: DefaultTextStyle(
                  style: style,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        i18n.t('voiceAssistant.supportedCommands'),
                        style: style.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (final command in commands)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 80,
                                child: Text(
                                  command.$1.isEmpty
                                      ? ''
                                      : i18n.t(
                                        'voiceAssistant.command.${command.$1}',
                                      ),
                                  style: style.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  i18n.t(
                                    'voiceAssistant.command.${command.$2}',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Divider(color: colors.border, height: 28),
                      Text(
                        i18n.t('voiceAssistant.notice'),
                        style: style.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (var i = 0; i < notices.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${i + 1}. '),
                              Expanded(
                                child: Text(
                                  i18n.t('voiceAssistant.${notices[i]}'),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
