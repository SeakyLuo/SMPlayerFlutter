import 'package:go_router/go_router.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../app/text_icon_button.dart';
import '../library/ui/popup_dialog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/undoable_notification.dart';
import '../i18n/app_i18n.dart';
import 'music_share_identity.dart';
import 'music_share_models.dart';
import 'music_share_peers.dart';
import 'music_share_scanner.dart';
import 'music_source_providers.dart';

class MusicShareConnect extends ConsumerStatefulWidget {
  const MusicShareConnect({super.key, required this.onConnected});
  final VoidCallback onConnected;
  @override
  ConsumerState<MusicShareConnect> createState() => _MusicShareConnectState();
}

class _MusicShareConnectState extends ConsumerState<MusicShareConnect> {
  final _address = TextEditingController();
  var _discovering = true;
  var _connecting = false;
  var _canceled = false;
  var _scanning = false;
  String? _code;
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

  Future<void> _connect(String address, {String? fingerprint}) async {
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
      // The first connection is trusted only after the user compares the code
      // on both screens. All subsequent connections pin this certificate.
      final secret = newShareSecret();
      await transport.json(
        '/pair',
        method: 'POST',
        body: {'name': share.name, 'secret': secret},
      );
      final code = shareDigest(
        '${transport.observedFingerprint}:$secret',
      ).substring(0, 8);
      if (!mounted || _canceled) return;
      setState(() {
        _code = code;
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
      final router = GoRouter.of(context);
      widget.onConnected();
      if (router.routeInformationProvider.value.uri.path == '/local') {
        router.go('/songs');
      }
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
          _code = null;
        });
      }
    }
  }

  @override
  void dispose() {
    _canceled = true;
    _transport?.close();
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final share = ref.watch(musicShareProvider);
    final colors = PopupDialogColors.resolve(context);
    if (_scanning) {
      return MusicShareScanner(
        onCancel: () => setState(() => _scanning = false),
        onScanned: (code) {
          setState(() => _scanning = false);
          unawaited(_connect(code.address, fingerprint: code.fingerprint));
        },
      );
    }
    if (_code != null) {
      return ListView(
        padding: EdgeInsets.zero,
        children: [
          Text(i18n.t('share.waitingApproval', {'name': _hostName!})),
          const SizedBox(height: 24),
          Center(
            child: SelectableText(
              _code!,
              style: const TextStyle(
                fontSize: 32,
                letterSpacing: 6,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(i18n.t('share.compareCode')),
          const SizedBox(height: 24),
          PopupDialogActionButton(
            label: i18n.t('common.cancel'),
            onPressed: () {
              _canceled = true;
              _transport?.close();
              setState(() {
                _code = null;
              });
            },
          ),
        ],
      );
    }
    final knownIds = share.peers.map((peer) => peer.id).toSet();
    final nearby =
        share.discovered.where((host) => !knownIds.contains(host.id)).toList();
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Text(
          i18n.t('share.connectHint'),
          style: TextStyle(color: colors.textMuted, fontSize: 14),
        ),
        const SizedBox(height: 20),
        if (Platform.isAndroid || Platform.isIOS) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: SmPlayerTextIconButton(
              label: i18n.t('share.scanToConnect'),
              icon: FluentIcons.scan_camera_24_regular,
              glassEnabled: false,
              disabled: _connecting,
              onPressed: () => setState(() => _scanning = true),
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
                  placeholder: '192.168.1.10:29644',
                  onSubmitted: _connecting ? null : _connect,
                ),
              ),
              const SizedBox(width: 10),
              SmPlayerTextIconButton(
                label: i18n.t(
                  _connecting ? 'share.connecting' : 'share.connect',
                ),
                height: 42,
                minWidth: 88,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                fontVariations: const [],
                horizontalPadding: 16,
                glassEnabled: false,
                loading: _connecting,
                disabled: _connecting,
                onPressed: () => _connect(_address.text),
              ),
            ],
          ),
        ),
        if (share.peers.isNotEmpty) ...[
          const SizedBox(height: 20),
          Divider(height: 1, color: colors.border),
          const SizedBox(height: 16),
          MusicSharePeers(busy: _connecting, onReauthorize: _connect),
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
                PopupDialogActionButton(
                  label: i18n.t('share.connect'),
                  onPressed: _connecting ? null : () => _connect(host.address),
                ),
              ],
            ),
          ),
        if (!_discovering && nearby.isEmpty)
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
                  i18n.t('share.noDevices'),
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
  }
}
