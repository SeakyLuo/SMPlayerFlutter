import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../app/smplayer_switch.dart';
import '../app/smplayer_auto_hide_scrollbar.dart';
import '../library/ui/popup_dialog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/undoable_notification.dart';
import '../i18n/app_i18n.dart';
import 'music_share_identity.dart';
import 'music_share_controller.dart';
import 'music_share_pair_identity.dart';
import 'music_share_models.dart';
import 'music_share_peers.dart';
import 'music_share_connect_button.dart';
import 'music_share_scanner.dart';
import 'music_share_pair_code.dart';
import 'music_source_providers.dart';
import 'music_source_selector.dart';

class MusicShareConnect extends ConsumerStatefulWidget {
  const MusicShareConnect({super.key, required this.onConnected});
  final VoidCallback onConnected;
  @override
  ConsumerState<MusicShareConnect> createState() => _MusicShareConnectState();
}

class _MusicShareConnectState extends ConsumerState<MusicShareConnect> {
  final _address = TextEditingController();
  final _scrollController = ScrollController(keepScrollOffset: false);
  var _discovering = true;
  var _connecting = false;
  String? _connectingPeerId;
  var _connectingFromScan = false;
  var _canceled = false;
  var _waitingApproval = false;
  String? _hostName;
  MusicShareTransport? _transport;

  @override
  void initState() {
    super.initState();
    unawaited(_discover());
  }

  Future<void> _discover() async {
    try {
      await ref.read(musicShareProvider).discover();
    } catch (_) {
      // Manual address entry remains available when discovery is unavailable.
    } finally {
      if (mounted) setState(() => _discovering = false);
    }
  }

  Future<void> _connectKnown(MusicPeer peer) async {
    setState(() {
      _connecting = true;
      _connectingPeerId = peer.id;
    });
    try {
      await runMusicShareAction(context, () async {
        final share = ref.read(musicShareProvider);
        if (share.selectedSource != peer.id ||
            peer.status != MusicPeerStatus.online) {
          await share.syncPeer(peer, rememberConnection: true);
          await share.selectSource(peer.id);
        }
        if (!mounted) return;
        widget.onConnected();
      });
    } finally {
      if (mounted) {
        setState(() {
          _connecting = false;
          _connectingPeerId = null;
        });
      }
    }
  }

  Future<void> _connect(
    String address, {
    String? fingerprint,
    String? peerId,
    bool fromScan = false,
  }) async {
    final i18n = context.smPlayerI18n;
    final host = Uri.tryParse(
      address.trim().contains('://')
          ? address.trim()
          : 'https://${address.trim()}',
    );
    if (host == null ||
        host.scheme != 'https' ||
        host.host.isEmpty ||
        host.userInfo.isNotEmpty ||
        host.hasQuery ||
        host.hasFragment ||
        (host.path.isNotEmpty && host.path != '/')) {
      showAppNotification(
        context: context,
        message: i18n.t('share.invalidAddress'),
      );
      return;
    }
    setState(() {
      _connecting = true;
      _connectingPeerId = peerId;
      _connectingFromScan = fromScan;
      _canceled = false;
    });
    final transport = MusicShareTransport(
      host.replace(port: host.hasPort ? host.port : musicSharePort).toString(),
      fingerprint: fingerprint,
    );
    _transport = transport;
    try {
      final share = ref.read(musicShareProvider);
      await share.ready;
      final hello = await transport.json('/hello');
      final hostId = hello['id'] as String;
      if (!RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
          ).hasMatch(hostId) ||
          hostId == share.identity.id ||
          hello['version'] != 1) {
        throw const MusicShareException('share.connectionFailed');
      }
      // The first connection is trusted after approval on the sharing device.
      // All subsequent connections pin this certificate.
      final secret = newShareSecret();
      await transport.json(
        '/pair',
        method: 'POST',
        body: {
          'name': share.name,
          'secret': secret,
          ...await signPairIdentity(
            share.identity,
            transport.observedFingerprint!,
            secret,
            share.name,
          ),
          if (share.peers
                  .where(
                    (peer) =>
                        peer.id == hostId &&
                        peer.fingerprint == transport.observedFingerprint,
                  )
                  .firstOrNull
              case final previous?)
            'previousToken': previous.token,
        },
      );
      if (!mounted || _canceled) return;
      setState(() {
        _waitingApproval = true;
        _hostName = hello['name'] as String;
      });
      await share.finishPairing(
        transport,
        secret,
        hello,
        () => _canceled || !mounted,
      );
      if (!mounted || _canceled) return;
      showAppNotification(context: context, message: i18n.t('share.connected'));
      widget.onConnected();
    } catch (error) {
      if (mounted && !_canceled) {
        showAppNotification(
          context: context,
          message: i18n.t(
            error is MusicShareException
                ? error.messageKey
                : 'share.connectionFailed',
          ),
        );
      }
    } finally {
      transport.close();
      if (mounted) {
        setState(() {
          _connecting = false;
          _connectingPeerId = null;
          _connectingFromScan = false;
          _transport = null;
          _waitingApproval = false;
        });
      }
    }
  }

  void _cancelConnection() {
    _canceled = true;
    _transport?.close();
    setState(() => _waitingApproval = false);
  }

  void _reauthorize(String address) {
    final peer = ref
        .read(musicShareProvider)
        .peers
        .firstWhere((peer) => peer.address == address);
    unawaited(_connect(address, peerId: peer.id));
  }

  Future<void> _scan() async {
    final code = await Navigator.of(
      context,
      rootNavigator: true,
    ).push<MusicSharePairCode>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder:
            (scanContext) => MusicShareScanner(
              onCancel: () => Navigator.of(scanContext).pop(),
              onScanned: (code) => Navigator.of(scanContext).pop(code),
            ),
      ),
    );
    if (!mounted || code == null) return;
    await _connect(code.address, fingerprint: code.fingerprint, fromScan: true);
  }

  @override
  void dispose() {
    _canceled = true;
    _transport?.close();
    _address.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildScrollable({
    required String page,
    required List<Widget> children,
  }) {
    const scrollbarGutter = 8.0;
    return ScrollConfiguration(
      key: ValueKey(page),
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: SmPlayerAutoHideScrollbar(
        controller: _scrollController,
        crossAxisMargin: (scrollbarGutter - 7) / 2,
        showOnHover: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: scrollbarGutter),
          child: ListView(
            controller: _scrollController,
            primary: false,
            padding: EdgeInsets.zero,
            children: children,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final share = ref.watch(musicShareProvider);
    final colors = PopupDialogColors.resolve(context);
    if (_waitingApproval) {
      return LayoutBuilder(
        builder:
            (context, constraints) => _buildScrollable(
              page: 'approval',
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Align(
                    alignment: const Alignment(0, -0.25),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            FluentIcons.laptop_24_regular,
                            size: 40,
                            color: colors.textMuted,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            i18n.t('share.waitingApprovalTitle'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: colors.textStrong,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _hostName!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: colors.textMuted,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox.square(
                                dimension: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  i18n.t('share.waitingApprovalHint'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: colors.textMuted,
                                    fontSize: 14,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          PopupDialogActionButton(
                            label: i18n.t('share.cancelConnection'),
                            height: 40,
                            onPressed: _cancelConnection,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
      );
    }
    final mobile = Platform.isAndroid || Platform.isIOS;
    final knownIds = share.peers.map((peer) => peer.id).toSet();
    final nearbyIds = share.discovered.map((host) => host.id).toSet();
    final savedPeers =
        share.peers.where((peer) => !nearbyIds.contains(peer.id)).toList();
    final nearbyPeers =
        share.peers.where((peer) => nearbyIds.contains(peer.id)).toList();
    final nearby =
        share.discovered.where((host) => !knownIds.contains(host.id)).toList();
    final devices = _buildScrollable(
      page: 'devices',
      children: [
        Text(
          i18n.t('share.connectHint'),
          style: TextStyle(color: colors.textMuted, fontSize: 14),
        ),
        const SizedBox(height: 20),
        if (Platform.isAndroid || Platform.isIOS) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: MusicShareConnectButton(
              label: i18n.t(
                _connectingFromScan
                    ? 'share.connecting'
                    : 'share.scanToConnect',
              ),
              loading: _connectingFromScan,
              icon: FluentIcons.scan_camera_24_regular,
              enabled: !_connecting,
              onPressed: _scan,
            ),
          ),
          const SizedBox(height: 16),
        ],
        Text(
          i18n.t('share.computerAddress'),
          style: TextStyle(
            color: colors.textStrong,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 42,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: PopupDialogTextField(
                  controller: _address,
                  enabled: !_connecting,
                  placeholder:
                      mobile ? null : i18n.t('share.addressPlaceholder'),
                  onSubmitted: _connecting ? null : _connect,
                ),
              ),
              const SizedBox(width: 10),
              MusicShareConnectButton(
                label: i18n.t(
                  _connecting &&
                          _connectingPeerId == null &&
                          !_connectingFromScan
                      ? 'share.connecting'
                      : 'share.connect',
                ),
                loading:
                    _connecting &&
                    _connectingPeerId == null &&
                    !_connectingFromScan,
                enabled: !_connecting,
                onPressed: () => _connect(_address.text),
              ),
            ],
          ),
        ),
        if (mobile) ...[
          const SizedBox(height: 8),
          Text(
            i18n.t('share.addressPlaceholder'),
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
        if (savedPeers.isNotEmpty) ...[
          const SizedBox(height: 20),
          Divider(height: 1, color: colors.border),
          const SizedBox(height: 16),
          MusicSharePeers(
            peers: savedPeers,
            busy: _connecting,
            onReauthorize: _reauthorize,
            onConnect: _connectKnown,
            connectingPeerId: _connectingPeerId,
          ),
        ],
        const SizedBox(height: 20),
        Divider(height: 1, color: colors.border),
        const SizedBox(height: 16),
        Text(
          i18n.t('share.nearbyDevices'),
          style: TextStyle(
            color: colors.textStrong,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (nearbyPeers.isNotEmpty)
          MusicSharePeers(
            peers: nearbyPeers,
            showTitle: false,
            busy: _connecting,
            onReauthorize: _reauthorize,
            onConnect: _connectKnown,
            connectingPeerId: _connectingPeerId,
          ),
        for (final host in nearby)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Icon(
                  FluentIcons.desktop_24_regular,
                  color: colors.textMuted,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    host.name,
                    style: TextStyle(color: colors.textStrong, fontSize: 14),
                  ),
                ),
                const SizedBox(width: 12),
                MusicShareConnectButton(
                  label: i18n.t(
                    _connectingPeerId == host.id
                        ? 'share.connecting'
                        : 'share.connect',
                  ),
                  loading: _connectingPeerId == host.id,
                  enabled: !_connecting,
                  onPressed: () => _connect(host.address, peerId: host.id),
                ),
              ],
            ),
          ),
        if (_discovering)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        if (!_discovering && share.discovered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                Icon(
                  FluentIcons.desktop_24_regular,
                  size: 32,
                  color: colors.textMuted,
                ),
                const SizedBox(height: 12),
                Text(
                  i18n.t(
                    savedPeers.isEmpty
                        ? 'share.noDevices'
                        : 'share.noOtherDevices',
                  ),
                  style: TextStyle(
                    color: colors.textStrong,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  i18n.t('share.noNearbyHint'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.textMuted, fontSize: 13),
                ),
              ],
            ),
          ),
      ],
    );
    return Column(
      children: [
        Expanded(child: devices),
        const SizedBox(height: 12),
        if (_connecting && _transport != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PopupDialogActionButton(
              label: i18n.t('common.cancel'),
              onPressed: _cancelConnection,
            ),
          ),
        _AutoConnectSetting(enabled: !_connecting),
      ],
    );
  }
}

class _AutoConnectSetting extends ConsumerWidget {
  const _AutoConnectSetting({required this.enabled});
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final share = ref.watch(musicShareProvider);
    final i18n = context.smPlayerI18n;
    final colors = PopupDialogColors.resolve(context);
    final interactive = enabled && share.initialized && !share.busy;
    void change(bool value) {
      unawaited(
        runMusicShareAction(context, () => share.setAutoConnect(value)),
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: interactive ? () => change(!share.autoConnect) : null,
      child: Container(
        constraints: const BoxConstraints(minHeight: 38),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                i18n.t('share.autoConnect'),
                style: TextStyle(
                  color: colors.textStrong,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 16),
            IgnorePointer(
              ignoring: !interactive,
              child: Opacity(
                opacity: interactive ? 1 : .55,
                child: SmPlayerSwitch(
                  value: share.autoConnect,
                  onChanged: change,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
