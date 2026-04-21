import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

abstract class AudioRecordingService {
  Future<bool> ensurePermission();
  Future<void> startRecording();
  Future<bool> isRecording();
  Future<bool> isMuted();
  Future<void> setMuted(bool muted);

  /// Stops the recording and returns the path to the recorded file.
  /// Returns null if nothing was recorded or an error occurred.
  Future<String?> stop();
}

class AudioRecordingServiceImpl implements AudioRecordingService {
  AudioRecordingServiceImpl();

  AudioRecorder? _recorder;
  String? _currentPath;
  bool _isMuted = false;

  @override
  Future<bool> ensurePermission() {
    _recorder ??= AudioRecorder();
    return _recorder!.hasPermission();
  }

  @override
  Future<void> startRecording() async {
    _recorder ??= AudioRecorder();
    _isMuted = false;

    final tempDir = await getTemporaryDirectory();
    _currentPath =
        '${tempDir.path}/meeting_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder!.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        numChannels: 1,
        sampleRate: 44100,
        autoGain: true,
        echoCancel: true,
        noiseSuppress: true,
        androidConfig: AndroidRecordConfig(
          audioSource: AndroidAudioSource.voiceCommunication,
          useLegacy: false,
        ),
      ),
      path: _currentPath!,
    );

    print('🎙️ [Recording] Started full-meeting recording at: $_currentPath');
  }

  @override
  Future<bool> isRecording() async {
    if (_recorder == null) return false;
    return _recorder!.isRecording();
  }

  @override
  Future<bool> isMuted() async => _isMuted;

  @override
  Future<void> setMuted(bool muted) async {
    _recorder ??= AudioRecorder();
    final currentlyRecording = await _recorder!.isRecording();
    if (!currentlyRecording) {
      _isMuted = muted;
      return;
    }

    if (muted == _isMuted) return;

    try {
      if (muted) {
        await _recorder!.pause();
      } else {
        await _recorder!.resume();
      }
      _isMuted = muted;
    } catch (e) {
      print('Error toggling mute state: $e');
      rethrow;
    }
  }

  @override
  Future<String?> stop() async {
    if (_recorder == null) return null;

    try {
      final isRecordingNow = await _recorder!.isRecording();
      final isPaused = await _recorder!.isPaused();

      String? path;
      if (isRecordingNow || isPaused) {
        path = await _recorder!.stop();
        print('🎙️ [Recording] Stopped. Reported path: $path');
      }

      _isMuted = false;
      await _recorder!.dispose();
      _recorder = null;
      _currentPath = null;

      if (path == null) return null;

      // Android's MediaRecorder writes the file asynchronously after stop().
      // Wait briefly for the OS to flush the file to disk before validating it.
      await Future.delayed(const Duration(milliseconds: 500));

      final file = File(path);
      final exists = await file.exists();
      final size = exists ? await file.length() : 0;

      if (!exists || size == 0) {
        print('⚠️ [Recording] File missing or empty after stop — skipping upload. path=$path, exists=$exists, size=$size');
        return null;
      }

      print('🎙️ [Recording] File ready: $path ($size bytes)');
      return path;
    } catch (e) {
      print('Error stopping recording: $e');
      await _recorder?.dispose();
      _recorder = null;
      _currentPath = null;
      return null;
    }
  }
}
