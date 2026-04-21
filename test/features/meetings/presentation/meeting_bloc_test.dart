import 'dart:async';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meeting_brain/core/di/injection_container.dart';
import 'package:meeting_brain/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:meeting_brain/features/meetings/data/datasources/meetings_remote_data_source.dart';
import 'package:meeting_brain/features/meetings/data/services/audio_recording_service.dart';
import 'package:meeting_brain/features/meetings/data/services/transcript_stream_service.dart';
import 'package:meeting_brain/features/meetings/data/services/webrtc_service.dart';
import 'package:meeting_brain/features/meetings/domain/repositories/meetings_repository.dart';
import 'package:meeting_brain/features/meetings/presentation/bloc/meeting_bloc.dart';
import 'package:meeting_brain/features/auth/data/models/user_model.dart';
import 'package:mocktail/mocktail.dart';

class _MockAudioRecordingService extends Mock implements AudioRecordingService {}
class _MockTranscriptStreamService extends Mock implements TranscriptStreamService {}
class _MockAuthLocalDataSource extends Mock implements AuthLocalDataSource {}
class _MockMeetingsRemoteDataSource extends Mock implements MeetingsRemoteDataSource {}
class _MockWebRtcService extends Mock implements WebRtcService {}
class _MockMeetingsRepository extends Mock implements MeetingsRepository {}

void main() {
  late _MockAudioRecordingService recordingService;
  late _MockTranscriptStreamService streamService;
  late _MockAuthLocalDataSource authLocalDataSource;
  late _MockMeetingsRemoteDataSource meetingsRemoteDataSource;
  late _MockWebRtcService webRtcService;
  late _MockMeetingsRepository meetingsRepository;

  setUpAll(() {
    sl.allowReassignment = true;
    registerFallbackValue(const JoinMeeting(''));
  });

  setUp(() {
    recordingService = _MockAudioRecordingService();
    streamService = _MockTranscriptStreamService();
    authLocalDataSource = _MockAuthLocalDataSource();
    meetingsRemoteDataSource = _MockMeetingsRemoteDataSource();
    webRtcService = _MockWebRtcService();
    meetingsRepository = _MockMeetingsRepository();

    sl.registerLazySingleton<AuthLocalDataSource>(() => authLocalDataSource);
    sl.registerLazySingleton<MeetingsRemoteDataSource>(() => meetingsRemoteDataSource);

    // Default mock behavior
    const mockUser = UserModel(id: 'user_1', email: 'test@test.com', displayName: 'Test');
    when(() => authLocalDataSource.getAccessToken()).thenReturn('mock_token');
    when(() => authLocalDataSource.getUser()).thenReturn(mockUser);
    
    when(() => recordingService.ensurePermission()).thenAnswer((_) async => true);
    when(() => recordingService.isRecording()).thenAnswer((_) async => false);
    when(() => recordingService.isMuted()).thenAnswer((_) async => true); 
    when(() => recordingService.setMuted(any())).thenAnswer((_) async {});
    when(() => recordingService.stop()).thenAnswer((_) async => null);
    when(() => recordingService.startRecording()).thenAnswer((_) async {});
    
    when(() => streamService.connect(any(), meetingId: any(named: 'meetingId'), accessToken: any(named: 'accessToken'), initialRawParticipants: any(named: 'initialRawParticipants')))
        .thenAnswer((_) async {});
    when(() => streamService.disconnect(any())).thenAnswer((_) async {});
    when(() => streamService.transcriptStream).thenAnswer((_) => const Stream<String>.empty());
    when(() => streamService.participantsStream).thenAnswer((_) => const Stream<List<UserModel>>.empty());
    when(() => streamService.statusStream).thenAnswer((_) => const Stream<String>.empty());

    when(() => meetingsRemoteDataSource.endMeeting(any())).thenAnswer((_) async => {});
    when(() => meetingsRemoteDataSource.leaveMeeting(any())).thenAnswer((_) async => {});
    when(() => meetingsRemoteDataSource.uploadRecording(any(), any())).thenAnswer((_) async => {});
    
    when(() => meetingsRepository.getIceServers()).thenAnswer((_) async => []);
    when(() => webRtcService.initialize(
      userId: any(named: 'userId'),
      meetingId: any(named: 'meetingId'),
      iceServers: any(named: 'iceServers'),
    )).thenAnswer((_) async {});
    when(() => webRtcService.dispose()).thenAnswer((_) async {});
    when(() => webRtcService.setMicEnabled(any())).thenReturn(null);
  });

  group('MeetingBloc', () {
    blocTest<MeetingBloc, MeetingState>(
      'emits MeetingJoined when JoinMeeting is successful',
      build: () => MeetingBloc(
        recordingService: recordingService,
        transcriptStreamService: streamService,
        webRtcService: webRtcService,
        meetingsRepository: meetingsRepository,
        authLocalDataSource: authLocalDataSource,
      ),
      act: (bloc) => bloc.add(const JoinMeeting('test_meeting_id')),
      expect: () => [
        isA<MeetingJoined>().having((s) => s.isLoading, 'isLoading', true),
        isA<MeetingJoined>().having((s) => s.isLoading, 'isLoading', false),
      ],
    );

    blocTest<MeetingBloc, MeetingState>(
      'emits MeetingPermissionDenied when mic permission is denied during ToggleMicrophone',
      build: () {
        when(() => recordingService.ensurePermission()).thenAnswer((_) async => false);
        return MeetingBloc(
          recordingService: recordingService,
          transcriptStreamService: streamService,
          webRtcService: webRtcService,
          meetingsRepository: meetingsRepository,
          authLocalDataSource: authLocalDataSource,
        );
      },
      act: (bloc) => bloc.add(const ToggleMicrophone('test_meeting_id')),
      expect: () => [
        isA<MeetingPermissionDenied>(),
      ],
    );

    blocTest<MeetingBloc, MeetingState>(
      'toggles mic state correctly for GUESTS (everyone can toggle voice)',
      build: () => MeetingBloc(
        recordingService: recordingService,
        transcriptStreamService: streamService,
        webRtcService: webRtcService,
        meetingsRepository: meetingsRepository,
        authLocalDataSource: authLocalDataSource,
        canUploadRecording: false,
      ),
      seed: () => const MeetingJoined(isMicEnabled: false),
      act: (bloc) => bloc.add(const ToggleMicrophone('test_meeting_id')),
      expect: () => [
        isA<MeetingJoined>().having((s) => s.isMicEnabled, 'isMicEnabled', true),
      ],
      verify: (_) {
        verify(() => webRtcService.setMicEnabled(true)).called(1);
        verifyNever(() => recordingService.setMuted(any()));
      },
    );

    blocTest<MeetingBloc, MeetingState>(
      'toggles mic state correctly for CREATOR (does NOT mute background recording)',
      build: () => MeetingBloc(
        recordingService: recordingService,
        transcriptStreamService: streamService,
        webRtcService: webRtcService,
        meetingsRepository: meetingsRepository,
        authLocalDataSource: authLocalDataSource,
        canUploadRecording: true,
      ),
      seed: () => const MeetingJoined(isMicEnabled: true),
      act: (bloc) => bloc.add(const ToggleMicrophone('test_meeting_id')),
      expect: () => [
        isA<MeetingJoined>().having((s) => s.isMicEnabled, 'isMicEnabled', false),
      ],
      verify: (_) {
        verify(() => webRtcService.setMicEnabled(false)).called(1);
        verifyNever(() => recordingService.setMuted(any())); // Key fix: should NOT mute recording
      },
    );

    blocTest<MeetingBloc, MeetingState>(
      'appends transcript on ReceiveTranscript',
      build: () => MeetingBloc(
        recordingService: recordingService,
        transcriptStreamService: streamService,
        webRtcService: webRtcService,
        meetingsRepository: meetingsRepository,
        authLocalDataSource: authLocalDataSource,
      ),
      act: (bloc) => bloc.add(const ReceiveTranscript('hello world')),
      expect: () => [
        isA<MeetingJoined>().having((s) => s.transcripts, 'transcripts', ['hello world']),
      ],
    );

    blocTest<MeetingBloc, MeetingState>(
      'emits Processing and then Completed when EndMeeting is called',
      build: () => MeetingBloc(
        recordingService: recordingService,
        transcriptStreamService: streamService,
        webRtcService: webRtcService,
        meetingsRepository: meetingsRepository,
        authLocalDataSource: authLocalDataSource,
      ),
      act: (bloc) => bloc.add(const EndMeeting('test_meeting_id')),
      expect: () => [
        isA<Processing>(),
        isA<Completed>(),
      ],
      verify: (_) {
        verify(() => recordingService.stop()).called(greaterThanOrEqualTo(1));
      },
    );
  });
}
