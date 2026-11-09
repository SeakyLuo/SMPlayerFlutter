import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../app/text_icon_button.dart';
import '../library/ui/popup_dialog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../i18n/app_i18n.dart';
import 'music_share_models.dart';
import 'music_source_providers.dart';
import 'music_source_selector.dart';

class MusicSharePeers extends ConsumerWidget {
  const MusicSharePeers({
    super.key,
    required this.onReauthorize,
    required this.busy,
  });

  final ValueChanged<String> onReauthorize;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final share = ref.watch(musicShareProvider);
    final i18n = context.smPlayerI18n;
    final colors = PopupDialogColors.resolve(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          i18n.t('share.connectedComputers'),
          style: TextStyle(
            color: colors.textStrong,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        for (final peer in share.peers)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              FluentIcons.desktop_24_regular,
              color: colors.textMuted,
            ),
            title: Text(
              peer.name,
              style: TextStyle(color: colors.textStrong, fontSize: 14),
            ),
            subtitle: Text(
              i18n.t(switch (peer.status) {
                MusicPeerStatus.online => 'share.online',
                MusicPeerStatus.unauthorized => 'share.authorizationRequired',
                MusicPeerStatus.offline => 'share.offline',
              }),
              style: TextStyle(color: colors.textMuted, fontSize: 13),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PopupDialogActionButton(
                  label: i18n.t(
                    peer.status == MusicPeerStatus.unauthorized
                        ? 'share.reauthorize'
                        : 'share.connect',
                  ),
                  onPressed:
                      busy
                          ? null
                          : () {
                            if (peer.status == MusicPeerStatus.unauthorized) {
                              onReauthorize(peer.address);
                            } else {
                              runMusicShareAction(
                                context,
                                () => share.syncPeer(peer),
                              );
                            }
                          },
                ),
                const SizedBox(width: 4),
                SmPlayerTextIconButton(
                  label: i18n.t('share.disconnect'),
                  icon: FluentIcons.dismiss_20_regular,
                  showLabel: false,
                  glassEnabled: false,
                  horizontalPadding: 8,
                  height: 36,
                  onPressed:
                      busy
                          ? null
                          : () => runMusicShareAction(
                            context,
                            () => share.forget(peer),
                          ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
