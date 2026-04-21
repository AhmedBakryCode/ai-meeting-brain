import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/network/api_constants.dart';
import '../../../auth/data/datasources/auth_local_data_source.dart'
    as import_auth;
import '../../../auth/data/models/user_model.dart';
import '../../data/datasources/meetings_remote_data_source.dart';
import '../../data/services/audio_recording_service.dart';
import '../../data/services/transcript_stream_service.dart';
import '../../data/services/webrtc_service.dart';
import '../../../auth/data/datasources/auth_local_data_source.dart';
import '../../domain/repositories/meetings_repository.dart';

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

class LeaveMeeting extends MeetingEvent {
  const LeaveMeeting(this.meetingId);
  final String meetingId;
}

class MeetingStreamFailed extends MeetingEvent {
  const MeetingStreamFailed();
}


class ReceiveTranscript extends MeetingEvent {
  const ReceiveTranscript(this.message);
  final String message;
}

class ReceiveParticipants extends MeetingEvent {
  const ReceiveParticipants(this.participants);
  final List<UserModel> participants;
}

class TickMeetingTimer extends MeetingEvent {
  const TickMeetingTimer();
}

class MeetingStatusChanged extends MeetingEvent {
  const MeetingStatusChanged(this.status);
  final String status;
}

class AudioLevelsChanged extends MeetingEvent {
  const AudioLevelsChanged(this.levels);
  final Map<String, double> levels;
}

abstract class MeetingState {
  const MeetingState({
    this.transcripts = const [],
    this.participants = const [],
    this.elapsed = Duration.zero,
    this.isLoading = false,
    this.isMicEnabled = false,
    this.audioLevels = const {},
  });

  final List<String> transcripts;
  final List<UserModel> participants;
  final Duration elapsed;
  final bool isLoading;
  final bool isMicEnabled;
  final Map<String, double> audioLevels;
}

class MeetingInitial extends MeetingState {
  const MeetingInitial() : super();
}

class MeetingJoined extends MeetingState {
  const MeetingJoined({
    super.transcripts,
    super.participants,
    super.elapsed,
    super.isLoading,
    super.isMicEnabled,
    super.audioLevels,
  });
}

class Processing extends MeetingState {
  const Processing({
    super.transcripts,
    super.participants,
    super.elapsed,
    super.isLoading,
    super.isMicEnabled,
    super.audioLevels,
  });
}

class Completed extends MeetingState {
  const Completed({
    super.transcripts,
    super.participants,
    super.elapsed,
    super.isLoading,
    super.isMicEnabled,
    super.audioLevels,
  });
}

class MeetingPermissionDenied extends MeetingState {
  const MeetingPermissionDenied({
    super.transcripts,
    super.participants,
    super.elapsed,
    super.isMicEnabled,
    super.audioLevels,
  });
}

class MeetingFailure extends MeetingState {
  const MeetingFailure({
    required this.message,
    super.transcripts,
    super.participants,
    super.elapsed,
    super.isMicEnabled,
    super.audioLevels,
  });

  final String message;
}

class MeetingBloc extends Bloc<MeetingEvent, MeetingState> {
  MeetingBloc({
    required AudioRecordingService recordingService,
    required TranscriptStreamService transcriptStreamService,
    required WebRtcService webRtcService,
    required MeetingsRepository meetingsRepository,
    required AuthLocalDataSource authLocalDataSource,
    this.canUploadRecording = true,
  }) : _recordingService = recordingService,
       _transcriptStreamService = transcriptStreamService,
       _webRtcService = webRtcService,
       _meetingsRepository = meetingsRepository,
       _authLocalDataSource = authLocalDataSource,
       super(const MeetingInitial()) {
    on<JoinMeeting>(_onJoinMeeting);
    on<ToggleMicrophone>(_onToggleMicrophone);
    on<EndMeeting>(_onEndMeeting);
    on<LeaveMeeting>(_onLeaveMeeting);
    on<MeetingStreamFailed>(_onMeetingStreamFailed);
    on<ReceiveTranscript>(_onReceiveTranscript);
    on<ReceiveParticipants>(_onReceiveParticipants);
    on<TickMeetingTimer>(_onTickMeetingTimer);
    on<MeetingStatusChanged>(_onMeetingStatusChanged);
    on<AudioLevelsChanged>(_onAudioLevelsChanged);
  }

  final AudioRecordingService _recordingService;
  final TranscriptStreamService _transcriptStreamService;
  final WebRtcService _webRtcService;
  final MeetingsRepository _meetingsRepository;
  final AuthLocalDataSource _authLocalDataSource;
  final bool canUploadRecording;

  StreamSubscription<String>? _transcriptSubscription;
  StreamSubscription<List<UserModel>>? _participantsSubscription;
  StreamSubscription<String>? _statusSubscription;
  StreamSubscription<Map<String, double>>? _audioLevelsSubscription;
  Timer? _timer;
  String? _currentMeetingId;
  Set<String> _previousJoinedParticipants = {};
  bool _isFirstParticipantsUpdate = true;
  UserModel? _currentUser;

  Future<void> _onJoinMeeting(
    JoinMeeting event,
    Emitter<MeetingState> emit,
  ) async {
    _currentMeetingId = event.meetingId;
    _currentUser = _authLocalDataSource.getUser();

    emit(
      MeetingJoined(
        transcripts: state.transcripts,
        participants: state.participants,
        elapsed: state.elapsed,
        isLoading: true,
        isMicEnabled: false,
      ),
    );

    bool hasPermission = false;
    try {
      final accToken = _authLocalDataSource.getAccessToken() ?? '';
      _currentUser ??= _extractCurrentUser(accToken);

      // Subscribe to streams BEFORE connecting to avoid missing the initial payload
      _transcriptSubscription = _transcriptStreamService.transcriptStream.listen(
        (text) => add(ReceiveTranscript(text)),
        onError: (_) => add(const MeetingStreamFailed()),
      );
      _participantsSubscription = _transcriptStreamService.participantsStream.listen(
        (participants) => add(ReceiveParticipants(participants)),
        onError: (_) => add(const MeetingStreamFailed()),
      );
      _statusSubscription = _transcriptStreamService.statusStream.listen(
        (status) => add(MeetingStatusChanged(status)),
        onError: (_) => add(const MeetingStreamFailed()),
      );
      _audioLevelsSubscription = _webRtcService.audioLevelsStream.listen(
        (levels) => add(AudioLevelsChanged(levels)),
        onError: (e) => print('⚠️ [WebRTC] Audio levels stream error: $e'),
      );

      // 1. Check mic permission first
      hasPermission = await _recordingService.ensurePermission();
      if (!hasPermission) {
        emit(MeetingPermissionDenied(
          transcripts: state.transcripts,
          participants: state.participants,
          elapsed: state.elapsed,
          isMicEnabled: false,
        ));
        return;
      }

      // 2. Get ICE Servers from API
      final iceServers = await _meetingsRepository.getIceServers();

      // 3. Initialize WebRTC service (Prepare local stream & listeners)
      if (_currentUser != null) {
        print('🚀 [WebRTC] Pre-initializing service for user: ${_currentUser!.id}');
        await _webRtcService.initialize(
          userId: _currentUser!.id,
          meetingId: event.meetingId,
          iceServers: iceServers,
        );
        _webRtcService.setMicEnabled(true);
      }

      // 4. NOW connect to SignalR and Join Meeting
      await _transcriptStreamService.connect(
        ApiConstants.meetingsHubUrl,
        meetingId: event.meetingId,
        initialRawParticipants: null,
      );

      // 5. Join meeting via REST API
      await _meetingsRepository.joinMeeting(event.meetingId);

      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        add(const TickMeetingTimer());
      });

      if (canUploadRecording && hasPermission) {
        await _recordingService.startRecording();
      }

      emit(MeetingJoined(
        transcripts: state.transcripts,
        participants: _mergeCurrentUser(state.participants),
        elapsed: state.elapsed,
        isLoading: false,
        isMicEnabled: hasPermission,
      ));
    } catch (e) {
      print('❌ [MeetingBloc] Join process failed: $e');
      if (!isClosed) {
        emit(MeetingFailure(
          message: 'Failed to join meeting: $e',
          transcripts: state.transcripts,
          participants: state.participants,
          elapsed: state.elapsed,
        ));
      }
    }
  }

  Future<void> _onToggleMicrophone(
    ToggleMicrophone event,
    Emitter<MeetingState> emit,
  ) async {
    if (state is Processing || state is Completed) return;
    _currentMeetingId = event.meetingId;

    final hasPermission = await _recordingService.ensurePermission();
    if (!hasPermission) {
      emit(
        MeetingPermissionDenied(
          transcripts: state.transcripts,
          participants: state.participants,
          elapsed: state.elapsed,
        ),
      );
      return;
    }

    try {
      final isEnabled = !state.isMicEnabled;
      _webRtcService.setMicEnabled(isEnabled);

      emit(
        MeetingJoined(
          transcripts: state.transcripts,
          participants: state.participants,
          elapsed: state.elapsed,
          isLoading: false,
          isMicEnabled: isEnabled,
        ),
      );
    } catch (e) {
      print('Mic toggle error: $e');
      emit(
        MeetingFailure(
          message: 'Failed to access microphone: $e',
          transcripts: state.transcripts,
          participants: state.participants,
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
        participants: state.participants,
        elapsed: state.elapsed,
        isLoading: true,
        isMicEnabled: state.isMicEnabled,
      ),
    );

    try {
      // Stop recording and get the full recording file path
      final recordingPath = await _recordingService.stop();

      final remote = sl<MeetingsRemoteDataSource>();
      await remote.endMeeting(event.meetingId);

      // Upload the full recording (if creator and file exists)
      if (canUploadRecording && recordingPath != null) {
        print('📤 [Recording] Uploading full recording: $recordingPath');
        try {
          await remote.uploadRecording(event.meetingId, recordingPath);
          final file = File(recordingPath);
          if (await file.exists()) await file.delete();
          print('✅ [Recording] Upload complete.');
        } catch (e) {
          print('❌ [Recording] Failed to upload recording: $e');
        }
      }

      await _webRtcService.dispose();
      await _transcriptSubscription?.cancel();
      _transcriptSubscription = null;
      await _participantsSubscription?.cancel();
      _participantsSubscription = null;
      await _transcriptStreamService.disconnect(event.meetingId);
      _timer?.cancel();
      _timer = null;

      emit(
        Completed(
          transcripts: state.transcripts,
          participants: state.participants,
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
          participants: state.participants,
          elapsed: state.elapsed,
          isMicEnabled: state.isMicEnabled,
        ),
      );
    }
  }

  Future<void> _onLeaveMeeting(
    LeaveMeeting event,
    Emitter<MeetingState> emit,
  ) async {
    emit(
      Processing(
        transcripts: state.transcripts,
        participants: state.participants,
        elapsed: state.elapsed,
        isLoading: true,
        isMicEnabled: false,
      ),
    );

    try {
      // Stop recording — guests don't upload
      await _recordingService.stop();

      await _transcriptSubscription?.cancel();
      _transcriptSubscription = null;
      await _participantsSubscription?.cancel();
      _participantsSubscription = null;
      final remote = sl<MeetingsRemoteDataSource>();
      await remote.leaveMeeting(event.meetingId);
      await _webRtcService.dispose();
      await _transcriptStreamService.disconnect(event.meetingId);
      _timer?.cancel();
      _timer = null;

      emit(
        Completed(
          transcripts: state.transcripts,
          participants: state.participants,
          elapsed: state.elapsed,
          isLoading: false,
          isMicEnabled: false,
        ),
      );
    } catch (e) {
      emit(
        MeetingFailure(
          message: 'Failed to leave meeting: $e',
          transcripts: state.transcripts,
          participants: state.participants,
          elapsed: state.elapsed,
          isMicEnabled: false,
        ),
      );
    }
  }


  void _onReceiveTranscript(
    ReceiveTranscript event,
    Emitter<MeetingState> emit,
  ) {
    if (event.message.isEmpty) return;
    final updated = List<String>.from(state.transcripts)..add(event.message);
    emit(_copyState(state, transcripts: updated));
  }

  void _onReceiveParticipants(
    ReceiveParticipants event,
    Emitter<MeetingState> emit,
  ) {
    final newParticipants = event.participants;

    // Manage WebRTC calls for newly joined participants
    print(
      '🔍 [WebRTC] Checking for new calls. Count=${newParticipants.length}',
    );

    for (final user in newParticipants) {
      if (!user.isJoined || user.id == _currentUser?.id) continue;

      final myId = _currentUser?.id ?? '';
      if (myId.isEmpty) {
        print('⚠️ [WebRTC] My ID is empty, skipping call initiation.');
        continue;
      }

      final theirId = user.id;
      final isNewParticipant = !_previousJoinedParticipants.contains(theirId);
      // Also re-initiate if they were seen before but connection is stale/dead
      final hasStaleConnection = _previousJoinedParticipants.contains(theirId) &&
          !_webRtcService.hasActiveConnection(theirId);

      if (!isNewParticipant && !hasStaleConnection) continue;

      final shouldCall = myId.compareTo(theirId) < 0;

      print('🔍 [WebRTC] Evaluation for ${user.displayName} ($theirId):');
      print('   ↳ isNew=$isNewParticipant, hasStaleConnection=$hasStaleConnection');
      print('   ↳ MyID ($myId) < TheirID ($theirId)? $shouldCall');

      if (shouldCall) {
        print('📞 [WebRTC] -> INITIATING call to ${user.displayName}');
        _webRtcService.callParticipant(theirId);
      } else {
        print('⏳ [WebRTC] -> WAITING for ${user.displayName} to call me.');
      }
    }

    // Update the previous participants set for next comparison
    if (_isFirstParticipantsUpdate) {
      _isFirstParticipantsUpdate = false;
      _previousJoinedParticipants = newParticipants
          .where((u) => u.isJoined)
          .map((u) => u.id)
          .toSet();
      print(
        '🔍 [WebRTC] First update: Tracked ${_previousJoinedParticipants.length} players.',
      );
    } else {
      _previousJoinedParticipants = newParticipants
          .where((u) => u.isJoined)
          .map((u) => u.id)
          .toSet();
    }

    // Cleanup WebRTC connections for participants who just left
    for (final oldUser in state.participants.where((u) => u.isJoined)) {
      final stillJoined = newParticipants.any(
        (u) => u.id == oldUser.id && u.isJoined,
      );
      if (!stillJoined && oldUser.id != _currentUser?.id) {
        print('📞 [WebRTC] Removing participant who left: ${oldUser.id}');
        _webRtcService.removeParticipant(oldUser.id);
        _previousJoinedParticipants.remove(oldUser.id);
      }
    }

    emit(_copyState(state, participants: _mergeCurrentUser(newParticipants)));
  }

  void _onTickMeetingTimer(TickMeetingTimer event, Emitter<MeetingState> emit) {
    if (state is Completed ||
        state is MeetingInitial ||
        state is MeetingFailure)
      return;
    emit(
      _copyState(state, elapsed: state.elapsed + const Duration(seconds: 1)),
    );
  }

  Future<void> _onMeetingStatusChanged(
    MeetingStatusChanged event,
    Emitter<MeetingState> emit,
  ) async {
    final status = event.status.toLowerCase();
    if (status.contains('ended') || status == '2') {
      if (state is Completed || state is Processing) return;

      // Stop recording and upload if creator
      final recordingPath = await _recordingService.stop();
      if (canUploadRecording && recordingPath != null && _currentMeetingId != null) {
        print('📤 [Recording] Meeting ended remotely — uploading full recording.');
        try {
          final remote = sl<MeetingsRemoteDataSource>();
          await remote.uploadRecording(_currentMeetingId!, recordingPath);
          final file = File(recordingPath);
          if (await file.exists()) await file.delete();
          print('✅ [Recording] Upload complete.');
        } catch (e) {
          print('❌ [Recording] Failed to upload recording: $e');
        }
      }

      await _transcriptSubscription?.cancel();
      _transcriptSubscription = null;
      await _participantsSubscription?.cancel();
      _participantsSubscription = null;
      await _statusSubscription?.cancel();
      _statusSubscription = null;

      if (_currentMeetingId != null) {
        await _transcriptStreamService.disconnect(_currentMeetingId!);
      }
      await _webRtcService.dispose();
      _timer?.cancel();
      _timer = null;

      emit(
        Completed(
          transcripts: state.transcripts,
          participants: state.participants,
          elapsed: state.elapsed,
          isLoading: false,
          isMicEnabled: false,
        ),
      );
    }
  }

  Future<void> _onMeetingStreamFailed(
    MeetingStreamFailed event,
    Emitter<MeetingState> emit,
  ) async {
    await _recordingService.stop();
    await _transcriptSubscription?.cancel();
    _transcriptSubscription = null;
    await _participantsSubscription?.cancel();
    _participantsSubscription = null;
    _timer?.cancel();
    _timer = null;
    if (_currentMeetingId != null) {
      await _transcriptStreamService.disconnect(_currentMeetingId!);
    }
    emit(
      MeetingFailure(
        message: 'Network connection was lost.',
        transcripts: state.transcripts,
        participants: state.participants,
        elapsed: state.elapsed,
        isMicEnabled: false,
      ),
    );
  }

  void _onAudioLevelsChanged(
    AudioLevelsChanged event,
    Emitter<MeetingState> emit,
  ) {
    emit(_copyState(state, audioLevels: event.levels));
  }


  List<UserModel> _mergeCurrentUser(List<UserModel> incoming) {
    final currentUser = _currentUser;
    if (currentUser == null) return incoming;

    final hasCurrentUser = incoming.any((user) => user.id == currentUser.id);
    if (hasCurrentUser) return incoming;
    return <UserModel>[currentUser, ...incoming];
  }

  UserModel? _extractCurrentUser(String? token) {
    if (token == null || token.isEmpty) return null;
    final parts = token.split('.');
    if (parts.length < 2) return null;

    try {
      final normalized = base64Url.normalize(parts[1]);
      final payload = jsonDecode(utf8.decode(base64Url.decode(normalized)));
      if (payload is! Map<String, dynamic>) return null;

      final id =
          payload['sub']?.toString() ??
          payload['nameid']?.toString() ??
          payload['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier']
              ?.toString() ??
          '';
      final name =
          payload['name']?.toString() ??
          payload['unique_name']?.toString() ??
          payload['preferred_username']?.toString() ??
          'You';
      final email =
          payload['email']?.toString() ??
          payload['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress']
              ?.toString() ??
          '';

      if (id.isEmpty) return null;
      return UserModel(id: id, email: email, displayName: name, isJoined: true);
    } catch (_) {
      return null;
    }
  }

  MeetingState _copyState(
    MeetingState current, {
    List<String>? transcripts,
    List<UserModel>? participants,
    Duration? elapsed,
    bool? isLoading,
    bool? isMicEnabled,
    Map<String, double>? audioLevels,
  }) {
    if (current is Processing) {
      return Processing(
        transcripts: transcripts ?? current.transcripts,
        participants: participants ?? current.participants,
        elapsed: elapsed ?? current.elapsed,
        isLoading: isLoading ?? current.isLoading,
        isMicEnabled: isMicEnabled ?? current.isMicEnabled,
        audioLevels: audioLevels ?? current.audioLevels,
      );
    }
    if (current is Completed) {
      return Completed(
        transcripts: transcripts ?? current.transcripts,
        participants: participants ?? current.participants,
        elapsed: elapsed ?? current.elapsed,
        isLoading: isLoading ?? current.isLoading,
        isMicEnabled: isMicEnabled ?? current.isMicEnabled,
        audioLevels: audioLevels ?? current.audioLevels,
      );
    }
    if (current is MeetingPermissionDenied) {
      return MeetingPermissionDenied(
        transcripts: transcripts ?? current.transcripts,
        participants: participants ?? current.participants,
        elapsed: elapsed ?? current.elapsed,
        isMicEnabled: isMicEnabled ?? current.isMicEnabled,
        audioLevels: audioLevels ?? current.audioLevels,
      );
    }
    if (current is MeetingFailure) {
      return MeetingFailure(
        message: current.message,
        transcripts: transcripts ?? current.transcripts,
        participants: participants ?? current.participants,
        elapsed: elapsed ?? current.elapsed,
        isMicEnabled: isMicEnabled ?? current.isMicEnabled,
        audioLevels: audioLevels ?? current.audioLevels,
      );
    }
    return MeetingJoined(
      transcripts: transcripts ?? current.transcripts,
      participants: participants ?? current.participants,
      elapsed: elapsed ?? current.elapsed,
      isLoading: isLoading ?? current.isLoading,
      isMicEnabled: isMicEnabled ?? current.isMicEnabled,
      audioLevels: audioLevels ?? current.audioLevels,
    );
  }

  @override
  Future<void> close() async {
    _timer?.cancel();
    await _transcriptSubscription?.cancel();
    await _participantsSubscription?.cancel();
    await _statusSubscription?.cancel();
    await _audioLevelsSubscription?.cancel(); // Added to fix the crash
    await _webRtcService.dispose();
    await _recordingService.stop();
    return super.close();
  }
}
