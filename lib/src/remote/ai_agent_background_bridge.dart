import 'music_share_background_host.dart';

/// The foreground engine keeps its existing API handlers on a private port;
/// the independent host owns the public AI port until background sharing ends.
class AiAgentBackgroundBridge {
  MusicShareBackgroundHost? host;
  bool get active => host != null;

  Future<void> configure({
    required bool enabled,
    required int port,
    int? uiPort,
  }) async {
    await host?.configureAgent(enabled: enabled, port: port, uiPort: uiPort);
  }

  Future<void> disconnect({bool stop = false}) async {
    final previous = host;
    host = null;
    await previous?.disconnectAgent(stop: stop);
  }
}
