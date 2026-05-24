import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

bool supportsVoiceAssistant() {
  return Platform.isWindows ||
      Platform.isMacOS ||
      Platform.isIOS ||
      Platform.isAndroid;
}

class VoiceAssistantDialog extends StatefulWidget {
  const VoiceAssistantDialog({
    super.key,
    required this.i18n,
    required this.getHint,
    required this.onExecute,
  });

  final SmPlayerI18n i18n;
  final String Function() getHint;
  final String Function(String command) onExecute;

  @override
  State<VoiceAssistantDialog> createState() => _VoiceAssistantDialogState();
}

enum _VoiceAssistantCaptureState { idle, capturing, processing }

class _VoiceAssistantDialogState extends State<VoiceAssistantDialog> {
  late final TextEditingController _controller;
  late final SpeechToText _speechToText;
  late final FlutterTts _tts;
  Timer? _closeTimer;
  Timer? _restartTimer;
  String? _result;
  String _statusText = '';
  var _state = _VoiceAssistantCaptureState.idle;
  var _session = 0;
  var _listening = false;
  var _processing = false;
  var _showHelpLink = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _speechToText = SpeechToText();
    _tts = FlutterTts();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openAssistant();
    });
  }

  @override
  void dispose() {
    _listening = false;
    _session += 1;
    _closeTimer?.cancel();
    _restartTimer?.cancel();
    unawaited(_speechToText.cancel().catchError(_ignoreVoicePluginError));
    unawaited(_tts.stop().catchError(_ignoreVoicePluginError));
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final i18n = widget.i18n;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xfafbfcff),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0x80b9c3d2)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x47232d3c),
                blurRadius: 28,
                offset: Offset(0, 16),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.mic_rounded, color: Color(0xff0063b1)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        i18n.t('player.voiceAssistant'),
                        style: const TextStyle(
                          color: Color(0xff111827),
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: i18n.t('common.close'),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _VoiceAssistantStatus(
                  state: _state,
                  text:
                      _statusText.isEmpty
                          ? i18n.t('voiceAssistant.listening')
                          : _statusText,
                  showHelpLink: _showHelpLink,
                  onOpenHelp: _openHelp,
                  i18n: i18n,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: i18n.t('voiceAssistant.command.play1'),
                    prefixIcon: const Icon(Icons.keyboard_voice_rounded),
                    filled: true,
                    fillColor: const Color(0xe6ffffff),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0x9ebec8d6)),
                    ),
                  ),
                  onSubmitted: (_) => _execute(),
                ),
                if (_result case final result?) ...[
                  const SizedBox(height: 12),
                  Text(
                    result,
                    style: const TextStyle(
                      color: Color(0xff344054),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _VoiceCommandHelp(i18n: i18n),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(i18n.t('common.cancel')),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: _openAssistant,
                      icon: const Icon(Icons.mic_rounded),
                      label: Text(i18n.t('voiceAssistant.listening')),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: _execute,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(i18n.t('common.start')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openAssistant() async {
    _session += 1;
    final session = _session;
    _listening = true;
    _processing = false;
    _closeTimer?.cancel();
    _restartTimer?.cancel();
    try {
      await _tts.stop();
      await _speechToText.cancel();
    } on Object {
      if (mounted) {
        _stopListeningWithMessage(
          widget.i18n.t('voiceAssistant.recognitionUnavailable'),
        );
      }
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _result = null;
      _statusText = widget.getHint();
      _showHelpLink = true;
      _state = _VoiceAssistantCaptureState.idle;
    });
    await _startRecognition(session);
  }

  Future<void> _startRecognition(int session) async {
    _restartTimer?.cancel();
    final bool initialized;
    try {
      initialized = await _speechToText.initialize(
        onStatus: (status) => _handleSpeechStatus(status, session),
        onError: (error) => _handleSpeechError(error, session),
      );
    } on Object {
      if (_isActiveSession(session)) {
        _stopListeningWithMessage(
          widget.i18n.t('voiceAssistant.recognitionUnavailable'),
        );
      }
      return;
    }
    if (!_isActiveSession(session)) {
      return;
    }
    if (!initialized) {
      _stopListeningWithMessage(widget.i18n.t('voiceAssistant.unavailable'));
      return;
    }

    _controller.clear();
    setState(() {
      _state = _VoiceAssistantCaptureState.idle;
    });
    try {
      await _speechToText.listen(
        onResult: (result) => _handleSpeechResult(result, session),
        listenOptions: SpeechListenOptions(
          partialResults: true,
          listenMode: ListenMode.confirmation,
          localeId: widget.i18n.locale,
          pauseFor: const Duration(seconds: 2),
          listenFor: const Duration(seconds: 8),
        ),
      );
    } on Object {
      if (_isActiveSession(session)) {
        _stopListeningWithMessage(
          widget.i18n.t('voiceAssistant.recognitionUnavailable'),
        );
      }
    }
  }

  void _handleSpeechStatus(String status, int session) {
    if (!_isActiveSession(session)) {
      return;
    }
    if (status == 'listening') {
      setState(() {
        _state = _VoiceAssistantCaptureState.capturing;
      });
    }
    if ((status == 'done' || status == 'notListening') &&
        !_processing &&
        _controller.text.trim().isEmpty) {
      _scheduleRecognitionRestart(session);
    }
  }

  void _handleSpeechError(SpeechRecognitionError error, int session) {
    if (!_isActiveSession(session)) {
      return;
    }
    final message = error.errorMsg;
    if (message.contains('no_match') ||
        message.contains('no-speech') ||
        message.contains('speech_timeout')) {
      _scheduleRecognitionRestart(session);
      return;
    }
    _stopListeningWithMessage(
      message.contains('permission')
          ? widget.i18n.t('voiceAssistant.privacyRequired')
          : widget.i18n.t('voiceAssistant.recognitionUnavailable'),
    );
  }

  void _handleSpeechResult(SpeechRecognitionResult result, int session) {
    if (!_isActiveSession(session)) {
      return;
    }
    final transcript = result.recognizedWords.trim();
    if (transcript.isNotEmpty) {
      _controller.text = transcript;
      setState(() {
        _statusText = transcript;
        _showHelpLink = false;
        _state = _VoiceAssistantCaptureState.capturing;
      });
    }
    if (result.finalResult && transcript.isNotEmpty) {
      unawaited(_executeRecognizedCommand(transcript, session));
    }
  }

  Future<void> _executeRecognizedCommand(String command, int session) async {
    _processing = true;
    try {
      await _speechToText.stop();
    } on Object {
      if (_isActiveSession(session)) {
        _stopListeningWithMessage(
          widget.i18n.t('voiceAssistant.recognitionUnavailable'),
        );
      }
      return;
    }
    if (!_isActiveSession(session)) {
      return;
    }
    setState(() {
      _state = _VoiceAssistantCaptureState.processing;
      _statusText = widget.i18n.t('voiceAssistant.processing');
    });
    final result = widget.onExecute(command);
    if (!_isActiveSession(session)) {
      return;
    }
    setState(() {
      _result = result;
      _statusText = result;
    });
    if (result == widget.i18n.t('voiceAssistant.notUnderstood')) {
      await _speak(result);
      if (_isActiveSession(session)) {
        _processing = false;
        _scheduleRecognitionRestart(session);
      }
      return;
    }
    _listening = false;
    if (result != widget.i18n.t('voiceAssistant.executed') &&
        result != widget.i18n.t('voiceAssistant.canceled')) {
      await _speak(result);
    }
    _closeTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  Future<void> _speak(String message) async {
    try {
      await _tts.stop();
      await _tts.setLanguage(widget.i18n.locale);
      await _tts.awaitSpeakCompletion(true);
      await _tts.speak(message);
    } on Object {
      return;
    }
  }

  void _ignoreVoicePluginError(Object error) {}

  void _scheduleRecognitionRestart(int session) {
    _restartTimer?.cancel();
    _restartTimer = Timer(const Duration(milliseconds: 250), () {
      if (_isActiveSession(session)) {
        unawaited(_startRecognition(session));
      }
    });
  }

  void _stopListeningWithMessage(String message) {
    _listening = false;
    _processing = false;
    setState(() {
      _state = _VoiceAssistantCaptureState.idle;
      _showHelpLink = false;
      _statusText = message;
      _result = message;
    });
  }

  void _openHelp() {
    setState(() {
      _result = widget.i18n.t('voiceAssistant.help');
      _showHelpLink = false;
    });
  }

  bool _isActiveSession(int session) {
    return mounted && _listening && _session == session;
  }

  void _execute() {
    _listening = false;
    _processing = false;
    _session += 1;
    _restartTimer?.cancel();
    _closeTimer?.cancel();
    unawaited(_speechToText.stop());
    final result = widget.onExecute(_controller.text);
    setState(() {
      _result = result;
      _statusText = result;
      _showHelpLink = false;
      _state = _VoiceAssistantCaptureState.idle;
    });
  }
}

class _VoiceAssistantStatus extends StatelessWidget {
  const _VoiceAssistantStatus({
    required this.state,
    required this.text,
    required this.showHelpLink,
    required this.onOpenHelp,
    required this.i18n,
  });

  final _VoiceAssistantCaptureState state;
  final String text;
  final bool showHelpLink;
  final VoidCallback onOpenHelp;
  final SmPlayerI18n i18n;

  @override
  Widget build(BuildContext context) {
    final isProcessing = state == _VoiceAssistantCaptureState.processing;
    final isCapturing = state == _VoiceAssistantCaptureState.capturing;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isCapturing ? const Color(0x1f0063b1) : const Color(0x0f0d1826),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color:
              isCapturing ? const Color(0x660063b1) : const Color(0x1f536379),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            if (isProcessing)
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              )
            else
              Icon(
                isCapturing ? Icons.graphic_eq_rounded : Icons.mic_none_rounded,
                color: const Color(0xff0063b1),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: Color(0xff344054),
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ),
            if (showHelpLink)
              TextButton(
                onPressed: onOpenHelp,
                child: Text(i18n.t('voiceAssistant.getHelp')),
              ),
          ],
        ),
      ),
    );
  }
}

class _VoiceCommandHelp extends StatelessWidget {
  const _VoiceCommandHelp({required this.i18n});

  final SmPlayerI18n i18n;

  @override
  Widget build(BuildContext context) {
    final commands = [
      ('voiceAssistant.command.play', 'voiceAssistant.command.play1'),
      (
        'voiceAssistant.command.playControl',
        'voiceAssistant.command.playControl1',
      ),
      ('voiceAssistant.command.search', 'voiceAssistant.command.search1'),
      ('voiceAssistant.command.volume', 'voiceAssistant.command.volume1'),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x0f0d1826),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x1f536379)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              i18n.t('voiceAssistant.supportedCommands'),
              style: const TextStyle(
                color: Color(0xff111827),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            for (final command in commands)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${i18n.t(command.$1)}: ${i18n.t(command.$2)}',
                  style: const TextStyle(
                    color: Color(0xff5b697a),
                    height: 1.35,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
