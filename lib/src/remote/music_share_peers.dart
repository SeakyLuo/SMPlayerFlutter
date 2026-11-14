import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../library/ui/popup_dialog.dart';

import '../i18n/app_i18n.dart';
import 'music_share_models.dart';
import 'music_share_connect_button.dart';

class MusicSharePeers extends StatelessWidget {
  const MusicSharePeers({
    super.key,
    required this.onReauthorize,
    required this.busy,
    required this.onConnect,
    this.connectingPeerId,
    required this.peers,
    this.showTitle = true,
  });

  final ValueChanged<String> onReauthorize;
  final bool busy;
  final ValueChanged<MusicPeer> onConnect;
  final String? connectingPeerId;
  final List<MusicPeer> peers;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final colors = PopupDialogColors.resolve(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle)
          Text(
            i18n.t('share.connectedComputers'),
            style: TextStyle(
              color: colors.textStrong,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        for (final peer in peers)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              FluentIcons.desktop_24_regular,
              color: colors.textMuted,
            ),
            title: Text(
              peer.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.textStrong, fontSize: 14),
            ),
            subtitle: Row(
              children: [
                if (peer.status == MusicPeerStatus.online) ...[
                  const SizedBox.square(
                    dimension: 7,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0xff34c759),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    i18n.t(switch (peer.status) {
                      MusicPeerStatus.online => 'share.connectedState',
                      MusicPeerStatus.unauthorized =>
                        'share.authorizationRequired',
                      MusicPeerStatus.offline => 'share.offline',
                    }),
                    style: TextStyle(color: colors.textMuted, fontSize: 13),
                  ),
                ),
              ],
            ),
            trailing:
                peer.status == MusicPeerStatus.online
                    ? null
                    : MusicShareConnectButton(
                      label: i18n.t(
                        connectingPeerId == peer.id
                            ? 'share.connecting'
                            : peer.status == MusicPeerStatus.unauthorized
                            ? 'share.reauthorize'
                            : 'share.connect',
                      ),
                      loading: connectingPeerId == peer.id,
                      enabled: !busy,
                      onPressed: () {
                        if (peer.status == MusicPeerStatus.unauthorized) {
                          onReauthorize(peer.address);
                        } else {
                          onConnect(peer);
                        }
                      },
                    ),
          ),
      ],
    );
  }
}
