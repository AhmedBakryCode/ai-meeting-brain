import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meeting_brain/features/meetings/data/services/audio_recording_service.dart';
import 'package:meeting_brain/features/meetings/data/services/transcript_stream_service.dart';
import 'package:meeting_brain/features/meetings/presentation/bloc/meeting_bloc.dart';
import 'package:mocktail/mocktail.dart';

class _MockAudioRecordingService extends Mock implements AudioRecordingService {}

class _MockTranscriptStreamService extends Mock implements TranscriptStreamService {}

void main() {
  late _MockAudioRecordingService recordingService;
  late _MockTranscriptStreamService streamService;

  setUpAll(() {
    registerFallbackValue(Uint8List.fromList(const [0]));
  });

  setUp(() {
    recordingService = _MockAudioRecordingService();
    streamService = _MockTranscriptStreamService();
    when(() => recordingService.ensurePermission()).thenAnswer((_) async => true);
    when(() => recordingService.start(onChunk: any(named: 'onChunk'))).thenAnswer((_) async {});
    when(() => recordingService.stop()).thenAnswer((_) async {});
    when(() => streamService.connect(any(), meetingId: any(named: 'meetingId'))).thenAnswer((_) async {});
    when(() => streamService.disconnect(any())).thenAnswer((_) async {});
    when(() => streamService.sendTranscriptChunk(
          meetingId: any(named: 'meetingId'),
          text: any(named: 'text'),
        )).thenAnswer((_) async {});
    when(() => streamService.transcriptStream).thenAnswer((_) => const Stream<String>.empty());
  });

  blocTest<MeetingBloc, MeetingState>(
    'emits permission denied when mic permission is denied',
    build: () {
      when(() => recordingService.ensurePermission()).thenAnswer((_) async => false);
      return MeetingBloc(
        recordingService: recordingService,
        transcriptStreamService: streamService,
      );
    },
    act: (bloc) => bloc.add(const StartMeeting('test_meeting')),
    expect: () => <Matcher>[isA<MeetingPermissionDenied>()],
  );

  blocTest<MeetingBloc, MeetingState>(
    'appends transcript on ReceiveTranscript',
    build: () => MeetingBloc(
      recordingService: recordingService,
      transcriptStreamService: streamService,
    ),
    act: (bloc) => bloc.add(const ReceiveTranscript('hello world')),
    expect: () => <Matcher>[
      isA<Recording>().having((s) => s.transcripts.length, 'transcripts length', 1),
    ],
  );

  blocTest<MeetingBloc, MeetingState>(
    'emits recording state when sending chunk',
    build: () => MeetingBloc(
      recordingService: recordingService,
      transcriptStreamService: streamService,
    ),
    act: (bloc) => bloc.add(SendChunk(Uint8List.fromList([1, 2, 3]))),
    expect: () => <Matcher>[isA<Processing>()],
  );
}
