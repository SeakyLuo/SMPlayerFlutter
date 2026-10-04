import 'package:flutter/services.dart';

class WindowsSpeechResult {
  const WindowsSpeechResult(this.text, this.error);
  final String text;
  final String? error;
}

class WindowsSpeechRecognition {
  final _channel = const MethodChannel('smplayer/windows_speech');
  var _generation = 0;

  Future<void> cancel() {
    _generation++;
    return _channel.invokeMethod<void>('cancel');
  }

  Future<WindowsSpeechResult> recognize(
    String language, {
    required void Function(String) onHypothesis,
    required void Function(String) onState,
  }) async {
    final generation = ++_generation;
    await _channel.invokeMethod<void>('cancel');
    if (generation != _generation) {
      return const WindowsSpeechResult('', 'canceled');
    }
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'hypothesis':
          onHypothesis(call.arguments as String);
        case 'state':
          onState(call.arguments as String);
      }
    });
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'recognize',
      language,
    );
    return WindowsSpeechResult(
      result!['text'] as String,
      result['error'] as String?,
    );
  }
}
