import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/undoable_notification.dart';
import '../i18n/app_i18n.dart';
import '../library/ui/library_load_failure.dart';
import '../library/data/library_providers.dart';
import '../platform/system_log.dart';
import 'music_share_models.dart';
import 'music_source_providers.dart';

class RemotePageAccess extends ConsumerStatefulWidget {
  const RemotePageAccess({
    super.key,
    required this.device,
    required this.location,
    required this.child,
  });
  final String device;
  final String location;
  final Widget child;

  @override
  ConsumerState<RemotePageAccess> createState() => _RemotePageAccessState();
}

class _RemotePageAccessState extends ConsumerState<RemotePageAccess> {
  var _generation = 0;
  var _loading = false;
  var _failed = false;
  var _visible = false;
  (String, String)? _lastAccess;

  bool get _needsData {
    if (widget.device == 'local') return false;
    final path = Uri.parse(widget.location).path;
    return [
      '/songs',
      '/artists',
      '/albums',
      '/playlists',
      '/favorites',
      '/search',
    ].any((root) => path == root || path.startsWith('$root/'));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _enterVisiblePage();
  }

  @override
  void didUpdateWidget(RemotePageAccess oldWidget) {
    super.didUpdateWidget(oldWidget);
    _enterVisiblePage();
  }

  void _enterVisiblePage() {
    _visible = TickerMode.valuesOf(context).enabled;
    if (!_visible) {
      if (_loading) {
        _generation += 1;
        _lastAccess = null;
        _loading = false;
      }
      return;
    }
    final access = (widget.device, widget.location);
    if (_lastAccess != access) {
      _lastAccess = access;
      unawaited(_access());
    }
  }

  void _retry() {
    invalidateLibraryQueries(ref.invalidate, source: widget.device);
    if (_visible && !_loading) unawaited(_access());
  }

  Future<void> _access() async {
    final generation = ++_generation;
    setState(() {
      _loading = _needsData;
      _failed = false;
    });
    if (!_needsData) return;
    bool current() => mounted && _visible && generation == _generation;
    try {
      final share = ref.read(musicShareProvider);
      await share.ready;
      if (current()) share.notifyLibraryAccess(widget.device);
      if (current()) setState(() => _loading = false);
    } catch (error, stack) {
      if (!mounted || !_visible || generation != _generation) return;
      SystemLog.error('Remote page read failed', error, stack);
      setState(() {
        _loading = false;
        _failed = true;
      });
      showAppNotification(
        context: context,
        message: context.smPlayerI18n.t(
          error is MusicShareException
              ? error.messageKey
              : 'share.connectionFailed',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final blocked = _failed;
    final directoryPage = Uri.parse(widget.location).path == '/local';
    return RemotePageAccessScope(
      retry: _retry,
      loading: _loading,
      failed: _failed,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Keep navigation state mounted, but prevent hidden content from making
          // visibility-driven artwork requests or accepting user input.
          TickerMode(
            enabled: directoryPage || !blocked,
            child: Offstage(
              offstage: !directoryPage && blocked,
              child: widget.child,
            ),
          ),
          if (!directoryPage && _failed) LibraryLoadFailure(onRetry: _retry),
        ],
      ),
    );
  }
}

class RemotePageAccessScope extends InheritedWidget {
  const RemotePageAccessScope({
    super.key,
    required this.retry,
    required this.loading,
    required this.failed,
    required super.child,
  });
  final VoidCallback retry;
  final bool loading;
  final bool failed;

  static RemotePageAccessScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RemotePageAccessScope>()!;

  @override
  bool updateShouldNotify(RemotePageAccessScope oldWidget) =>
      retry != oldWidget.retry ||
      loading != oldWidget.loading ||
      failed != oldWidget.failed;
}
