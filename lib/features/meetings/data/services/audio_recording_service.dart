import 'dart:async';
import 'dart:io';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

abstract class AudioRecordingService {
  Future<bool> ensurePermission();
  Future<void> startChunking({
    required void Function(String filePath) onChunk30s,
  });
  Future<bool> isRecording();
  Future<void> stop();
}

class AudioRecordingServiceImpl implements AudioRecordingService {
  AudioRecordingServiceImpl();

  AudioRecorder? _recorder;
  Timer? _chunkTimer;
  void Function(String filePath)? _onChunk30s;
  String? _currentPath;

  @override
  Future<bool> ensurePermission() {
    _recorder ??= AudioRecorder();
    return _recorder!.hasPermission();
  }

  @override
  Future<void> startChunking({
    required void Function(String filePath) onChunk30s,
  }) async {
    _recorder ??= AudioRecorder();
    _chunkTimer?.cancel();
    _onChunk30s = onChunk30s;
    await _startNewRecord();

    _chunkTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (_recorder == null) return;
      
      try {
        if (await _recorder!.isRecording()) {
          final oldPath = await _recorder!.stop();
          if (oldPath != null && _onChunk30s != null) {
            _onChunk30s!(oldPath);
          }
        }
      } catch (e) {
        print('Error stopping chunk: $e');
      }
      
      // Increased delay to allow hardware release
      await Future.delayed(const Duration(milliseconds: 350));
      
      if (_chunkTimer != null) {
        await _startNewRecord();
      }
    });
  }

  Future<void> _startNewRecord() async {
    if (_recorder == null) return;
    
    int retries = 0;
    while (retries < 3) {
      try {
        // Double check state
        if (await _recorder!.isRecording()) {
          await _recorder!.stop();
          await Future.delayed(const Duration(milliseconds: 150));
        }
        
        final tempDir = await getTemporaryDirectory();
        _currentPath = '${tempDir.path}/chunk_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        await _recorder!.start(
          const RecordConfig(encoder: AudioEncoder.aacLc, numChannels: 1, sampleRate: 44100),
          path: _currentPath!,
        );
        return; // Success
      } catch (e) {
        print('Attempt ${retries + 1} to start recording failed: $e');
        retries++;
        // On failure, wait longer and try to reset the recorder instance
        await _recorder!.dispose().catchError((_) {});
        _recorder = AudioRecorder();
        await Future.delayed(const Duration(milliseconds: 600));
      }
    }
  }

  @override
  Future<bool> isRecording() async {
    if (_recorder == null) return false;
    return _recorder!.isRecording();
  }

  @override
  Future<void> stop() async {
    _chunkTimer?.cancel();
    _chunkTimer = null;

    if (_recorder != null) {
      try {
        if (await _recorder!.isRecording()) {
          final lastPath = await _recorder!.stop();
          if (lastPath != null && _onChunk30s != null) {
            _onChunk30s!(lastPath);
          }
        }
      } catch (e) {
        print('Error during final stop: $e');
      }
      
      _onChunk30s = null;
      await _recorder!.dispose();
      _recorder = null;
    }
  }
}
