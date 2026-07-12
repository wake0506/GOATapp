import 'dart:async';

import 'package:permission_handler/permission_handler.dart';
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

class DeviceSpeechRecognitionService implements SpeechRecognitionService {
  final stt.SpeechToText _speech;
  final StreamController<SpeechState> _states = StreamController.broadcast();
  Completer<SpeechResult>? _finalResult;
  String _partialText = '';
  String _finalText = '';
  bool _initialized = false;
  bool _available = false;
  bool _disposed = false;

  DeviceSpeechRecognitionService({stt.SpeechToText? speech})
    : _speech = speech ?? stt.SpeechToText();

  @override
  Stream<SpeechState> get stateStream => _states.stream;

  @override
  bool get isListening => _speech.isListening;

  void _emit(SpeechState state) {
    if (!_disposed) _states.add(state);
  }

  @override
  Future<PermissionResult> requestPermission() async {
    _emit(SpeechState.requestingPermission);
    final status = await Permission.microphone.request();
    if (status.isGranted) return PermissionResult.granted;
    if (status.isPermanentlyDenied || status.isRestricted) {
      _emit(SpeechState.permissionDenied);
      return PermissionResult.permanentlyDenied;
    }
    _emit(SpeechState.permissionDenied);
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
        onStatus: (status) {
          if (status == 'listening') _emit(SpeechState.listening);
          if (status == 'notListening' || status == 'done') {
            if (_finalResult?.isCompleted == false) {
              _emit(SpeechState.finalizing);
            }
          }
        },
        onError: (_) {
          _emit(SpeechState.error);
          if (_finalResult?.isCompleted == false) {
            _finalResult?.complete(
              SpeechResult(
                text: _finalText.isNotEmpty ? _finalText : _partialText,
                isFinal: false,
              ),
            );
          }
        },
        finalTimeout: const Duration(seconds: 2),
      );
      if (!_available) _emit(SpeechState.serviceUnavailable);
      return SpeechInitResult(available: _available);
    } catch (error) {
      _emit(SpeechState.error);
      return SpeechInitResult(available: false, error: error.toString());
    }
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
    if (!_available) {
      final result = await initialize();
      if (!result.available) {
        _emit(SpeechState.serviceUnavailable);
        return;
      }
    }
    _partialText = '';
    _finalText = '';
    _finalResult = Completer<SpeechResult>();
    final localeId = await _selectChineseLocale();
    await _speech.listen(
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        localeId: localeId,
        pauseFor: const Duration(seconds: 3),
        listenFor: const Duration(minutes: 1),
      ),
      onResult: (result) {
        _partialText = result.recognizedWords;
        if (result.finalResult) _finalText = result.recognizedWords;
        onPartial(result.recognizedWords);
        if (result.finalResult && _finalResult?.isCompleted == false) {
          _finalResult?.complete(
            SpeechResult(text: result.recognizedWords, isFinal: true),
          );
          _emit(SpeechState.recognized);
        }
      },
    );
    _emit(SpeechState.listening);
  }

  @override
  Future<SpeechResult> stopListening() async {
    if (!isListening) {
      final text = _finalText.isNotEmpty ? _finalText : _partialText;
      _emit(text.isEmpty ? SpeechState.idle : SpeechState.recognized);
      return SpeechResult(text: text, isFinal: _finalText.isNotEmpty);
    }
    _emit(SpeechState.finalizing);
    final resultFuture = _finalResult?.future;
    await _speech.stop();
    if (resultFuture == null) {
      return SpeechResult(
        text: _finalText.isNotEmpty ? _finalText : _partialText,
        isFinal: _finalText.isNotEmpty,
      );
    }
    try {
      return await resultFuture.timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          final text = _finalText.isNotEmpty ? _finalText : _partialText;
          return SpeechResult(text: text, isFinal: _finalText.isNotEmpty);
        },
      );
    } finally {
      _finalResult = null;
    }
  }

  @override
  Future<void> cancel() async {
    _finalResult = null;
    if (_speech.isListening) await _speech.cancel();
    _partialText = '';
    _finalText = '';
    _emit(SpeechState.idle);
  }

  Future<String?> _selectChineseLocale() async {
    final values = await locales();
    const preferred = ['zh_CN', 'zh-CN', 'zh_Hans_CN', 'zh-Hans-CN'];
    for (final id in preferred) {
      if (values.any((locale) => locale.localeId == id)) return id;
    }
    final system = await _speech.systemLocale();
    return system?.localeId;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    if (_speech.isListening) await _speech.cancel();
    await _states.close();
  }
}
