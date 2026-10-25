import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'shell_models.dart';
import 'voice_assistant_help.dart';
import 'voice_assistant_popover.dart';
import 'windows_speech_recognition.dart';

bool supportsVoiceAssistant() => Platform.isWindows || Platform.isMacOS;

class VoiceAssistantDialog extends StatefulWidget {
  const VoiceAssistantDialog({
    super.key,
    required this.i18n,
    required this.getHint,
    required this.onExecute,
    this.miniMode = false,
  });
  final SmPlayerI18n i18n;
  final String Function() getHint;
  final String Function(String command) onExecute;
  final bool miniMode;

  @override
  State<VoiceAssistantDialog> createState() => _VoiceAssistantDialogState();
}

class _VoiceAssistantDialogState extends State<VoiceAssistantDialog> {
  final _speechToText = SpeechToText();
  final _windowsSpeech = WindowsSpeechRecognition();
  final _tts = FlutterTts();
  Timer? _restartTimer;
  var _text = '';
  var _state = VoiceAssistantCaptureState.starting;
  var _session = 0;
  var _sessionOpen = false;
  var _listening = false;
  var _processing = false;
  var _showHelpLink = false;
  var _popoverOpen = true;
  var _helpOpen = false;

  @override
  void initState() {
    super.initState();
    _text = widget.i18n.t('voiceAssistant.starting');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_openAssistant());
    });
  }

  @override
  void dispose() {
    _cancelSession();
    super.dispose();
  }

  void _cancelSession() {
    if (!_sessionOpen) return;
    _sessionOpen = false;
    _listening = false;
    _processing = false;
    _session += 1;
    _restartTimer?.cancel();
    unawaited(_cancelRecognition().catchError(_ignoreVoicePluginError));
    unawaited(_tts.stop().catchError(_ignoreVoicePluginError));
  }

  void _closePopover() {
    _cancelSession();
    if (_helpOpen) {
      setState(() => _popoverOpen = false);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _closeHelp() {
    if (_popoverOpen) {
      setState(() => _helpOpen = false);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _openHelp() {
    _cancelSession();
    setState(() {
      _popoverOpen = false;
      _helpOpen = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final helpWasOpen = _helpOpen;
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (!helpWasOpen &&
            event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          _closePopover();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_popoverOpen) ...[
              Semantics(
                label: widget.i18n.t('common.close'),
                button: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _closePopover,
                  child: const SizedBox.expand(),
                ),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth <= 560;
                  final compact = narrow || widget.miniMode;
                  return Stack(
                    children: [
                      Positioned(
                        right: compact ? 10 : 54,
                        left: compact ? 10 : null,
                        bottom:
                            widget.miniMode
                                ? 48
                                : SmPlayerShellMetrics.playerHeight - 2,
                        width:
                            compact
                                ? null
                                : (constraints.maxWidth - 40).clamp(0.0, 560.0),
                        child: VoiceAssistantPopover(
                          text: _text,
                          state: _state,
                          miniMode: widget.miniMode,
                          narrow: narrow,
                          helpLabel: widget.i18n.t('voiceAssistant.getHelp'),
                          onClose: _closePopover,
                          onHelp: _showHelpLink ? _openHelp : null,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
            if (_helpOpen)
              VoiceAssistantHelp(i18n: widget.i18n, onClose: _closeHelp),
          ],
        ),
      ),
    );
  }

  Future<void> _openAssistant() async {
    final session = ++_session;
    _sessionOpen = true;
    _listening = true;
    try {
      await _tts.stop();
      await _cancelRecognition();
      if (!_isActiveSession(session)) return;
      if (Platform.isWindows) {
        await _startRecognition(session);
        return;
      }
      final initialized = await _speechToText.initialize(
        onStatus: (status) => _handleSpeechStatus(status, session),
        onError: (error) => _handleSpeechError(error, session),
      );
      if (!_isActiveSession(session)) return;
      if (!initialized) {
        _stopWithError(widget.i18n.t('voiceAssistant.unavailable'));
        return;
      }
      // SpeechToText is a singleton; initialize retains its first listeners.
      _speechToText.statusListener =
          (status) => _handleSpeechStatus(status, session);
      _speechToText.errorListener =
          (error) => _handleSpeechError(error, session);
      await _startRecognition(session);
    } on Object {
      if (_isActiveSession(session)) {
        _stopWithError(widget.i18n.t('voiceAssistant.recognitionUnavailable'));
      }
    }
  }

  Future<void> _startRecognition(int session) async {
    _restartTimer?.cancel();
    setState(() {
      _state = VoiceAssistantCaptureState.starting;
      _text = widget.i18n.t('voiceAssistant.starting');
      _showHelpLink = false;
    });
    try {
      if (Platform.isWindows) {
        await _recognizeWindows(session);
        return;
      }
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
        _stopWithError(widget.i18n.t('voiceAssistant.recognitionUnavailable'));
      }
    }
  }

  Future<void> _cancelRecognition() =>
      Platform.isWindows ? _windowsSpeech.cancel() : _speechToText.cancel();

  Future<void> _recognizeWindows(int session) async {
    final result = await _windowsSpeech.recognize(
      widget.i18n.locale,
      onHypothesis: (text) {
        if (!_isActiveSession(session) || _processing || text.trim().isEmpty) {
          return;
        }
        setState(() {
          _text = text.trim();
          _showHelpLink = false;
          _state = VoiceAssistantCaptureState.capturing;
        });
      },
      onState: (state) {
        if (!_isActiveSession(session) || _processing) return;
        if (state == 'Ready') {
          _recognitionReady();
          return;
        }
        if (state == 'Capturing' ||
            state == 'SoundStarted' ||
            state == 'SpeechDetected') {
          _recognitionReady();
        }
        setState(() {
          _state = switch (state) {
            'Capturing' ||
            'SoundStarted' ||
            'SpeechDetected' => VoiceAssistantCaptureState.capturing,
            'Processing' => VoiceAssistantCaptureState.processing,
            _ =>
              _state == VoiceAssistantCaptureState.starting
                  ? VoiceAssistantCaptureState.starting
                  : VoiceAssistantCaptureState.idle,
          };
        });
      },
    );
    if (!_isActiveSession(session)) return;
    final transcript = result.text.trim();
    if (transcript.isNotEmpty) {
      setState(() {
        _text = transcript;
        _showHelpLink = false;
      });
      await _executeRecognizedCommand(transcript, session);
      return;
    }
    switch (result.error) {
      case 'no-speech':
        _scheduleRecognitionRestart(session);
      case 'canceled':
        _closePopover();
      default:
        _stopWithError(
          widget.i18n.t(switch (result.error) {
            'unavailable' ||
            'unsupported-platform' => 'voiceAssistant.unavailable',
            'privacy-required' => 'voiceAssistant.privacyRequired',
            'audio-capture' => 'voiceAssistant.audioCaptureFailed',
            _ => 'voiceAssistant.recognitionUnavailable',
          }),
        );
    }
  }

  void _handleSpeechStatus(String status, int session) {
    if (!_isActiveSession(session) || _processing) return;
    if (status == 'listening') {
      _recognitionReady();
    } else if (status == 'done' || status == 'notListening') {
      _scheduleRecognitionRestart(session);
    }
  }

  void _recognitionReady() {
    if (_state != VoiceAssistantCaptureState.starting) return;
    setState(() {
      _text = widget.getHint();
      _showHelpLink = true;
      _state = VoiceAssistantCaptureState.idle;
    });
  }

  void _handleSpeechError(SpeechRecognitionError error, int session) {
    if (!_isActiveSession(session)) return;
    final message = error.errorMsg;
    if (message.contains('no_match') ||
        message.contains('no-speech') ||
        message.contains('speech_timeout')) {
      if (!_processing) _scheduleRecognitionRestart(session);
      return;
    }
    _stopWithError(
      widget.i18n.t(
        message.contains('permission')
            ? 'voiceAssistant.privacyRequired'
            : message.contains('audio')
            ? 'voiceAssistant.audioCaptureFailed'
            : 'voiceAssistant.recognitionUnavailable',
      ),
    );
  }

  void _handleSpeechResult(SpeechRecognitionResult result, int session) {
    if (!_isActiveSession(session) || _processing) return;
    final transcript = result.recognizedWords.trim();
    if (transcript.isEmpty) return;
    setState(() {
      _text = transcript;
      _showHelpLink = false;
      _state = VoiceAssistantCaptureState.capturing;
    });
    if (result.finalResult) {
      unawaited(_executeRecognizedCommand(transcript, session));
    }
  }

  Future<void> _executeRecognizedCommand(String command, int session) async {
    _processing = true;
    _restartTimer?.cancel();
    try {
      if (!Platform.isWindows) await _speechToText.stop();
      if (!_isActiveSession(session)) return;
      setState(() => _state = VoiceAssistantCaptureState.processing);
      final result = widget.onExecute(command);
      if (!_isActiveSession(session)) return;
      if (result == widget.i18n.t('voiceAssistant.notUnderstood')) {
        _showMessage(result);
        await _speak(result, session);
        if (_isActiveSession(session)) {
          _processing = false;
          _scheduleRecognitionRestart(session);
        }
        return;
      }
      if (result == widget.i18n.t('voiceAssistant.canceled')) {
        _closePopover();
        return;
      }
      _listening = false;
      if (result == widget.i18n.t('voiceAssistant.help')) {
        _openHelp();
        return;
      }
      if (result == widget.i18n.t('voiceAssistant.executed')) {
        _closePopover();
        return;
      }
      _showMessage(result);
      unawaited(_speak(result, session));
    } on Object {
      if (mounted && _session == session) {
        _stopWithError(widget.i18n.t('voiceAssistant.recognitionUnavailable'));
      }
    }
  }

  Future<void> _speak(String message, int session) async {
    try {
      await _tts.stop();
      if (!mounted || _session != session) return;
      await _tts.setLanguage(widget.i18n.locale);
      if (!mounted || _session != session) return;
      await _tts.awaitSpeakCompletion(true);
      if (!mounted || _session != session) return;
      await _tts.speak(message);
    } on Object {
      // Speech output is optional; recognition can continue without it.
    }
  }

  void _ignoreVoicePluginError(Object error) {}

  void _scheduleRecognitionRestart(int session) {
    _restartTimer?.cancel();
    setState(() => _state = VoiceAssistantCaptureState.idle);
    _restartTimer = Timer(const Duration(milliseconds: 250), () {
      if (_isActiveSession(session) && !_processing) {
        unawaited(_startRecognition(session));
      }
    });
  }

  void _stopWithError(String message) {
    _cancelSession();
    _showMessage(message);
  }

  void _showMessage(String message) {
    setState(() {
      _text = message;
      _state = VoiceAssistantCaptureState.idle;
      _showHelpLink = true;
    });
  }

  bool _isActiveSession(int session) =>
      mounted && _listening && _session == session;
}
