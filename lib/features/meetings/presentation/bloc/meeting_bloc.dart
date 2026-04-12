import 'dart:async';
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/network/api_constants.dart';
import '../../data/datasources/meetings_remote_data_source.dart';
import '../../data/services/audio_recording_service.dart';
import '../../data/services/transcript_stream_service.dart';
import '../../../auth/data/datasources/auth_local_data_source.dart' as import_auth;

abstract class MeetingEvent {
  const MeetingEvent();
}

class JoinMeeting extends MeetingEvent {
  const JoinMeeting(this.meetingId);
  final String meetingId;
}

class ToggleMicrophone extends MeetingEvent {
  const ToggleMicrophone(this.meetingId);
  final String meetingId;
}

class EndMeeting extends MeetingEvent {
  const EndMeeting(this.meetingId);
  final String meetingId;
}

class MeetingStreamFailed extends MeetingEvent {
  const MeetingStreamFailed();
}

class UploadChunk extends MeetingEvent {
  const UploadChunk(this.filePath);
  final String filePath;
}

class ReceiveTranscript extends MeetingEvent {
  const ReceiveTranscript(this.message);
  final String message;
}

class TickMeetingTimer extends MeetingEvent {
  const TickMeetingTimer();
}

abstract class MeetingState {
  const MeetingState({
    this.transcripts = const [],
    this.elapsed = Duration.zero,
    this.isLoading = false,
    this.isMicEnabled = false,
  });

  final List<String> transcripts;
  final Duration elapsed;
  final bool isLoading;
  final bool isMicEnabled;
}

class MeetingInitial extends MeetingState {
  const MeetingInitial() : super();
}

class MeetingJoined extends MeetingState {
  const MeetingJoined({
    super.transcripts,
    super.elapsed,
    super.isLoading,
    super.isMicEnabled,
  });
}

class Processing extends MeetingState {
  const Processing({
    super.transcripts,
    super.elapsed,
    super.isLoading,
    super.isMicEnabled,
  });
}

class Completed extends MeetingState {
  const Completed({
    super.transcripts,
    super.elapsed,
    super.isLoading,
    super.isMicEnabled,
  });
}

class MeetingPermissionDenied extends MeetingState {
  const MeetingPermissionDenied({
    super.transcripts,
    super.elapsed,
    super.isMicEnabled,
  });
}

class MeetingFailure extends MeetingState {
  const MeetingFailure({
    required this.message,
    super.transcripts,
    super.elapsed,
    super.isMicEnabled,
  });

  final String message;
}

class MeetingBloc extends Bloc<MeetingEvent, MeetingState> {
  MeetingBloc({
    required AudioRecordingService recordingService,
    required TranscriptStreamService transcriptStreamService,
    this.canUploadRecording = true,
  })  : _recordingService = recordingService,
        _transcriptStreamService = transcriptStreamService,
        super(const MeetingInitial()) {
    on<JoinMeeting>(_onJoinMeeting);
    on<ToggleMicrophone>(_onToggleMicrophone);
    on<EndMeeting>(_onEndMeeting);
    on<MeetingStreamFailed>(_onMeetingStreamFailed);
    on<UploadChunk>(_onUploadChunk);
    on<ReceiveTranscript>(_onReceiveTranscript);
    on<TickMeetingTimer>(_onTickMeetingTimer);
  }

  final AudioRecordingService _recordingService;
  final TranscriptStreamService _transcriptStreamService;
  final bool canUploadRecording;

  StreamSubscription<String>? _transcriptSubscription;
  Timer? _timer;
  String? _currentMeetingId;
  int _pendingUploads = 0;
  Completer<void>? _uploadsCompleter;

  Future<void> _onJoinMeeting(JoinMeeting event, Emitter<MeetingState> emit) async {
    _currentMeetingId = event.meetingId;
    emit(
      MeetingJoined(
        transcripts: state.transcripts,
        elapsed: state.elapsed,
        isLoading: true,
        isMicEnabled: false,
      ),
    );

    try {
      final accToken = sl<import_auth.AuthLocalDataSource>().getAccessToken() ?? '';
      await _transcriptStreamService.connect(
        ApiConstants.meetingsHubUrl,
        meetingId: event.meetingId,
        accessToken: accToken,
      );
      _transcriptSubscription = _transcriptStreamService.transcriptStream.listen(
        (text) => add(ReceiveTranscript(text)),
        onError: (_) => add(const MeetingStreamFailed()),
        cancelOnError: false,
      );

      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        add(const TickMeetingTimer());
      });

      emit(
        MeetingJoined(
          transcripts: state.transcripts,
          elapsed: state.elapsed,
          isLoading: false,
          isMicEnabled: false,
        ),
      );
    } catch (e) {
      if (!isClosed) {
        emit(
          MeetingFailure(
            message: 'Could not connect to live stream: $e',
            transcripts: state.transcripts,
            elapsed: state.elapsed,
            isMicEnabled: false,
          ),
        );
      }
    }
  }

  Future<void> _onToggleMicrophone(
    ToggleMicrophone event,
    Emitter<MeetingState> emit,
  ) async {
    if (state is Processing || state is Completed) return;
    _currentMeetingId = event.meetingId;

    if (!canUploadRecording) {
      emit(
        MeetingFailure(
          message: 'Only the meeting creator can upload meeting recordings.',
          transcripts: state.transcripts,
          elapsed: state.elapsed,
          isMicEnabled: false,
        ),
      );
      return;
    }

    final micIsRunning = await _recordingService.isRecording();
    if (micIsRunning || state.isMicEnabled) {
      await _recordingService.stop();
      emit(
        MeetingJoined(
          transcripts: state.transcripts,
          elapsed: state.elapsed,
          isLoading: false,
          isMicEnabled: false,
        ),
      );
      return;
    }

    final hasPermission = await _recordingService.ensurePermission();
    if (!hasPermission) {
      emit(
        MeetingPermissionDenied(
          transcripts: state.transcripts,
          elapsed: state.elapsed,
          isMicEnabled: false,
        ),
      );
      return;
    }

    try {
      await _recordingService.startChunking(onChunk30s: (path) {
        add(UploadChunk(path));
      });
      emit(
        MeetingJoined(
          transcripts: state.transcripts,
          elapsed: state.elapsed,
          isLoading: false,
          isMicEnabled: true,
        ),
      );
    } catch (e) {
      emit(
        MeetingFailure(
          message: 'Failed to access microphone: $e',
          transcripts: state.transcripts,
          elapsed: state.elapsed,
          isMicEnabled: false,
        ),
      );
    }
  }

  Future<void> _onEndMeeting(
    EndMeeting event,
    Emitter<MeetingState> emit,
  ) async {
    emit(
      Processing(
        transcripts: state.transcripts,
        elapsed: state.elapsed,
        isLoading: true,
        isMicEnabled: state.isMicEnabled,
      ),
    );

    try {
      await _recordingService.stop();
      await _flushPendingChunkUploads();
      final remote = sl<MeetingsRemoteDataSource>();
      await remote.endMeeting(event.meetingId);

      await _transcriptSubscription?.cancel();
      _transcriptSubscription = null;
      await _transcriptStreamService.disconnect(event.meetingId);
      _timer?.cancel();
      _timer = null;

      emit(
        Completed(
          transcripts: state.transcripts,
          elapsed: state.elapsed,
          isLoading: false,
          isMicEnabled: false,
        ),
      );
    } catch (e) {
      emit(
        MeetingFailure(
          message: 'Failed to end meeting: $e',
          transcripts: state.transcripts,
          elapsed: state.elapsed,
          isMicEnabled: state.isMicEnabled,
        ),
      );
    }
  }

  Future<void> _onUploadChunk(UploadChunk event, Emitter<MeetingState> emit) async {
    if (_currentMeetingId == null) return;
    _pendingUploads++;
    _uploadsCompleter ??= Completer<void>();
    try {
      final remote = sl<MeetingsRemoteDataSource>();
      await remote.uploadRecording(_currentMeetingId!, event.filePath);
      final file = File(event.filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('Failed to upload 30s chunk: $e');
    } finally {
      _pendingUploads--;
      if (_pendingUploads <= 0) {
        _pendingUploads = 0;
        _uploadsCompleter?.complete();
        _uploadsCompleter = null;
      }
    }
  }

  void _onReceiveTranscript(ReceiveTranscript event, Emitter<MeetingState> emit) {
    if (event.message.isEmpty) return;
    final updated = List<String>.from(state.transcripts)..add(event.message);

    if (state is Processing) {
      emit(
        Processing(
          transcripts: updated,
          elapsed: state.elapsed,
          isLoading: true,
          isMicEnabled: state.isMicEnabled,
        ),
      );
      return;
    }

    if (state is Completed) {
      emit(
        Completed(
          transcripts: updated,
          elapsed: state.elapsed,
          isLoading: false,
          isMicEnabled: false,
        ),
      );
      return;
    }

    emit(
      MeetingJoined(
        transcripts: updated,
        elapsed: state.elapsed,
        isLoading: false,
        isMicEnabled: state.isMicEnabled,
      ),
    );
  }

  void _onTickMeetingTimer(TickMeetingTimer event, Emitter<MeetingState> emit) {
    if (state is Processing) {
      emit(
        Processing(
          transcripts: state.transcripts,
          elapsed: state.elapsed + const Duration(seconds: 1),
          isLoading: state.isLoading,
          isMicEnabled: state.isMicEnabled,
        ),
      );
      return;
    }

    if (state is Completed || state is MeetingInitial) return;

    emit(
      MeetingJoined(
        transcripts: state.transcripts,
        elapsed: state.elapsed + const Duration(seconds: 1),
        isLoading: state.isLoading,
        isMicEnabled: state.isMicEnabled,
      ),
    );
  }

  Future<void> _onMeetingStreamFailed(
    MeetingStreamFailed event,
    Emitter<MeetingState> emit,
  ) async {
    await _recordingService.stop();
    await _transcriptSubscription?.cancel();
    _transcriptSubscription = null;
    _timer?.cancel();
    _timer = null;
    if (_currentMeetingId != null) {
      await _transcriptStreamService.disconnect(_currentMeetingId!);
    }
    emit(
      MeetingFailure(
        message: 'Network connection was lost.',
        transcripts: state.transcripts,
        elapsed: state.elapsed,
        isMicEnabled: false,
      ),
    );
  }

  Future<void> _flushPendingChunkUploads() async {
    if (_pendingUploads <= 0) return;
    await _uploadsCompleter?.future;
  }

  @override
  Future<void> close() async {
    _timer?.cancel();
    await _transcriptSubscription?.cancel();
    await _recordingService.stop();
    return super.close();
  }
}
