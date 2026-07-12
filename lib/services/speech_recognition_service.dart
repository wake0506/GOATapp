import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

enum SpeechState {
  idle,
  requestingPermission,
  initializing,
  listening,
  finalizing,
  recognized,
  parsing,
  preview,
  saving,
  permissionDenied,
  serviceUnavailable,
  error,
}

enum PermissionResult { granted, denied, permanentlyDenied }

class SpeechInitResult {
  final bool available;
  final String? error;

  const SpeechInitResult({required this.available, this.error});
}

class SpeechResult {
  final String text;
  final bool isFinal;

  const SpeechResult({required this.text, required this.isFinal});
}

class LocaleName {
  final String name;
  final String localeId;

  const LocaleName({required this.name, required this.localeId});
}

abstract interface class SpeechRecognitionService {
  Future<SpeechInitResult> initialize();
  Future<PermissionResult> requestPermission();
  Future<void> startListening({required void Function(String text) onPartial});
  Future<SpeechResult> stopListening();
  Future<void> cancel();
  Future<List<LocaleName>> locales();
  bool get isListening;
  Stream<SpeechState> get stateStream;
}

class _ActiveSpeechSession {
  final int id;
  final DateTime createdAt;
  final void Function(String text) onPartial;
  final Completer<void> listening = Completer<void>();
  final Completer<SpeechResult> result = Completer<SpeechResult>();
  bool listeningConfirmed = false;
  bool stopRequested = false;
  bool cancelRequested = false;
  bool terminalStatusReceived = false;
  bool receivedAudio = false;
  String partialText = '';
  String finalText = '';

  _ActiveSpeechSession({
    required this.id,
    required this.createdAt,
    required this.onPartial,
  });

  Duration get elapsed => DateTime.now().difference(createdAt);
}

class DeviceSpeechRecognitionService implements SpeechRecognitionService {
  static const _defaultStartupTimeout = Duration(seconds: 3);
  static const _defaultFinalizeTimeout = Duration(seconds: 3);

  final stt.SpeechToText _speech;
  final Duration _startupTimeout;
  final Duration _finalizeTimeout;
  final StreamController<SpeechState> _states = StreamController.broadcast();
  _ActiveSpeechSession? _activeSession;
  SpeechResult? _lastResult;
  int _nextSessionId = 0;
  String _lastErrorCode = '';
  bool _starting = false;
  bool _initialized = false;
  bool _available = false;
  bool _disposed = false;

  DeviceSpeechRecognitionService({
    stt.SpeechToText? speech,
    Duration startupTimeout = _defaultStartupTimeout,
    Duration finalizeTimeout = _defaultFinalizeTimeout,
  }) : _speech = speech ?? stt.SpeechToText(),
       _startupTimeout = startupTimeout,
       _finalizeTimeout = finalizeTimeout;

  @override
  Stream<SpeechState> get stateStream => _states.stream;

  @override
  bool get isListening =>
      _activeSession?.listeningConfirmed == true && _speech.isListening;

  void _emit(SpeechState state) {
    if (!_disposed) _states.add(state);
  }

  void _log(String message, [_ActiveSpeechSession? session]) {
    if (!kDebugMode) return;
    final suffix = session == null
        ? ''
        : ' session=${session.id} elapsed=${session.elapsed.inMilliseconds}ms';
    debugPrint('[Speech]$suffix $message');
  }

  bool _isCurrent(_ActiveSpeechSession session) =>
      identical(_activeSession, session) && !session.cancelRequested;

  @override
  Future<PermissionResult> requestPermission() async {
    _emit(SpeechState.requestingPermission);
    final status = await Permission.microphone.request();
    if (status.isGranted) return PermissionResult.granted;
    _emit(SpeechState.permissionDenied);
    if (status.isPermanentlyDenied || status.isRestricted) {
      return PermissionResult.permanentlyDenied;
    }
    return PermissionResult.denied;
  }

  @override
  Future<SpeechInitResult> initialize() async {
    if (_initialized) {
      return SpeechInitResult(available: _available);
    }
    _initialized = true;
    _emit(SpeechState.initializing);
    try {
      _available = await _speech.initialize(
        debugLogging: kDebugMode,
        onStatus: _handleStatus,
        onError: _handleError,
      );
      if (!_available) _emit(SpeechState.serviceUnavailable);
      return SpeechInitResult(available: _available);
    } catch (error) {
      _log('initialize failed type=${error.runtimeType}');
      _emit(SpeechState.error);
      return SpeechInitResult(available: false, error: error.toString());
    }
  }

  void _handleStatus(String status) {
    final session = _activeSession;
    _log('raw status=$status', session);
    if (session == null || !_isCurrent(session)) return;

    if (status == 'listening') {
      session.listeningConfirmed = true;
      if (!session.listening.isCompleted) session.listening.complete();
      _emit(SpeechState.listening);
      return;
    }

    if (status == 'notListening' || status == 'done') {
      session.terminalStatusReceived = true;
      if (!session.listeningConfirmed) {
        _log('premature terminal status', session);
        if (!session.listening.isCompleted) session.listening.complete();
        _completeCurrent(
          session,
          SpeechState.error,
          SpeechResult(text: '', isFinal: false),
        );
        return;
      }

      _finishFromPlatform(session);
    }
  }

  void _handleError(SpeechRecognitionError error) {
    final session = _activeSession;
    _lastErrorCode = error.errorMsg;
    _log(
      'raw error code=${error.errorMsg} permanent=${error.permanent}',
      session,
    );
    if (session == null || !_isCurrent(session)) return;

    session.terminalStatusReceived = true;
    if (!session.listeningConfirmed && !session.listening.isCompleted) {
      session.listening.complete();
    }
    _completeCurrent(session, SpeechState.error, _resultFor(session));
  }

  void _finishFromPlatform(_ActiveSpeechSession session) {
    if (!_isCurrent(session) || session.result.isCompleted) return;
    final result = _resultFor(session);
    if (result.text.trim().isEmpty) {
      _completeCurrent(session, SpeechState.error, result);
    } else {
      _completeCurrent(session, SpeechState.recognized, result);
    }
  }

  SpeechResult _resultFor(_ActiveSpeechSession session) {
    final text = session.finalText.isNotEmpty
        ? session.finalText
        : session.partialText;
    return SpeechResult(text: text, isFinal: session.finalText.isNotEmpty);
  }

  void _completeCurrent(
    _ActiveSpeechSession session,
    SpeechState state,
    SpeechResult result,
  ) {
    if (!_isCurrent(session) || session.result.isCompleted) return;
    _lastResult = result;
    session.result.complete(result);
    _emit(state);
    _activeSession = null;
  }

  @override
  Future<List<LocaleName>> locales() async {
    final values = await _speech.locales();
    return values
        .map(
          (locale) => LocaleName(name: locale.name, localeId: locale.localeId),
        )
        .toList();
  }

  @override
  Future<void> startListening({
    required void Function(String text) onPartial,
  }) async {
    if (_activeSession != null || _starting) return;
    _starting = true;
    if (!_available) {
      final result = await initialize();
      if (!result.available) {
        _emit(SpeechState.serviceUnavailable);
        _starting = false;
        return;
      }
    }

    final session = _ActiveSpeechSession(
      id: ++_nextSessionId,
      createdAt: DateTime.now(),
      onPartial: onPartial,
    );
    _activeSession = session;
    _lastResult = null;
    _lastErrorCode = '';
    _log('startListening called', session);

    try {
      final localeId = await _selectChineseLocale();
      _log('selected locale=$localeId', session);
      if (!_isCurrent(session)) {
        _starting = false;
        return;
      }

      await _speech.listen(
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: stt.ListenMode.dictation,
          pauseFor: const Duration(seconds: 5),
          listenFor: const Duration(seconds: 30),
          localeId: localeId,
        ),
        onResult: (result) {
          if (!_isCurrent(session)) return;
          session.partialText = result.recognizedWords;
          session.receivedAudio =
              session.receivedAudio || result.recognizedWords.trim().isNotEmpty;
          if (result.finalResult) session.finalText = result.recognizedWords;
          _log(
            'result final=${result.finalResult} hasText=${result.recognizedWords.trim().isNotEmpty}',
            session,
          );
          session.onPartial(result.recognizedWords);
          if (result.finalResult && session.listeningConfirmed) {
            _completeCurrent(
              session,
              SpeechState.recognized,
              _resultFor(session),
            );
          }
        },
        onSoundLevelChange: (level) {
          if (!_isCurrent(session)) return;
          session.receivedAudio = true;
          _log('sound level received=${level.isFinite}', session);
        },
      );
      _log('listen returned', session);
    } catch (error) {
      _log('listen failed type=${error.runtimeType}', session);
      _completeCurrent(session, SpeechState.error, _resultFor(session));
      _starting = false;
      return;
    }

    try {
      await session.listening.future.timeout(_startupTimeout);
    } on TimeoutException {
      if (_isCurrent(session) && !session.listeningConfirmed) {
        _log('startup timeout error=$_lastErrorCode', session);
        _completeCurrent(session, SpeechState.error, _resultFor(session));
      }
    }
    _starting = false;
  }

  @override
  Future<SpeechResult> stopListening() async {
    final session = _activeSession;
    if (session == null) {
      final result =
          _lastResult ?? const SpeechResult(text: '', isFinal: false);
      _emit(
        result.text.trim().isEmpty ? SpeechState.idle : SpeechState.recognized,
      );
      return result;
    }

    session.stopRequested = true;
    _emit(SpeechState.finalizing);
    _log('stop requested', session);
    try {
      await _speech.stop();
    } catch (error) {
      _log('stop failed type=${error.runtimeType}', session);
    }

    if (!session.result.isCompleted) {
      try {
        await session.result.future.timeout(_finalizeTimeout);
      } on TimeoutException {
        _log('finalize timeout', session);
        _finishFromPlatform(session);
      }
    }
    final result = await session.result.future;
    if (identical(_activeSession, session)) _activeSession = null;
    return result;
  }

  @override
  Future<void> cancel() async {
    final session = _activeSession;
    if (session != null) {
      session.cancelRequested = true;
      _activeSession = null;
      if (!session.result.isCompleted) {
        session.result.complete(const SpeechResult(text: '', isFinal: false));
      }
      _log('cancel requested', session);
    }
    try {
      if (_speech.isListening) await _speech.cancel();
    } finally {
      _emit(SpeechState.idle);
    }
  }

  Future<String?> _selectChineseLocale() async {
    final values = await locales();
    const preferred = ['zh_CN', 'zh-CN', 'zh_Hans_CN', 'zh-Hans-CN'];
    for (final id in preferred) {
      if (values.any((locale) => locale.localeId == id)) return id;
    }
    if (kIsWeb) return 'zh-CN';
    final system = await _speech.systemLocale();
    return system?.localeId;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    await cancel();
    _disposed = true;
    await _states.close();
  }
}
